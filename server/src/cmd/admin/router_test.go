// router_test.go — 端到端 HTTP 测试（healthz / metrics / RBAC / stub endpoints）
package main

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

// authedRequest 构造带 Bearer token 的请求并发送；caller 负责 Close body。
func authedRequest(t *testing.T, method, url, token string, body io.Reader) *http.Response {
	t.Helper()
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		t.Fatalf("new req: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	return resp
}

// TestHealthz_Public — 无 token 也能 200。
func TestHealthz_Public(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	resp, err := http.Get(base + "/healthz")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
	var m map[string]string
	_ = json.NewDecoder(resp.Body).Decode(&m)
	if m["status"] != "ok" {
		t.Errorf("status=%s", m["status"])
	}
}

// TestMetrics_Public — /metrics 公开（按 Prometheus 抓取惯例不该鉴权）。
func TestMetrics_Public(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	resp, err := http.Get(base + "/metrics")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(body), "go_") {
		// 默认 prom Handler 至少暴露 go_* 指标
		t.Errorf("metrics body 没有 go_* 指标，body=%s", string(body)[:200])
	}
}

// TestPlayers_RequiresAuth — 无 token 401。
func TestPlayers_RequiresAuth(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	resp := authedRequest(t, http.MethodGet, base+"/api/v1/players", "", nil)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

// TestPlayers_GetWithReadonly — readonly 能读列表 200。
func TestPlayers_GetWithReadonly(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	tok := loginAs(t, base, "readonly", "ro-dev-pwd")
	resp := authedRequest(t, http.MethodGet, base+"/api/v1/players", tok, nil)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

// TestPlayers_GetByID — gm 能查单个玩家，URL 参数应回显。
func TestPlayers_GetByID(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	tok := loginAs(t, base, "gm", "gm-dev-pwd")
	resp := authedRequest(t, http.MethodGet, base+"/api/v1/players/12345", tok, nil)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
	var m map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&m)
	if m["id"] != "12345" {
		t.Errorf("id 没回显，got %v", m["id"])
	}
}

// TestRBAC_ReadonlyCannotBan — readonly 调 POST /ban 应 403。
func TestRBAC_ReadonlyCannotBan(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	tok := loginAs(t, base, "readonly", "ro-dev-pwd")
	resp := authedRequest(t, http.MethodPost, base+"/api/v1/players/42/ban", tok, strings.NewReader("{}"))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403, got %d", resp.StatusCode)
	}
}

// TestRBAC_GMCanBan — gm 调 POST /ban 应 202（异步派发语义）。
func TestRBAC_GMCanBan(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	tok := loginAs(t, base, "gm", "gm-dev-pwd")
	resp := authedRequest(t, http.MethodPost, base+"/api/v1/players/42/ban", tok, strings.NewReader("{}"))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		t.Errorf("expected 202, got %d", resp.StatusCode)
	}
	var m map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&m)
	if m["by"] != "gm" {
		t.Errorf("by claim 应为 gm，got %v", m["by"])
	}
}

// TestServerStats_Readonly — readonly 能拉 stats。
func TestServerStats_Readonly(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	tok := loginAs(t, base, "readonly", "ro-dev-pwd")
	resp := authedRequest(t, http.MethodGet, base+"/api/v1/server/stats", tok, nil)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

// TestPlayers_KickRequiresGM — readonly kick 403；gm kick 202。
func TestPlayers_KickRequiresGM(t *testing.T) {
	base, _, cleanup := newTestServer(t)
	defer cleanup()
	roTok := loginAs(t, base, "readonly", "ro-dev-pwd")
	resp := authedRequest(t, http.MethodPost, base+"/api/v1/players/7/kick", roTok, strings.NewReader("{}"))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("readonly kick 应 403，got %d", resp.StatusCode)
	}

	gmTok := loginAs(t, base, "gm", "gm-dev-pwd")
	resp2 := authedRequest(t, http.MethodPost, base+"/api/v1/players/7/kick", gmTok, strings.NewReader("{}"))
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusAccepted {
		t.Errorf("gm kick 应 202，got %d", resp2.StatusCode)
	}
}
