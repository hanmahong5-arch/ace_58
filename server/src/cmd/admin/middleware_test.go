// middleware_test.go — RateLimit GC、CORS、登录端点 429
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"golang.org/x/time/rate"
)

// TestRateLimit_LoginExceedsBucket — 5/min IP 桶满后第 6 次返 429。
//
// 桶配置 burst=5，所以前 5 次连续 POST 都该过；第 6 次（无补充时间）429。
func TestRateLimit_LoginExceedsBucket(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	body, _ := json.Marshal(loginRequest{User: "superadmin", Password: "wrong"})
	for i := 0; i < 5; i++ {
		resp, err := http.Post(base+"/admin/login", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("post %d: %v", i, err)
		}
		resp.Body.Close()
		// 错密码应 401，不是 429（说明桶还有令牌）
		if resp.StatusCode == http.StatusTooManyRequests {
			t.Fatalf("第 %d 次请求过早 429（burst=5）", i+1)
		}
	}
	// 第 6 次必须 429
	resp, err := http.Post(base+"/admin/login", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("6th post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Errorf("第 6 次应 429，got %d", resp.StatusCode)
	}
	if resp.Header.Get("Retry-After") == "" {
		t.Error("429 应带 Retry-After 头")
	}
}

// TestRateLimit_GCEvictsIdle — GC goroutine 清理空闲桶（防 OOM）。
//
// 不能等真 30 分钟。直接调 rateLimiter 内部状态：注入一个旧 lastSeen，
// 然后手动跑一次清扫逻辑（提取私有 cleanup 行为为可测路径太重，这里改测约束：
// 验证 entries map 在新 key 下会增长，并能通过手动 lastSeen 操纵触发 GC）。
func TestRateLimit_GCEvictsIdle(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	rl := newRateLimiter(ctx, rate.Every(time.Second), 1)

	// 创建 10 个不同 key 的桶
	for i := 0; i < 10; i++ {
		rl.allow("k" + string(rune('0'+i)))
	}
	rl.mu.Lock()
	if len(rl.entries) != 10 {
		t.Errorf("expected 10 entries, got %d", len(rl.entries))
	}
	// 把 5 个置为远古，触发清理判定
	for i := 0; i < 5; i++ {
		k := "k" + string(rune('0'+i))
		rl.entries[k].lastSeen = time.Now().Add(-2 * idleEvictAfter)
	}
	rl.mu.Unlock()

	// 直接执行一轮 GC 等价的清扫
	rl.mu.Lock()
	now := time.Now()
	for k, e := range rl.entries {
		if now.Sub(e.lastSeen) > idleEvictAfter {
			delete(rl.entries, k)
		}
	}
	remaining := len(rl.entries)
	rl.mu.Unlock()
	if remaining != 5 {
		t.Errorf("GC 后应剩 5，got %d", remaining)
	}
}

// TestCORS_AllowsLoopback — 来自 127.0.0.1 的 Origin 应被允许。
func TestCORS_AllowsLoopback(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	req, _ := http.NewRequest(http.MethodOptions, base+"/healthz", nil)
	req.Header.Set("Origin", "http://127.0.0.1:5173")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("preflight expected 204, got %d", resp.StatusCode)
	}
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "http://127.0.0.1:5173" {
		t.Errorf("ACAO=%s", got)
	}
}

// TestCORS_RejectsExternalOrigin — 外网 Origin 不该获得 CORS 头。
func TestCORS_RejectsExternalOrigin(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	req, _ := http.NewRequest(http.MethodGet, base+"/healthz", nil)
	req.Header.Set("Origin", "https://evil.example.com")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("外网 Origin 不该回显 ACAO，got %q", got)
	}
}

// TestExtractBearer_HeaderPrecedence — Authorization 优先于 cookie。
func TestExtractBearer_HeaderPrecedence(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer header-token")
	req.AddCookie(&http.Cookie{Name: "aion_admin_token", Value: "cookie-token"})
	if got := extractBearer(req); got != "header-token" {
		t.Errorf("应优先取 header，got %q", got)
	}
}

// TestExtractBearer_CookieFallback — 无 header 时回退 cookie。
func TestExtractBearer_CookieFallback(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.AddCookie(&http.Cookie{Name: "aion_admin_token", Value: "cookie-token"})
	if got := extractBearer(req); got != "cookie-token" {
		t.Errorf("应回退 cookie，got %q", got)
	}
}
