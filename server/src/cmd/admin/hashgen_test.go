// hashgen_test.go — 一次性 bcrypt 哈希生成器 (build tag 隔离，不入正常测试集)。
//
// 用途：在迁移期生成 admin_users 默认 superadmin 的 bcrypt cost=12 hash，
// 输出后我们把 hash 抄进 00136_admin_users.sql 的 INSERT。
//
// 跑法：go test -tags=hashgen ./cmd/admin -run TestGenerateDefaultAdminHash -v
//
// 这是一次性产出 — hash 抄入 SQL 后此文件保留作为"如何重新生成"的可执行文档。
//go:build hashgen

package main

import (
	"fmt"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

// TestGenerateDefaultAdminHash 生成默认 superadmin 密码的 bcrypt 哈希。
// 不在正常 test pass — 须通过 -tags=hashgen 显式触发。
func TestGenerateDefaultAdminHash(t *testing.T) {
	const plaintext = "sadmin-dev-pwd"
	h, err := bcrypt.GenerateFromPassword([]byte(plaintext), 12)
	if err != nil {
		t.Fatalf("bcrypt: %v", err)
	}
	fmt.Printf("\n\nplaintext = %q\nhash      = %s\n\n", plaintext, string(h))
}
