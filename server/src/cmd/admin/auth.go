// auth.go — JWT 签发 / 校验 + 用户库（硬编码三角色）
//
// WHY HS256：admin 进程独立部署，密钥只此一份，无需 RSA 公私分离的复杂度。
// HS256 + 32B 强密钥的攻击成本远超本场景威胁模型（≤10 GM、内网）。
//
// WHY HttpOnly cookie + body 双发：
//   - cookie HttpOnly 防 XSS 偷 token；
//   - body 同送 token 是为给纯 API 客户端（curl/前端 fetch with credentials:false）兜底。
//
// WHY 启动期 ≥32B 校验：HS256 密钥短于 hash 输出（256bit=32B）会被 HMAC 截断风险，
// 且暴力破解成本骤降。短密钥直接 fatal 比"运行时偶尔失败"更安全。
//
// TODO(post-MVP): 用户库迁到 PG 表 admin_users(login text PK, passhash text, role text, disabled bool)，
// 走 SP aion_AdminAuth(login, password) 校验。当前硬编码仅供 ≤10 人 GM 团队冷启动。
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// envJWTSecret 是 HS256 密钥的环境变量名。
const envJWTSecret = "AION_ADMIN_JWT_SECRET"

// jwtMinSecretBytes 是密钥最小长度（256 bit = HS256 hash 输出宽度）。
const jwtMinSecretBytes = 32

// tokenTTL 是 JWT 有效期；2h 平衡"无感续期"与"被盗损失窗口"。
const tokenTTL = 2 * time.Hour

// 三角色常量；硬编码在 router 端做 RBAC 比较。
const (
	roleSuperadmin = "superadmin"
	roleGM         = "gm"
	roleReadonly   = "readonly"
)

// ctxKey 是 context 注入的私有 key 类型，避免跨包碰撞。
type ctxKey int

const (
	ctxKeyClaims ctxKey = iota + 1
)

// adminClaims 是签进 JWT 的自定义 claim。
//
// jti 用 16B 随机十六进制；未来要做"主动撤销列表"时按 jti 黑名单。
type adminClaims struct {
	Role string `json:"role"`
	jwt.RegisteredClaims
}

// userRecord 是硬编码用户库的一行；passhash 由 bcrypt 生成（cost=10）。
type userRecord struct {
	passhash []byte
	role     string
}

// authStore 持有用户库 + JWT 密钥；通过依赖注入便于测试覆盖。
type authStore struct {
	users  map[string]userRecord
	secret []byte
}

// loadAuthStore 从环境读密钥并构建用户库。
//
// 启动失败时返回 error，由 main 决定 fatal 还是 fallback。
func loadAuthStore() (*authStore, error) {
	secret := []byte(os.Getenv(envJWTSecret))
	if len(secret) < jwtMinSecretBytes {
		return nil, fmt.Errorf("%s 长度 %dB < %dB（最小要求）", envJWTSecret, len(secret), jwtMinSecretBytes)
	}
	return &authStore{
		users:  defaultUsers(),
		secret: secret,
	}, nil
}

// defaultUsers 提供三个硬编码账号；passhash 在进程启动期 bcrypt 一次。
//
// 默认密码（dev 用，部署前必须改）：
//   - superadmin / sadmin-dev-pwd
//   - gm        / gm-dev-pwd
//   - readonly  / ro-dev-pwd
//
// TODO(post-MVP): 读 PG admin_users 表替换之。
func defaultUsers() map[string]userRecord {
	mk := func(plain string) []byte {
		// cost=10 是 bcrypt 实际生产档；测试场景下慢但能接受（每次启动一次）。
		h, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
		if err != nil {
			// bcrypt 在合法输入下不会失败；走到这里说明运行时崩坏，直接 panic。
			panic(fmt.Sprintf("bcrypt: %v", err))
		}
		return h
	}
	return map[string]userRecord{
		"superadmin": {passhash: mk("sadmin-dev-pwd"), role: roleSuperadmin},
		"gm":         {passhash: mk("gm-dev-pwd"), role: roleGM},
		"readonly":   {passhash: mk("ro-dev-pwd"), role: roleReadonly},
	}
}

// signToken 给已认证用户签发 JWT。
func (s *authStore) signToken(sub, role string) (string, time.Time, error) {
	now := time.Now().UTC()
	exp := now.Add(tokenTTL)
	jtiBytes := make([]byte, 16)
	if _, err := rand.Read(jtiBytes); err != nil {
		return "", time.Time{}, err
	}
	claims := adminClaims{
		Role: role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   sub,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(exp),
			ID:        hex.EncodeToString(jtiBytes),
			Issuer:    "aion-admin",
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString(s.secret)
	return signed, exp, err
}

// parseToken 校验签名 + exp + 算法白名单，返回 claims。
func (s *authStore) parseToken(raw string) (*adminClaims, error) {
	tok, err := jwt.ParseWithClaims(raw, &adminClaims{}, func(t *jwt.Token) (any, error) {
		// 算法白名单：只信 HS256，防"alg=none"/"alg=RS256 公钥当 HMAC"两类经典攻击。
		if t.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, fmt.Errorf("unexpected alg: %s", t.Method.Alg())
		}
		return s.secret, nil
	})
	if err != nil {
		return nil, err
	}
	c, ok := tok.Claims.(*adminClaims)
	if !ok || !tok.Valid {
		return nil, errors.New("invalid token")
	}
	return c, nil
}

// loginRequest 是 POST /admin/login 的请求体。
type loginRequest struct {
	User     string `json:"user"`
	Password string `json:"password"`
}

// loginResponse 是登录成功的响应；token 同时通过 Set-Cookie 下发。
type loginResponse struct {
	Token     string `json:"token"`
	ExpiresAt int64  `json:"expires_at"` // unix epoch (s)
	Role      string `json:"role"`
}

// handleLogin 处理 POST /admin/login。
//
// 失败 401 不区分"用户不存在/密码错"以减少枚举。bcrypt.CompareHashAndPassword
// 自身耗时近似常数级，对 timing 侧信道天然友好。
func (s *authStore) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	rec, ok := s.users[req.User]
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}
	if err := bcrypt.CompareHashAndPassword(rec.passhash, []byte(req.Password)); err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}
	tok, exp, err := s.signToken(req.User, rec.role)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "sign failed"})
		return
	}
	// HttpOnly 防 XSS 偷 token；Secure 在内网 dev 不强制，生产由反代层补。
	http.SetCookie(w, &http.Cookie{
		Name:     "aion_admin_token",
		Value:    tok,
		Path:     "/",
		Expires:  exp,
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
	})
	writeJSON(w, http.StatusOK, loginResponse{Token: tok, ExpiresAt: exp.Unix(), Role: rec.role})
}

// authMiddleware 校验 Bearer JWT，把 claims 注入 context。
//
// 优先 Authorization header；再回退到 cookie，方便浏览器直接调 API。
func (s *authStore) authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := extractBearer(r)
		if raw == "" {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "missing token"})
			return
		}
		claims, err := s.parseToken(raw)
		if err != nil {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid token"})
			return
		}
		ctx := context.WithValue(r.Context(), ctxKeyClaims, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// extractBearer 优先从 Authorization 头读 Bearer，再回退 cookie。
func extractBearer(r *http.Request) string {
	if h := r.Header.Get("Authorization"); h != "" {
		const prefix = "Bearer "
		if strings.HasPrefix(h, prefix) {
			return strings.TrimSpace(h[len(prefix):])
		}
	}
	if c, err := r.Cookie("aion_admin_token"); err == nil {
		return c.Value
	}
	return ""
}

// claimsFromCtx 从 context 取出已校验的 claims；handler 拿不到就是 middleware 没串好。
func claimsFromCtx(ctx context.Context) (*adminClaims, bool) {
	c, ok := ctx.Value(ctxKeyClaims).(*adminClaims)
	return c, ok
}

// writeJSON 是统一的 JSON 响应工具；忽略 Encode 错误（连接已断的话写不进也无所谓）。
func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
