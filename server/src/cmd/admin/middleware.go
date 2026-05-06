// middleware.go — 自写 RateLimit + CORS。
//
// WHY 顺序：Recoverer → RequestID → Logger → CORS → RateLimit → Auth → handler
//   - Recoverer 必须最外，否则 panic 直接吞 RequestID，日志无关联。
//   - CORS 在 Auth 之前是为让 OPTIONS preflight 不带 token 也能 204（浏览器规约）。
//   - RateLimit 在 Auth 之前，防"暴力 /admin/login"靠 IP 桶限速；Auth 之后的端点
//     仍走同一函数，但 keyer 切换为 sub（按用户限速）— 这样未登录的桶按 IP，
//     已登录的桶按身份，两类语义不冲撞。
//
// WHY GC goroutine：sync.Map 永不收缩，每个新 IP 都堆一个 *rate.Limiter，
// 长跑下 OOM。30 分钟扫描清理空闲桶足够稳，且不会误清近期活跃的。
package main

import (
	"context"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// gcInterval 是 limiter GC 周期；30 分钟够长以吸收业务尖峰，又够短防长尾 OOM。
const gcInterval = 30 * time.Minute

// idleEvictAfter 是 limiter 闲置多久就被 GC 清掉。
const idleEvictAfter = 30 * time.Minute

// limiterEntry 携带 limiter + 最近访问时间，用于 GC 判定。
type limiterEntry struct {
	lim      *rate.Limiter
	lastSeen time.Time
}

// rateLimiter 是一个 keyed token-bucket 限流器，goroutine-safe。
//
// 不用 sync.Map 是因为我们要扫描全表做 GC，sync.Map 的 Range 没保序也没原子快照；
// 普通 map + RWMutex 在 GC 周期 > 写频率的场景下更可控。
type rateLimiter struct {
	mu      sync.Mutex
	entries map[string]*limiterEntry
	r       rate.Limit
	burst   int
}

// newRateLimiter 创建一个限流器。r=每秒补充令牌数，burst=桶容量。
//
// 启动一个 GC goroutine，由 ctx 控制生命周期 — 进程退出时 ctx cancel 自动收线。
func newRateLimiter(ctx context.Context, r rate.Limit, burst int) *rateLimiter {
	rl := &rateLimiter{
		entries: make(map[string]*limiterEntry),
		r:       r,
		burst:   burst,
	}
	go rl.gcLoop(ctx)
	return rl
}

// allow 判断 key 这一刻能否拿到一个令牌。
func (rl *rateLimiter) allow(key string) bool {
	rl.mu.Lock()
	e, ok := rl.entries[key]
	if !ok {
		e = &limiterEntry{lim: rate.NewLimiter(rl.r, rl.burst)}
		rl.entries[key] = e
	}
	e.lastSeen = time.Now()
	rl.mu.Unlock()
	return e.lim.Allow()
}

// gcLoop 周期清理 idle 限流条目，避免 long-running 进程 OOM。
func (rl *rateLimiter) gcLoop(ctx context.Context) {
	t := time.NewTicker(gcInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-t.C:
			rl.mu.Lock()
			for k, e := range rl.entries {
				if now.Sub(e.lastSeen) > idleEvictAfter {
					delete(rl.entries, k)
				}
			}
			rl.mu.Unlock()
		}
	}
}

// keyerFunc 是从 request 提取限流 key 的函数。
//
// 默认两策略：
//   - keyByIP：登录前 / 公开端点用，按客户端 IP 计桶。
//   - keyBySubOrIP：已登录端点用，优先按 sub（防同 IP 多账号互相影响）。
type keyerFunc func(r *http.Request) string

// keyByIP 抽取 RemoteAddr 的 IP 部分（去端口）作为 key。
//
// 若反向代理在前，调用方可包装一层从 X-Forwarded-For 取 — 当前 admin 仅 127.0.0.1，
// 不需要这层适配。
func keyByIP(r *http.Request) string {
	addr := r.RemoteAddr
	// 形如 "127.0.0.1:54321" → "127.0.0.1"；IPv6 形如 "[::1]:54321" → "[::1]"
	if i := strings.LastIndex(addr, ":"); i > 0 {
		return addr[:i]
	}
	return addr
}

// keyBySubOrIP：登录后按 sub 限速，未登录回退 IP。
func keyBySubOrIP(r *http.Request) string {
	if c, ok := claimsFromCtx(r.Context()); ok && c.Subject != "" {
		return "sub:" + c.Subject
	}
	return "ip:" + keyByIP(r)
}

// rateLimitMiddleware 包装一个 keyer，超额返 429。
func (rl *rateLimiter) middleware(keyer keyerFunc) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !rl.allow(keyer(r)) {
				// 429 + Retry-After 是 RFC7231 标准；浏览器和 prometheus.exporter 都认。
				w.Header().Set("Retry-After", "1")
				writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate limited"})
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// corsMiddleware 仅放 127.0.0.1 来源；admin 进程定位是内网管理面，跨域必然异常。
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && isLoopbackOrigin(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		}
		// preflight 在 Auth 前直接 204，浏览器才肯发真正请求。
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// isLoopbackOrigin 检测 Origin 头是否是 127.0.0.1 / localhost / [::1]。
func isLoopbackOrigin(origin string) bool {
	// 简单模式：只接受三类 host。完整 URL 解析对内网管理面是 over-engineering。
	switch {
	case strings.HasPrefix(origin, "http://127.0.0.1"),
		strings.HasPrefix(origin, "https://127.0.0.1"),
		strings.HasPrefix(origin, "http://localhost"),
		strings.HasPrefix(origin, "https://localhost"),
		strings.HasPrefix(origin, "http://[::1]"),
		strings.HasPrefix(origin, "https://[::1]"):
		return true
	}
	return false
}
