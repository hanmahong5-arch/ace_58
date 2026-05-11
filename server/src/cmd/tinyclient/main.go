// Package main 实现 AION 5.8 协议的 Go 版极小客户端 (tinyclient)。
//
// Round 11 C8 升级：从 boot-test 客户端扩展为完整 PvE 链端到端验证客户端。
//
// 用途：作为 5 进程拓扑（gateway/world/chat/logd/admin）端到端冒烟测试 +
// "光辉永恒"高熵命题的第一次实测演示客户端。
//
// 阶段化跑法 (--stage):
//
//	login   ← SM_KEY → CM_AUTH_LOGIN → SM_LOGIN_OK
//	        → CM_PLAY → SM_PLAY_OK            (auth :2108 半边握手)
//	list    + SM_SESSION_KEY → CM_SESSION_CONFIRM
//	        ← SM_CHARACTER_LIST                (game :7777 上线 + 角色列表)
//	create  + 若 list 为空：CM_CREATE_CHARACTER → SM_CREATE_CHARACTER_RESPONSE
//	select  + （5.8 client 选角直接 enter；本步预留给将来 CM_CHARACTER_SELECT）
//	world   + CM_ENTER_WORLD → SM_ENTER_WORLD_RESPONSE
//	attack  + CM_USE_SKILL（含 target_id）→ SM_DIE
//	loot    + SM_LOOT_AVAILABLE ← CM_LOOT_ITEM → SM_LOOT_ITEMLIST
//	          打印 forge_id + stones + attrs (高熵命题 visible 验证)
//
// 默认 --stage loot 跑全链路；任何阶段失败 / 收意外 packet 详细 log + exit 1。
//
// 关键命令行参数：
//   - --mob-id     攻击目标 NPC entity id（B8 提供具体 mob template）
//   - --skill-id   攻击使用的技能模板 id（默认 1001 — 战士基础攻击）
//   - --account    账号名（≤17 chars）；默认随机
//   - --char-name  角色名；默认随机 8 字符
//   - --auth-only  只跑 login 段（兼容 Round 10 F4 boot-test 行为）
package main

import (
	"crypto/rand"
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"math/big"
	mrand "math/rand"
	"net"
	"os"
	"strings"
	"time"

	"aion58/internal/aionproto"
	"aion58/internal/crypto"
)

// 与 internal/aionproto 保持一致的常量（仅本工具内部使用，不导出）。
const (
	rsaBlockSize    = crypto.CredentialBlockSize // 128
	accountNameMax  = crypto.AccountNameMaxLen   // 17
	passwordOffset  = 18                         // RSA block 内 password 起始偏移
	passwordMaxLen  = rsaBlockSize - passwordOffset
	defaultAuthPort = 2108
	defaultGamePort = 7777
	defaultServerID = uint32(10)
	rsaPublicExp    = 65537 // 与 NCSoft 真端一致
	connectTimeout  = 5 * time.Second
	postLoginPause  = 100 * time.Millisecond // 给 NATS player.login → World 一点时间

	// 各阶段读包等待窗口 — 攻击 / loot 等服务端有 NPC AI / SP 调用的步骤
	// 给 5s；握手类 2s 足够。
	smCharListWindow = 5 * time.Second
	smEnterWorldWait = 5 * time.Second
	smDieWait        = 8 * time.Second
	smLootWait       = 8 * time.Second
)

// stage 枚举 — 与 --stage 参数一一对应。每后一个 stage 都包含前序所有步骤。
type stage int

const (
	stageLogin stage = iota
	stageList
	stageCreate
	stageSelect
	stageWorld
	stageAttack
	stageLoot
)

// stageNames 把 stage int 映射回字符串（出错时打印 + flag 解析时校验）。
var stageNames = map[string]stage{
	"login":  stageLogin,
	"list":   stageList,
	"create": stageCreate,
	"select": stageSelect,
	"world":  stageWorld,
	"attack": stageAttack,
	"loot":   stageLoot,
}

// stageOrdered 用于 stage >= target 比较 — 比 map 反查更快。
var stageOrdered = []string{"login", "list", "create", "select", "world", "attack", "loot"}

// LootResult 结构化保存 SM_LOOT_ITEMLIST 解析结果。Stones != nil 是命题验证的核心。
type LootResult struct {
	CorpseEID  int32
	ItemID     int32
	ItemCount  int32
	ItemUID    int32
	ForgeID    string  // 8 ASCII chars; entropy.forge_id 输出
	Stones     []int32 // 6 元素，0 = 空槽
	Attrs      []LootAttr
}

// LootAttr 一条 random_attr：attr_id 字符串 + value 数值。
type LootAttr struct {
	AttrID string
	Value  int32
}

// tinyClient 维护一次完整握手过程中的所有可变状态。
type tinyClient struct {
	host      string
	account   string
	password  string
	charName  string
	serverID  uint32
	mobID     int32
	skillID   int32
	logger    *slog.Logger
	endStage  stage

	conn   net.Conn
	bf     *crypto.BlowfishLE
	xorEnc *crypto.XORCipher // 客户端 → 服务端方向
	xorDec *crypto.XORCipher // 服务端 → 客户端方向
	encOn  bool              // 是否已激活 BF + XOR

	// 由 auth_phase 填充，供 game_phase 使用
	rsaModulus   []byte
	bfStaticKey  []byte
	sessionToken []byte

	// 由 list / create 阶段填充
	charID int32

	// 由 attack / loot 阶段填充
	lastDieEID int32
	loot       *LootResult
}

func main() {
	host := flag.String("host", "127.0.0.1", "gateway host")
	authPort := flag.Int("auth-port", defaultAuthPort, "gateway auth port")
	gamePort := flag.Int("game-port", defaultGamePort, "gateway game port")
	account := flag.String("account", "", "account name (<=17 chars; default random)")
	password := flag.String("password", "hunter2", "account password")
	charName := flag.String("char-name", "", "character name (default random 8 chars)")
	serverID := flag.Uint("server-id", uint(defaultServerID), "logical server selection")
	mobID := flag.Int("mob-id", 0, "target mob entity id (required for --stage attack/loot)")
	skillID := flag.Int("skill-id", 1001, "skill template id used for the attack")
	stageFlag := flag.String("stage", "loot", "max stage to run: login|list|create|select|world|attack|loot")
	authOnly := flag.Bool("auth-only", false, "(legacy) equivalent to --stage login")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	// 解析 --stage 字符串。
	endStage, ok := stageNames[strings.ToLower(*stageFlag)]
	if !ok {
		logger.Error("tinyclient: unknown --stage", "value", *stageFlag, "allowed", stageOrdered)
		os.Exit(2)
	}
	if *authOnly {
		endStage = stageLogin
	}

	// 随机账号 / 角色名（避免反复跑命中同名角色）。
	acctName := *account
	if acctName == "" {
		acctName = randName("dbg_", 12)
	}
	cName := *charName
	if cName == "" {
		cName = randName("Sg", 6)
	}

	// 攻击 / loot 阶段必须有 mob-id，否则提前给出明确错误。
	if endStage >= stageAttack && *mobID == 0 {
		logger.Error("tinyclient: --mob-id is required for stage>=attack",
			"stage", *stageFlag,
			"hint", "ask the B8 agent for a spawn-able mob entity id")
		os.Exit(2)
	}

	c := &tinyClient{
		host:     *host,
		account:  acctName,
		password: *password,
		charName: cName,
		serverID: uint32(*serverID),
		mobID:    int32(*mobID),
		skillID:  int32(*skillID),
		logger:   logger,
		endStage: endStage,
	}

	t0 := time.Now()
	logger.Info("tinyclient: start",
		"host", *host, "account", acctName, "char_name", cName,
		"end_stage", *stageFlag,
		"mob_id", *mobID, "skill_id", *skillID)

	// === 阶段 1: auth phase（login + (server list)） ===
	if err := c.authPhase(*authPort); err != nil {
		logger.Error("tinyclient: auth phase failed", "err", err)
		os.Exit(1)
	}
	logger.Info("tinyclient: auth phase OK", "elapsed", time.Since(t0))

	if c.endStage <= stageLogin {
		logger.Info("tinyclient: stopped at stage=login (auth-only)", "elapsed", time.Since(t0))
		os.Exit(0)
	}

	// 给 gateway → NATS → world 一点缓冲。
	time.Sleep(postLoginPause)

	// === 阶段 2..N: game phase ===
	if err := c.gamePhase(*gamePort); err != nil {
		logger.Error("tinyclient: game phase failed", "err", err, "elapsed", time.Since(t0))
		os.Exit(1)
	}

	// === 命题验证摘要打印 ===
	if c.loot != nil {
		nonZeroStones := 0
		for _, s := range c.loot.Stones {
			if s != 0 {
				nonZeroStones++
			}
		}
		logger.Info("tinyclient: LOOT verified — 光辉永恒命题第一次端到端实测",
			"item_id", c.loot.ItemID, "item_uid", c.loot.ItemUID,
			"forge_id", c.loot.ForgeID,
			"stones", c.loot.Stones,
			"non_zero_stones", nonZeroStones,
			"attrs_count", len(c.loot.Attrs))
		if c.loot.Stones == nil {
			logger.Error("tinyclient: SM_LOOT_ITEMLIST stones is nil — entropy 路径未通")
			os.Exit(1)
		}
	}

	logger.Info("tinyclient: end-to-end OK", "elapsed", time.Since(t0), "end_stage", *stageFlag)
}

// ---------------------------------------------------------------------------
// authPhase: SM_KEY → CM_AUTH_LOGIN → SM_LOGIN_OK → CM_PLAY → SM_PLAY_OK
// ---------------------------------------------------------------------------

// authPhase 走完 auth :2108 端口的完整握手。
func (c *tinyClient) authPhase(port int) error {
	if err := c.connect(port); err != nil {
		return fmt.Errorf("connect auth: %w", err)
	}
	defer c.close()

	// 1. SM_KEY (clear, 1B opcode auth format)
	opcode, body, err := c.readAuthPacket()
	if err != nil {
		return fmt.Errorf("read SM_KEY: %w", err)
	}
	if opcode != uint16(aionproto.SM_KEY) {
		return fmt.Errorf("expected SM_KEY (0x%02X), got 0x%02X", aionproto.SM_KEY, opcode)
	}
	// SM_INIT payload: sessionId(4) + revision(4) + RSA(128,scrambled) + pad(16) + BF(16) + ...
	const smInitMinLen = 4 + 4 + rsaBlockSize + 16 + 16
	if len(body) < smInitMinLen {
		return fmt.Errorf("SM_KEY body too short: %d bytes (need %d)", len(body), smInitMinLen)
	}
	scrambledMod := body[8 : 8+rsaBlockSize]
	c.rsaModulus = crypto.UnscrambleModulus(scrambledMod)
	c.bfStaticKey = append([]byte(nil), body[8+rsaBlockSize+16:8+rsaBlockSize+16+16]...)
	c.logger.Info("tinyclient: SM_KEY received",
		"bf_key", fmt.Sprintf("%x", c.bfStaticKey),
		"country", 5)

	if err := c.activateCrypto(c.bfStaticKey); err != nil {
		return fmt.Errorf("activate crypto: %w", err)
	}

	// 2. CM_AUTH_LOGIN (1B opcode auth format)
	cred, err := c.encryptCredentials()
	if err != nil {
		return fmt.Errorf("encrypt credentials: %w", err)
	}
	versionTail := []byte{0x01, 0x00, 0x00, 0x00}
	if err := c.sendAuthPacket(uint16(aionproto.CM_AUTH_LOGIN), append(cred, versionTail...)); err != nil {
		return fmt.Errorf("send CM_AUTH_LOGIN: %w", err)
	}
	c.logger.Info("tinyclient: CM_AUTH_LOGIN sent", "account", c.account)

	// 3. SM_LOGIN_OK / SM_LOGIN_FAIL (1B opcode)
	opcode, body, err = c.readAuthPacket()
	if err != nil {
		return fmt.Errorf("read SM_LOGIN result: %w", err)
	}
	switch opcode {
	case uint16(aionproto.SM_LOGIN_FAIL):
		var reason byte
		if len(body) > 0 {
			reason = body[0]
		}
		return fmt.Errorf("SM_LOGIN_FAIL reason=0x%02X", reason)
	case uint16(aionproto.SM_LOGIN_OK):
		if len(body) < 9 {
			return fmt.Errorf("SM_LOGIN_OK body too short: %d", len(body))
		}
		accountID := binary.LittleEndian.Uint64(body[0:8])
		c.logger.Info("tinyclient: SM_LOGIN_OK", "account_id", accountID, "servers", body[8])
	default:
		return fmt.Errorf("unexpected opcode after CM_AUTH_LOGIN: 0x%02X", opcode)
	}

	// 4. CM_PLAY (1B opcode)
	playPayload := make([]byte, 4)
	binary.LittleEndian.PutUint32(playPayload, c.serverID)
	if err := c.sendAuthPacket(uint16(aionproto.CM_PLAY), playPayload); err != nil {
		return fmt.Errorf("send CM_PLAY: %w", err)
	}

	// 5. SM_PLAY_OK / SM_PLAY_FAIL (1B opcode)
	opcode, body, err = c.readAuthPacket()
	if err != nil {
		return fmt.Errorf("read SM_PLAY result: %w", err)
	}
	switch opcode {
	case uint16(aionproto.SM_PLAY_FAIL):
		return fmt.Errorf("SM_PLAY_FAIL")
	case uint16(aionproto.SM_PLAY_OK):
		if len(body) < 20 {
			return fmt.Errorf("SM_PLAY_OK body too short: %d", len(body))
		}
		c.sessionToken = append([]byte(nil), body[4:20]...)
		c.logger.Info("tinyclient: SM_PLAY_OK", "token", fmt.Sprintf("%x", c.sessionToken))
	default:
		return fmt.Errorf("unexpected opcode after CM_PLAY: 0x%02X", opcode)
	}

	return nil
}

// ---------------------------------------------------------------------------
// gamePhase: 调度 list / create / select / world / attack / loot 子阶段
// ---------------------------------------------------------------------------

func (c *tinyClient) gamePhase(port int) error {
	if err := c.connect(port); err != nil {
		return fmt.Errorf("connect game: %w", err)
	}
	defer c.close()

	// 1) SM_SESSION_KEY → CM_SESSION_CONFIRM → SM_CHARACTER_LIST
	if err := c.gameHandshake(); err != nil {
		return fmt.Errorf("game handshake: %w", err)
	}
	if c.endStage <= stageList {
		c.logger.Info("tinyclient: stopped at stage=list", "char_id", c.charID)
		return nil
	}

	// 2) 角色不存在 → CM_CREATE_CHARACTER
	if c.charID == 0 {
		if err := c.createCharacter(); err != nil {
			return fmt.Errorf("create character: %w", err)
		}
	} else {
		c.logger.Info("tinyclient: character already exists, skipping create", "char_id", c.charID)
	}
	if c.endStage <= stageCreate {
		c.logger.Info("tinyclient: stopped at stage=create", "char_id", c.charID)
		return nil
	}

	// 3) 5.8 协议中 client 选角后直接 CM_ENTER_WORLD（无独立 select 包）。
	//    本步骤保留为 marker，保证 stage 顺序自洽。
	if c.endStage <= stageSelect {
		c.logger.Info("tinyclient: stopped at stage=select (5.8 has no separate CM_CHARACTER_SELECT)",
			"char_id", c.charID)
		return nil
	}

	// 4) CM_ENTER_WORLD
	if err := c.enterWorld(); err != nil {
		return fmt.Errorf("enter world: %w", err)
	}
	if c.endStage <= stageWorld {
		c.logger.Info("tinyclient: stopped at stage=world")
		return nil
	}

	// 5) CM_USE_SKILL → ... → SM_DIE
	if err := c.attackUntilDie(); err != nil {
		return fmt.Errorf("attack: %w", err)
	}
	if c.endStage <= stageAttack {
		c.logger.Info("tinyclient: stopped at stage=attack", "dead_eid", c.lastDieEID)
		return nil
	}

	// 6) SM_LOOT_AVAILABLE → CM_LOOT_ITEM → SM_LOOT_ITEMLIST
	if err := c.lootCorpse(); err != nil {
		return fmt.Errorf("loot: %w", err)
	}
	return nil
}

// gameHandshake 完成 game 端口建联三部曲：SESSION_KEY / CONFIRM / CHARACTER_LIST.
func (c *tinyClient) gameHandshake() error {
	// SM_SESSION_KEY (clear)
	opcode, body, err := c.readPacket()
	if err != nil {
		return fmt.Errorf("read SM_SESSION_KEY: %w", err)
	}
	if opcode != aionproto.SM_SESSION_KEY {
		return fmt.Errorf("expected SM_SESSION_KEY (0x%02X), got 0x%02X",
			aionproto.SM_SESSION_KEY, opcode)
	}
	if len(body) < 16 {
		return fmt.Errorf("SM_SESSION_KEY body too short: %d", len(body))
	}
	gameBFKey := body[:16]
	c.logger.Info("tinyclient: SM_SESSION_KEY received", "key", fmt.Sprintf("%x", gameBFKey))

	if err := c.activateCrypto(gameBFKey); err != nil {
		return fmt.Errorf("re-activate crypto with game key: %w", err)
	}

	// CM_SESSION_CONFIRM
	if c.sessionToken == nil {
		return fmt.Errorf("no session token from auth phase")
	}
	if err := c.sendPacket(aionproto.CM_SESSION_CONFIRM, c.sessionToken); err != nil {
		return fmt.Errorf("send CM_SESSION_CONFIRM: %w", err)
	}
	c.logger.Info("tinyclient: CM_SESSION_CONFIRM sent")

	// 等 SM_CHARACTER_LIST。
	if err := c.conn.SetReadDeadline(time.Now().Add(smCharListWindow)); err != nil {
		return fmt.Errorf("set read deadline: %w", err)
	}
	opcode, body, err = c.readPacket()
	if err != nil {
		return fmt.Errorf("await SM_CHARACTER_LIST: %w", err)
	}
	if opcode != aionproto.SM_CHARACTER_LIST {
		c.logger.Warn("tinyclient: first SM after CM_SESSION_CONFIRM was not SM_CHARACTER_LIST",
			"opcode", fmt.Sprintf("0x%02X", opcode), "payload_len", len(body))
		// 不算失败 — chat/logd/admin 可能先打了别的。继续读一次。
		opcode, body, err = c.readPacket()
		if err != nil {
			return fmt.Errorf("second read after non-CHAR_LIST: %w", err)
		}
		if opcode != aionproto.SM_CHARACTER_LIST {
			return fmt.Errorf("did not receive SM_CHARACTER_LIST (got 0x%02X)", opcode)
		}
	}
	count, charID, charName := parseCharacterList(body)
	c.logger.Info("tinyclient: SM_CHARACTER_LIST received",
		"count", count, "first_char_id", charID, "first_char_name", charName)
	c.charID = charID

	// 重置 deadline 以免影响后续读包。
	_ = c.conn.SetReadDeadline(time.Time{})
	return nil
}

// createCharacter 构造 CM_CREATE_CHARACTER 包并等 SM_CREATE_CHARACTER_RESPONSE。
func (c *tinyClient) createCharacter() error {
	body := encodeCreateCharacter(c.charName, 0 /*male*/, 0 /*Elyos*/, 0 /*Warrior*/)
	if err := c.sendPacket(aionproto.CM_CREATE_CHARACTER, body); err != nil {
		return fmt.Errorf("send CM_CREATE_CHARACTER: %w", err)
	}
	c.logger.Info("tinyclient: CM_CREATE_CHARACTER sent", "name", c.charName)

	if err := c.conn.SetReadDeadline(time.Now().Add(smEnterWorldWait)); err != nil {
		return err
	}
	opcode, payload, err := c.readPacket()
	if err != nil {
		return fmt.Errorf("await SM_CREATE_CHARACTER_RESPONSE: %w", err)
	}
	_ = c.conn.SetReadDeadline(time.Time{})
	if opcode != aionproto.SM_CREATE_CHARACTER_RESPONSE {
		return fmt.Errorf("expected SM_CREATE_CHARACTER_RESPONSE (0x%02X), got 0x%02X",
			aionproto.SM_CREATE_CHARACTER_RESPONSE, opcode)
	}
	result, charID, gotName := parseCreateCharResp(payload)
	if result != 0 {
		return fmt.Errorf("create char rejected result=%d (1=invalid_name, 2=taken, 3=forbidden, 7=db_error)", result)
	}
	c.charID = charID
	c.logger.Info("tinyclient: SM_CREATE_CHARACTER_RESPONSE OK",
		"char_id", charID, "name", gotName)
	return nil
}

// enterWorld 发 CM_ENTER_WORLD 并等 SM_ENTER_WORLD_RESPONSE。
func (c *tinyClient) enterWorld() error {
	if c.charID == 0 {
		return fmt.Errorf("no char_id to enter world with")
	}
	payload := make([]byte, 4)
	binary.LittleEndian.PutUint32(payload, uint32(c.charID))
	if err := c.sendPacket(aionproto.CM_ENTER_WORLD, payload); err != nil {
		return fmt.Errorf("send CM_ENTER_WORLD: %w", err)
	}
	c.logger.Info("tinyclient: CM_ENTER_WORLD sent", "char_id", c.charID)

	if err := c.conn.SetReadDeadline(time.Now().Add(smEnterWorldWait)); err != nil {
		return err
	}
	defer c.conn.SetReadDeadline(time.Time{})

	// 读包直到看到 SM_ENTER_WORLD_RESPONSE — 中间会有 SM_INVENTORY_INFO 等
	// follow-up packet，全部 log 不丢。
	deadline := time.Now().Add(smEnterWorldWait)
	for time.Now().Before(deadline) {
		opcode, body, err := c.readPacket()
		if err != nil {
			return fmt.Errorf("await SM_ENTER_WORLD_RESPONSE: %w", err)
		}
		if opcode == aionproto.SM_ENTER_WORLD_RESPONSE {
			c.logger.Info("tinyclient: SM_ENTER_WORLD_RESPONSE received",
				"payload_len", len(body))
			return nil
		}
		c.logger.Info("tinyclient: enter-world side packet",
			"opcode", fmt.Sprintf("0x%02X", opcode), "payload_len", len(body))
	}
	return fmt.Errorf("timeout waiting for SM_ENTER_WORLD_RESPONSE")
}

// attackUntilDie 用 CM_USE_SKILL 反复攻击直到收到 SM_DIE。
//
// 每轮发包后等 1.5s 收 SM_ATTACK / SM_SKILL_RESULT / SM_STAT_INFO 等更新；
// 任一时点收到 SM_DIE 即胜利返回。最多 12 轮（约 18s + handler 处理）。
func (c *tinyClient) attackUntilDie() error {
	const maxRounds = 12
	for round := 1; round <= maxRounds; round++ {
		// CM_USE_SKILL: int32 skill_id, int32 target_id, byte skill_lvl
		buf := make([]byte, 0, 9)
		buf = appendInt32(buf, c.skillID)
		buf = appendInt32(buf, c.mobID)
		buf = append(buf, 1) // skill_lvl=1
		if err := c.sendPacket(aionproto.CM_USE_SKILL, buf); err != nil {
			return fmt.Errorf("send CM_USE_SKILL: %w", err)
		}
		c.logger.Info("tinyclient: CM_USE_SKILL sent",
			"round", round, "skill_id", c.skillID, "target", c.mobID)

		// 在 1.5s 窗口内尽可能多吸收应答 packet。
		windowEnd := time.Now().Add(1500 * time.Millisecond)
		for time.Now().Before(windowEnd) {
			remaining := time.Until(windowEnd)
			if remaining < 50*time.Millisecond {
				break
			}
			if err := c.conn.SetReadDeadline(time.Now().Add(remaining)); err != nil {
				return err
			}
			opcode, body, err := c.readPacket()
			if err != nil {
				if isTimeout(err) {
					break // 本轮没更多包，进入下一轮发攻击
				}
				return fmt.Errorf("read during attack: %w", err)
			}
			c.logger.Info("tinyclient: attack-window packet",
				"round", round,
				"opcode", fmt.Sprintf("0x%02X", opcode),
				"payload_len", len(body))
			if opcode == aionproto.SM_DIE {
				if len(body) >= 4 {
					c.lastDieEID = int32(binary.LittleEndian.Uint32(body[:4]))
				}
				_ = c.conn.SetReadDeadline(time.Time{})
				c.logger.Info("tinyclient: SM_DIE received", "dead_eid", c.lastDieEID)
				return nil
			}
		}
	}
	_ = c.conn.SetReadDeadline(time.Time{})
	return fmt.Errorf("did not see SM_DIE after %d attack rounds (mob may be unkillable / handler missing)", maxRounds)
}

// lootCorpse 等 SM_LOOT_AVAILABLE → 发 CM_LOOT_ITEM → 收 SM_LOOT_ITEMLIST.
//
// SM_LOOT_AVAILABLE 可能在 SM_DIE 之前 / 之后 / 同时到达，本函数允许 8s 窗口
// 中任意时刻看到它；收齐后立刻发 CM_LOOT_ITEM(slot=0)。
func (c *tinyClient) lootCorpse() error {
	if err := c.conn.SetReadDeadline(time.Now().Add(smLootWait)); err != nil {
		return err
	}
	defer c.conn.SetReadDeadline(time.Time{})

	// 等 SM_LOOT_AVAILABLE
	var corpseEID int32
	var itemCount int32
	deadline := time.Now().Add(smLootWait)
	for time.Now().Before(deadline) {
		opcode, body, err := c.readPacket()
		if err != nil {
			if isTimeout(err) {
				return fmt.Errorf("timeout waiting for SM_LOOT_AVAILABLE (server may not have wired loot drop yet)")
			}
			return fmt.Errorf("read SM_LOOT_AVAILABLE: %w", err)
		}
		if opcode == aionproto.SM_LOOT_AVAILABLE {
			if len(body) < 8 {
				return fmt.Errorf("SM_LOOT_AVAILABLE body too short: %d", len(body))
			}
			corpseEID = int32(binary.LittleEndian.Uint32(body[0:4]))
			itemCount = int32(binary.LittleEndian.Uint32(body[4:8]))
			c.logger.Info("tinyclient: SM_LOOT_AVAILABLE received",
				"corpse_eid", corpseEID, "item_count", itemCount)
			break
		}
		c.logger.Info("tinyclient: pre-loot side packet",
			"opcode", fmt.Sprintf("0x%02X", opcode), "payload_len", len(body))
	}
	if corpseEID == 0 {
		return fmt.Errorf("never saw SM_LOOT_AVAILABLE within %v", smLootWait)
	}
	if itemCount == 0 {
		return fmt.Errorf("SM_LOOT_AVAILABLE reports 0 items — drop pool empty (B8 needs to attach loot table)")
	}

	// 发 CM_LOOT_ITEM(slot=0)
	pickup := make([]byte, 0, 8)
	pickup = appendInt32(pickup, corpseEID)
	pickup = appendInt32(pickup, 0) // 取第 0 槽
	if err := c.sendPacket(aionproto.CM_LOOT_ITEM, pickup); err != nil {
		return fmt.Errorf("send CM_LOOT_ITEM: %w", err)
	}
	c.logger.Info("tinyclient: CM_LOOT_ITEM sent", "corpse_eid", corpseEID, "slot", 0)

	// 等 SM_LOOT_ITEMLIST
	if err := c.conn.SetReadDeadline(time.Now().Add(smLootWait)); err != nil {
		return err
	}
	for time.Now().Before(time.Now().Add(smLootWait)) {
		opcode, body, err := c.readPacket()
		if err != nil {
			if isTimeout(err) {
				return fmt.Errorf("timeout waiting for SM_LOOT_ITEMLIST")
			}
			return fmt.Errorf("read SM_LOOT_ITEMLIST: %w", err)
		}
		if opcode == aionproto.SM_LOOT_ITEMLIST {
			loot, err := parseLootItemlist(body)
			if err != nil {
				return fmt.Errorf("parse SM_LOOT_ITEMLIST: %w", err)
			}
			c.loot = loot
			return nil
		}
		c.logger.Info("tinyclient: post-pickup side packet",
			"opcode", fmt.Sprintf("0x%02X", opcode), "payload_len", len(body))
	}
	return fmt.Errorf("never saw SM_LOOT_ITEMLIST")
}

// ---------------------------------------------------------------------------
// 编解码 helper（独立函数 — 单测直接拿）
// ---------------------------------------------------------------------------

// encodeCreateCharacter 构造 CM_CREATE_CHARACTER 的 payload，与
// scripts/handlers/cm_create_character.lua 的 read_utf16_null + 后续字段读序
// 严格对齐。
//
// 字段顺序（LE）:
//
//	utf16_null name
//	byte gender, byte race, byte class
//	int32 face_color, int32 hair_color, int32 eye_color, int32 lip_color
//	byte face_type, byte hair_type, byte voice_type
//	float32 scale
func encodeCreateCharacter(name string, gender, race, classID byte) []byte {
	buf := make([]byte, 0, 64)
	// utf16 LE + null term
	for _, r := range name {
		var tmp [2]byte
		binary.LittleEndian.PutUint16(tmp[:], uint16(r))
		buf = append(buf, tmp[:]...)
	}
	buf = append(buf, 0x00, 0x00)
	buf = append(buf, gender, race, classID)
	buf = appendInt32(buf, 0x00FFD0B8) // face_color (random)
	buf = appendInt32(buf, 0x00808080) // hair_color
	buf = appendInt32(buf, 0x00404060) // eye_color
	buf = appendInt32(buf, 0x00C04040) // lip_color
	buf = append(buf, 0, 0, 0)         // face/hair/voice type
	scaleBits := uint32(0x3F800000)    // float32(1.0)
	tmp := make([]byte, 4)
	binary.LittleEndian.PutUint32(tmp, scaleBits)
	buf = append(buf, tmp...)
	return buf
}

// parseCharacterList 解析 SM_CHARACTER_LIST。AION 5.8 服务端实际推送两种格式：
//
//  1. dispatcher.go (CM_SESSION_CONFIRM 后异步推) — byte server_index +
//     byte max_slots + byte count + N×(int32 char_id, int32 account_id,
//     utf16_null name, byte race, byte class, ...)
//  2. cm_character_list.lua (client refresh) — int32 count +
//     N×(int32 char_id, utf16_null name)
//
// 实测 Round 11 联调走的是路径 1。本函数优先按路径 1 解析，count==0 返回早退。
// 对于路径 2 的回退由调用方按二次启发式自行识别（极少触发，列表 refresh 不在
// 默认 PvE 链上）。返回 (count, 第一个 char_id, 第一个 name)。
func parseCharacterList(body []byte) (count int32, firstID int32, firstName string) {
	if len(body) == 0 {
		return 0, 0, ""
	}
	// 路径 1: dispatcher 格式 — body[0]=server_index, body[1]=max_slots, body[2]=count
	if len(body) >= 3 {
		count = int32(body[2])
		if count == 0 {
			return 0, 0, ""
		}
		// 第一个 entry 起于 offset 3：char_id(4) + account_id(4) + utf16_null name
		if len(body) >= 3+4+4 {
			firstID = int32(binary.LittleEndian.Uint32(body[3:7]))
			name, _ := readUTF16NullAt(body, 11)
			return count, firstID, name
		}
		return count, 0, ""
	}
	return 0, 0, ""
}

// parseCreateCharResp: byte result, int32 char_id, utf16_null name.
func parseCreateCharResp(body []byte) (result byte, charID int32, name string) {
	if len(body) < 5 {
		return 0xFF, 0, ""
	}
	result = body[0]
	charID = int32(binary.LittleEndian.Uint32(body[1:5]))
	name, _ = readUTF16NullAt(body, 5)
	return
}

// parseLootItemlist 解析 SM_LOOT_ITEMLIST 的完整 payload（见 opcodes.go 注释）。
func parseLootItemlist(body []byte) (*LootResult, error) {
	if len(body) < 4+4+4+4+8+4 {
		return nil, fmt.Errorf("body too short: %d", len(body))
	}
	r := &LootResult{}
	off := 0
	r.CorpseEID = int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	r.ItemID = int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	r.ItemCount = int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	r.ItemUID = int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	if off+8 > len(body) {
		return nil, fmt.Errorf("forge_id truncated")
	}
	r.ForgeID = string(body[off : off+8])
	off += 8

	stoneCount := int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	if stoneCount < 0 || stoneCount > 32 {
		return nil, fmt.Errorf("absurd stone_count=%d", stoneCount)
	}
	if off+int(stoneCount)*4 > len(body) {
		return nil, fmt.Errorf("stones truncated: need %d bytes, have %d",
			int(stoneCount)*4, len(body)-off)
	}
	r.Stones = make([]int32, stoneCount)
	for i := int32(0); i < stoneCount; i++ {
		r.Stones[i] = int32(binary.LittleEndian.Uint32(body[off:]))
		off += 4
	}

	if off+4 > len(body) {
		// 没有 attrs 段也算合法（早期 server wiring 可能只发 stones）。
		return r, nil
	}
	attrCount := int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	if attrCount < 0 || attrCount > 64 {
		return nil, fmt.Errorf("absurd attr_count=%d", attrCount)
	}
	for i := int32(0); i < attrCount; i++ {
		name, n := readUTF16NullAt(body, off)
		off += n
		if off+4 > len(body) {
			return nil, fmt.Errorf("attr value truncated at idx %d", i)
		}
		val := int32(binary.LittleEndian.Uint32(body[off:]))
		off += 4
		r.Attrs = append(r.Attrs, LootAttr{AttrID: name, Value: val})
	}
	return r, nil
}

// readUTF16NullAt 从 body[off:] 读 utf16 LE null-terminated 字符串。
// 返回字符串 + 已消费字节数（含 2 字节终止符）。非 ASCII 用 '?' 替代。
func readUTF16NullAt(body []byte, off int) (string, int) {
	var sb strings.Builder
	consumed := 0
	for off+consumed+1 < len(body) {
		code := binary.LittleEndian.Uint16(body[off+consumed:])
		consumed += 2
		if code == 0 {
			break
		}
		if code < 0x80 {
			sb.WriteByte(byte(code))
		} else {
			sb.WriteByte('?')
		}
	}
	return sb.String(), consumed
}

// appendInt32 追加 int32 LE。
func appendInt32(buf []byte, v int32) []byte {
	var tmp [4]byte
	binary.LittleEndian.PutUint32(tmp[:], uint32(v))
	return append(buf, tmp[:]...)
}

// isTimeout 判定是否 net 超时错误（用于 read deadline 触发的 i/o timeout）。
func isTimeout(err error) bool {
	type timeouter interface{ Timeout() bool }
	if te, ok := err.(timeouter); ok {
		return te.Timeout()
	}
	// readPacket wrap 一层，需要逐层 unwrap。
	for inner := err; inner != nil; {
		if te, ok := inner.(timeouter); ok && te.Timeout() {
			return true
		}
		type wrapper interface{ Unwrap() error }
		if w, ok := inner.(wrapper); ok {
			inner = w.Unwrap()
			continue
		}
		break
	}
	return false
}

// randName 生成一个 alphanum 后缀的随机标识，避免反复跑命中重名。
func randName(prefix string, n int) string {
	const alphabet = "abcdefghijkmnpqrstuvwxyz23456789"
	// 优先用 crypto/rand；失败回落到 math/rand（仅本工具，不影响生产）。
	out := []byte(prefix)
	for i := 0; i < n; i++ {
		bi, err := rand.Int(rand.Reader, big.NewInt(int64(len(alphabet))))
		if err != nil {
			out = append(out, alphabet[mrand.Intn(len(alphabet))])
		} else {
			out = append(out, alphabet[bi.Int64()])
		}
	}
	return string(out)
}

// ---------------------------------------------------------------------------
// 底层 I/O + 加密辅助函数（与 Round 10 F4 实现一致）
// ---------------------------------------------------------------------------

func (c *tinyClient) connect(port int) error {
	d := net.Dialer{Timeout: connectTimeout}
	conn, err := d.Dial("tcp", net.JoinHostPort(c.host, fmt.Sprintf("%d", port)))
	if err != nil {
		return err
	}
	c.conn = conn
	c.bf = nil
	c.xorEnc = crypto.NewXORCipher()
	c.xorDec = crypto.NewXORCipher()
	c.encOn = false
	return nil
}

func (c *tinyClient) close() {
	if c.conn != nil {
		_ = c.conn.Close()
		c.conn = nil
	}
}

func (c *tinyClient) activateCrypto(bfKey []byte) error {
	bf, err := crypto.NewBlowfishLE(bfKey)
	if err != nil {
		return err
	}
	c.bf = bf
	c.xorEnc = crypto.NewXORCipher()
	c.xorDec = crypto.NewXORCipher()
	c.encOn = true
	return nil
}

// readAuthPacket reads an auth-port packet with 1B opcode.
func (c *tinyClient) readAuthPacket() (uint16, []byte, error) {
	header := make([]byte, aionproto.HeaderSize)
	if _, err := io.ReadFull(c.conn, header); err != nil {
		return 0, nil, fmt.Errorf("read header: %w", err)
	}
	totalLen := binary.LittleEndian.Uint16(header)
	if int(totalLen) < 3 {
		return 0, nil, fmt.Errorf("packet length %d below min 3", totalLen)
	}
	body := make([]byte, int(totalLen)-aionproto.HeaderSize)
	if _, err := io.ReadFull(c.conn, body); err != nil {
		return 0, nil, fmt.Errorf("read body: %w", err)
	}
	if c.encOn {
		c.xorDec.Decode(body)
		c.decryptBody(body)
	}
	if len(body) < 1 {
		return 0, nil, fmt.Errorf("body too short for auth opcode")
	}
	return uint16(body[0]), body[1:], nil
}

// sendAuthPacket sends an auth-port packet with 1B opcode.
func (c *tinyClient) sendAuthPacket(opcode uint16, payload []byte) error {
	bodyLen := 1 + len(payload)
	pad := (-bodyLen) & (aionproto.BlockSize - 1)
	totalLen := aionproto.HeaderSize + bodyLen + pad
	buf := make([]byte, totalLen)
	binary.LittleEndian.PutUint16(buf[0:], uint16(totalLen))
	buf[aionproto.HeaderSize] = byte(opcode)
	copy(buf[aionproto.HeaderSize+1:], payload)
	if c.encOn {
		c.encryptBody(buf[aionproto.HeaderSize:])
		c.xorEnc.Encode(buf[aionproto.HeaderSize:])
	}
	_, err := c.conn.Write(buf)
	return err
}

func (c *tinyClient) readPacket() (uint16, []byte, error) {
	header := make([]byte, aionproto.HeaderSize)
	if _, err := io.ReadFull(c.conn, header); err != nil {
		return 0, nil, fmt.Errorf("read header: %w", err)
	}
	totalLen := binary.LittleEndian.Uint16(header)
	if int(totalLen) < aionproto.MinPacketSize {
		return 0, nil, fmt.Errorf("packet length %d below min %d", totalLen, aionproto.MinPacketSize)
	}
	body := make([]byte, int(totalLen)-aionproto.HeaderSize)
	if _, err := io.ReadFull(c.conn, body); err != nil {
		return 0, nil, fmt.Errorf("read body: %w", err)
	}

	if c.encOn {
		c.xorDec.Decode(body)
		c.decryptBody(body)
	}

	if len(body) < 2 {
		return 0, nil, fmt.Errorf("decrypted body too short for opcode: %d", len(body))
	}
	opcode := binary.LittleEndian.Uint16(body[:2])
	return opcode, body[2:], nil
}

func (c *tinyClient) sendPacket(opcode uint16, payload []byte) error {
	bodyLen := 2 + len(payload)
	pad := (-bodyLen) & (aionproto.BlockSize - 1)
	totalLen := aionproto.HeaderSize + bodyLen + pad

	pkt := make([]byte, totalLen)
	binary.LittleEndian.PutUint16(pkt[0:], uint16(totalLen))
	binary.LittleEndian.PutUint16(pkt[aionproto.HeaderSize:], opcode)
	copy(pkt[aionproto.HeaderSize+2:], payload)

	if c.encOn {
		body := pkt[aionproto.HeaderSize:]
		c.xorEnc.Encode(body)
		c.encryptBody(body)
	}

	_, err := c.conn.Write(pkt)
	return err
}

func (c *tinyClient) encryptBody(body []byte) {
	for off := 0; off+aionproto.BlockSize <= len(body); off += aionproto.BlockSize {
		c.bf.EncryptBlock(body[off:off+aionproto.BlockSize], body[off:off+aionproto.BlockSize])
	}
}

func (c *tinyClient) decryptBody(body []byte) {
	for off := 0; off+aionproto.BlockSize <= len(body); off += aionproto.BlockSize {
		c.bf.DecryptBlock(body[off:off+aionproto.BlockSize], body[off:off+aionproto.BlockSize])
	}
}

// encryptCredentials 构造 RSA-NoPad 加密的 128 字节凭据块。
//
// 明文 layout (与 server/internal/crypto/rsa.go ParseCredentials 对称)：
//
//	[0]      scramble byte = 0x00
//	[1..17]  account name (17 bytes, null padded)
//	[18..127] password (110 bytes, null padded)
func (c *tinyClient) encryptCredentials() ([]byte, error) {
	if len(c.account) > accountNameMax {
		return nil, fmt.Errorf("account name too long: %d > %d", len(c.account), accountNameMax)
	}
	if len(c.password) > passwordMaxLen {
		return nil, fmt.Errorf("password too long: %d > %d", len(c.password), passwordMaxLen)
	}

	plain := make([]byte, rsaBlockSize)
	plain[0] = 0x00
	copy(plain[1:], c.account)
	copy(plain[passwordOffset:], c.password)

	n := new(big.Int).SetBytes(c.rsaModulus)
	m := new(big.Int).SetBytes(plain)
	if m.Cmp(n) >= 0 {
		return nil, fmt.Errorf("plaintext >= modulus (m bit too high; check scramble byte)")
	}
	e := big.NewInt(int64(rsaPublicExp))
	cInt := new(big.Int).Exp(m, e, n)

	cipherBytes := cInt.Bytes()
	if len(cipherBytes) > rsaBlockSize {
		return nil, fmt.Errorf("ciphertext > block size: %d", len(cipherBytes))
	}
	out := make([]byte, rsaBlockSize)
	copy(out[rsaBlockSize-len(cipherBytes):], cipherBytes)
	return out, nil
}
