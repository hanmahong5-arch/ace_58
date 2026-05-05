# AionCore 5.8 代码风格指南 / Style Guide

> 范围：本仓库 `server/`。Go + Lua + SQL + Markdown + commit message + PR description。
> 大原则：一致性 > 个人喜好；可读性 > 简洁性；命名是文档。
>
> 配套阅读：[`dev-guide.md`](./dev-guide.md)（硬约束 / 反模式） ·
> [`architecture.md`](./architecture.md)（三层职责） ·
> [`glossary.md`](./glossary.md)（术语词典） ·
> [`../CLAUDE.md`](../CLAUDE.md)（7 大铁律）。

---

## 1. 通用 / General

- UTF-8 only，BOM 严禁。
- LF (Unix line ending)，包括 Windows 上提交时也走 `core.autocrlf=input`。
- 文件末尾保留单个换行。
- 行宽：Go ≤ 100；其它（Lua / SQL / Markdown）≤ 120。
- 文档以中文为主，代码注释中英文混排 OK；技术术语保留英文。
- 禁止中文标点出现在代码内（"，" / "。" / "（" → "," / "." / "("）。
- 缩进：Go 用 tab；Lua / SQL 用 4 空格；Markdown 用 2 空格。

## 2. Go

- `gofmt` 是最低线（CI enforce）；不要手工对齐。
- 包名：简短小写，无下划线（`luahost` / `aionproto` / `jobq`）。
- 命名：CamelCase 导出符号；camelCase 局部变量；snake_case 文件名（与 Lua 一致）。
- 接口在 **使用方** 定义（accept-interface, return-struct）；不滥用接口。
- 错误：
  - 显式 wrap：`fmt.Errorf("ctx: %w", err)`，不丢错（除测试 helper）。
  - sentinel error 在包顶层：`var ErrXxx = errors.New(...)`。
- 日志：`log/slog` 结构化；info / warn / error 三级；不用 `log.Printf`。
- 注释：每个 exported 符号一句 godoc，重点解释 **WHY**，不解释 WHAT。
- `panic` 仅限 init / 真正不可恢复；production 路径不 panic。
- `context.Context` 永远是第一个参数；不放进 struct 字段（除任务对象）。
- 测试包用 `_test` 后缀（`luahost_test`）当只测公开 API。

## 3. Lua

- 文件名 + 函数名：snake_case；module 名一般也 snake_case。
- Module 模式：lib/ 下使用 `M = {}; ...; return M` 或全局表 `pvp = {}`（看 lib/ 现状两种共存，新文件就近模仿）。
- 不污染 global namespace（除明示注册模式：技能 / 任务 / 副本 / 处理器自动加载）。
- 沙盒约束：仅 `base / table / string / math / os.time` 可用；不要尝试 `io.*` / `os.execute` / `require` 游戏模块（Bridge 已注入全局表）。
- 错误返回：用 `(false, "reason")` 二值；不用 `error()`抛异常（除非语义上确实是 bug）。
- API doc：在文件头部块注释列出所有 public 签名 + reasons 取值。
- 调 SP：`db.call("aion_xxx", arg1, arg2, ...)`，SP 名全小写（PG 不区分大小写但便于 grep）。
- 不写持久 closure / 长 timer / module-level 可变 table（破坏热重载语义）。
- 状态归宿：ECS 组件（`entity.set_stat`） / Redis / 关系表 / jobq；不放 Lua 进程内存。

## 4. SQL / PG SP

- SP 名：snake_case + `aion_` 前缀（NCSoft 历史惯例：`aion_getitem` / `aion_setuserinstance_20171122`）。
- 文件命名：`00NNN_sp_<name>.sql`，5 位数（4 + 0）零填充；同一 SP 改版用日期后缀（`_20171122`）保留 NCSoft 原始版本号。
- goose marker 必须双镜像：`sql/schema/` ↔ `src/internal/database/migrations/`（`go:embed` 限制）。
  - `-- +goose Up` / `-- +goose Down`
  - `-- +goose StatementBegin` / `-- +goose StatementEnd`（含 `$$` 函数体的语句必带）
- 每个 user_data SELECT 必带 `delete_date = 0` 软删除过滤。
- READ-ONLY SP 用 `STABLE`；只读但依赖 session 状态用 `VOLATILE`。
- 参数命名：`_param` 前缀避免与列名歧义（如 `_user_item_dbid`）。
- 用 `LANGUAGE plpgsql AS $$ ... $$;` 包裹函数体；不要用单引号字符串。
- `RETURNS TABLE` 优先于 `RETURNS SETOF record`（前者列名固定，调用方少踩坑）。

## 5. Commit message

格式：`<scope>: <imperative subject>`（subject ≤ 70 字符，imperative 动词）。

示例：

```
phase S-19: instance/dungeon MVP + jobq expiry + daily reset
SP: aion_AddItemUser (3-param wrapper for starter_kit)
engineering hardening: CI + benchmarks + telemetry + coverage
glossary: add legion ranks + manastone entry
```

要求：

- imperative：`add` / `fix` / `refactor`，不是 `added` / `fixed`。
- subject 不加句号 / 不加 emoji。
- body 详写动机 / 验证 / 风险（参见 CONTRIBUTING / 自查）；body 与 subject 之间空一行。
- `Co-Authored-By:` 行放尾部，前空一行。

## 6. PR description

必含 4 段：

- **What** — 改了什么（文件 / 函数 / SP 列表）。
- **Why** — 解决什么问题（链接 issue / 决策日志条目 / phase 编号）。
- **Verification** — 怎么验证（命令 + 输出 / 截图 / Grafana 指标）。
- **Risk** — 已知风险 + 回滚策略（特别是触及 crypto / DB schema / opcode 的变更）。

控制：

- 主体不超过 500 字符（除复杂 PR）；超长拆 issue。
- 触及红线（PG 暴露 / opcode 重排 / crypto 改动）必须 Opus 审核 + 显式标注。

## 7. Markdown

- 标题：H1 仅一个；H2 / H3 顺序，不跳层。
- 列表对齐：`-` 或 `1.`，全文不混用。
- 反引号成对；inline 用单 `` ` ``，块用三反引号 + 语言标签（` ```bash `）。
- 链接相对路径优先：同 `doc/` 内 `./architecture.md`，跨目录 `../README.zh-CN.md`。
- 中文段落不强制空格分隔；中英混排时英文术语两侧加空格（"调用 `db.call` 时"）。
- 表格头分隔行用 `|---|---|`，列对齐用 `:`（左 `:---`、中 `:---:`、右 `---:`）。

## 8. 文件大小 / 复杂度

- 单 Lua handler ≤ 100 行（超出拆 lib/ 复用）。
- 单 Go 文件 ≤ 600 行；同一目录下 1 个 `.go` + 1 个 `_test.go` 是骨架。
- 单函数 ≤ 80 行（dispatch table / generated 例外）。
- cyclomatic complexity ≤ 15（CI 可后续接 gocyclo 抽查）。

## 9. 测试

- 命名：`TestXxx_Scenario`（Go） / `test_xxx`（Lua bridge 测试）。
- 每个测试独立 cleanup band（PG 集成测试用临时 schema 或事务回滚）。
- env-gated 集成测试：`testDSN()` 模式；缺 env → `t.Skip()` 而非 fail。
- bench：`BenchmarkXxx`，调 `b.SetBytes(n)` / `b.ResetTimer()` 后再循环。
- 测试文件不能引入新依赖（除非测试用 helper 包，统一在 `internal/testutil` 之类下）。

## 10. 反模式（不要这样做）

1. 在 Go / Lua 写 inline `INSERT` / `UPDATE` / `DELETE`（违三层架构金律）。
2. 在 Lua 写并发原语（goroutine / channel / mutex）；并发归 Go runtime。
3. 编辑别人未提交的工作树文件（违并发会话协议；先 `sg lock`）。
4. `git add .` / `git add -A`（吞他人 WIP）；按文件名 stage。
5. 删 ADR / 决策文档（只能 supersede，写新条目覆盖旧条目）。
6. PG 暴露 0.0.0.0（违红线 + 勒索教训）。
7. `git rebase -i` / `git push --force` to main（违全局红线）。
8. 编译用 `release` flag（违全局 CLAUDE.md：dev only）。
9. 硬编码 ports / IPs / rates / 路径（一律走 TOML / 环境变量 / DB）。
10. 跳 hook（`--no-verify` / `--no-gpg-sign`）（违全局 CLAUDE.md，除非用户明示）。

---

## 引用 / References

- 架构总览：[`architecture.md`](./architecture.md)
- 开发指南：[`dev-guide.md`](./dev-guide.md)
- 术语词典：[`glossary.md`](./glossary.md)
- 协议字典：[`opcodes.md`](./opcodes.md)
- Lua API：[`lua-api.md`](./lua-api.md)
- 服务器级 CLAUDE.md：[`../CLAUDE.md`](../CLAUDE.md)
- 工作区入口：[`../../CLAUDE.md`](../../CLAUDE.md)
- 全局编码原则：`D:\拾光ai\CLAUDE.md`（项目根）

---

> 风格分歧时：以本文 + `dev-guide.md` 为准；本文未涉及的，沿用既有文件风格（最近邻原则）。
> 修改本文须同步更新引用本文的 PR 模板 / CI 检查脚本（如有）。
