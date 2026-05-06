// rbac.go — 极简 RBAC：基于 role 字符串白名单的 middleware。
//
// WHY 不上 Casbin：≤10 GM 团队、3 个角色、5-8 个端点，policy DSL 的复杂度成本远超收益。
// 直接 `requireRole("superadmin", "gm")` 比写 .conf + 加载器更可读、更易审计。
//
// 设计：
//   - role 必须由 authMiddleware 注入；走到 requireRole 前没 claims = 配置错（500）。
//   - 角色不在白名单 → 403（语义上是已认证但无权，区别于 401 的未认证）。
package main

import (
	"net/http"
)

// requireRole 返回一个 middleware，只放行 claims.Role 落在 allowed 之内的请求。
//
// 用法：r.With(store.authMiddleware, requireRole("superadmin", "gm")).Post(...)
func requireRole(allowed ...string) func(http.Handler) http.Handler {
	// 预构集合便于 O(1) 命中；3 个 role 用切片也行，但 set 语义更清晰。
	allowedSet := make(map[string]struct{}, len(allowed))
	for _, r := range allowed {
		allowedSet[r] = struct{}{}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := claimsFromCtx(r.Context())
			if !ok {
				// 编程错误：requireRole 必须挂在 authMiddleware 之后。
				writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "rbac misconfigured"})
				return
			}
			if _, hit := allowedSet[claims.Role]; !hit {
				writeJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
