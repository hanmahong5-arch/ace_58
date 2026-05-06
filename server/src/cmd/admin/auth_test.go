// auth_test.go — JWT / 用户库 / 启动期校验
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"golang.org/x/time/rate"
)

// testSecret 是单测用的强密钥（32B 满足 jwtMinSecretBytes）。
const testSecret = "0123456789abcdef0123456789abcdef"

// newTestAuth 跳过环境变量直接构造 authStore，便于多场景注入。
func newTestAuth(t *testing.T) *authStore {
	t.Helper()
	t.Setenv(envJWTSecret, testSecret)
	a, err := loadAuthStore()
	if err != nil {
		t.Fatalf("loadAuthStore: %v", err)
	}
	return a
}

// newTestServer 把 router 套进 httptest.NewServer，返回 base URL。
func newTestServer(t *testing.T) (string, *authStore, func()) {
	t.Helper()
	auth := newTestAuth(t)
	ctx, cancel := context.WithCancel(context.Background())
	loginLim := newRateLimiter(ctx, rate.Every(time.Minute/5), 5)
	apiLim := newRateLimiter(ctx, rate.Every(time.Second), 60)
	h := newRouter(routerDeps{auth: auth, loginLimit: loginLim, apiLimit: apiLim})
	srv := httptest.NewServer(h)
	return srv.URL, auth, func() {
		srv.Close()
		cancel()
	}
}

// loginAs 走完整 HTTP 链路登录并返回 token；失败时直接 fatal。
func loginAs(t *testing.T, base, user, pass string) string {
	t.Helper()
	body, _ := json.Marshal(loginRequest{User: user, Password: pass})
	resp, err := http.Post(base+"/admin/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("login post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("login expected 200, got %d", resp.StatusCode)
	}
	var lr loginResponse
	if err := json.NewDecoder(resp.Body).Decode(&lr); err != nil {
		t.Fatalf("decode login resp: %v", err)
	}
	if lr.Token == "" {
		t.Fatal("token empty")
	}
	return lr.Token
}

// TestLoadAuthStore_RejectsShortSecret — 启动期 ≥32B 校验。
func TestLoadAuthStore_RejectsShortSecret(t *testing.T) {
	t.Setenv(envJWTSecret, "short")
	_, err := loadAuthStore()
	if err == nil {
		t.Fatal("expected error for short secret, got nil")
	}
	if !strings.Contains(err.Error(), "32B") {
		t.Errorf("error should mention 32B threshold: %v", err)
	}
}

// TestLoadAuthStore_AcceptsExactly32B — 边界值精确通过。
func TestLoadAuthStore_AcceptsExactly32B(t *testing.T) {
	t.Setenv(envJWTSecret, strings.Repeat("a", 32))
	if _, err := loadAuthStore(); err != nil {
		t.Fatalf("32B should pass: %v", err)
	}
}

// TestLoadAuthStore_RejectsEmpty — 未设环境变量等价于空字符串。
func TestLoadAuthStore_RejectsEmpty(t *testing.T) {
	_ = os.Unsetenv(envJWTSecret)
	_, err := loadAuthStore()
	if err == nil {
		t.Fatal("expected error for empty secret")
	}
}

// TestSignAndParseToken_Roundtrip — 签发后能解析回相同 claims。
func TestSignAndParseToken_Roundtrip(t *testing.T) {
	a := newTestAuth(t)
	tok, exp, err := a.signToken("alice", roleGM)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if tok == "" {
		t.Fatal("empty token")
	}
	if time.Until(exp) < time.Hour {
		t.Errorf("exp too short: %v", exp)
	}
	c, err := a.parseToken(tok)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if c.Subject != "alice" || c.Role != roleGM {
		t.Errorf("claims mismatch: sub=%s role=%s", c.Subject, c.Role)
	}
	if c.ID == "" {
		t.Error("jti empty — replay defense weakened")
	}
}

// TestParseToken_RejectsTamperedSig — 篡改签名应失败。
func TestParseToken_RejectsTamperedSig(t *testing.T) {
	a := newTestAuth(t)
	tok, _, _ := a.signToken("alice", roleGM)
	// 改最后一个字符破坏签名
	tampered := tok[:len(tok)-1] + "X"
	if _, err := a.parseToken(tampered); err == nil {
		t.Fatal("tampered token should fail parse")
	}
}

// TestParseToken_RejectsForeignSecret — 不同密钥签的 token 应拒绝。
func TestParseToken_RejectsForeignSecret(t *testing.T) {
	a := newTestAuth(t)
	other := &authStore{secret: []byte(strings.Repeat("z", 32)), users: defaultUsers()}
	foreign, _, _ := other.signToken("alice", roleGM)
	if _, err := a.parseToken(foreign); err == nil {
		t.Fatal("foreign-signed token should fail")
	}
}

// TestLogin_BadPassword — 错密码 401，不区分"用户不存在/密码错"。
func TestLogin_BadPassword(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	body, _ := json.Marshal(loginRequest{User: "superadmin", Password: "wrong"})
	resp, err := http.Post(base+"/admin/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

// TestLogin_UnknownUser — 未知用户也是 401（防枚举）。
func TestLogin_UnknownUser(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	body, _ := json.Marshal(loginRequest{User: "nobody", Password: "x"})
	resp, err := http.Post(base+"/admin/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

// TestLogin_Success_SetsCookieAndBody — 登录成功 cookie + body 双发，token 可解析。
func TestLogin_Success_SetsCookieAndBody(t *testing.T) {
	base, auth, cleanup := newTestServer(t)
	defer cleanup()
	body, _ := json.Marshal(loginRequest{User: "superadmin", Password: "sadmin-dev-pwd"})
	resp, err := http.Post(base+"/admin/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	// 验 cookie
	var found bool
	for _, c := range resp.Cookies() {
		if c.Name == "aion_admin_token" {
			found = true
			if !c.HttpOnly {
				t.Error("cookie 应该 HttpOnly")
			}
		}
	}
	if !found {
		t.Error("response 缺 aion_admin_token cookie")
	}
	// 验 body token
	var lr loginResponse
	if err := json.NewDecoder(resp.Body).Decode(&lr); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if lr.Role != roleSuperadmin {
		t.Errorf("role=%s expected superadmin", lr.Role)
	}
	c, err := auth.parseToken(lr.Token)
	if err != nil {
		t.Fatalf("parse signed token: %v", err)
	}
	if c.Subject != "superadmin" {
		t.Errorf("sub=%s expected superadmin", c.Subject)
	}
}
