// Package config loads TOML configuration files and provides hot-reload
// via fsnotify.  All configuration is read-only after loading; changes to
// the underlying files are delivered through a registered callback.
//
// Hot-reload is intentionally limited to rates.toml (game multipliers) so
// that game designers can adjust drop/exp rates without restarting the server.
// Gateway and world config changes require a restart for safety.
package config

import (
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/pelletier/go-toml/v2"
)

// --- Gateway config ---

// GatewayConfig is the typed representation of config/gateway.toml.
type GatewayConfig struct {
	Server   GatewayServer   `toml:"server"`
	Crypto   GatewayCrypto   `toml:"crypto"`
	Database DatabaseConfig  `toml:"database"`
	Redis    RedisConfig     `toml:"redis"`
	NATS     NATSConfig      `toml:"nats"`
}

// GatewayServer holds listener and identity settings.
type GatewayServer struct {
	AuthListen     string `toml:"auth_listen"`     // e.g. "0.0.0.0:2108"
	GameListen     string `toml:"game_listen"`     // e.g. "0.0.0.0:7777"
	MaxConnections int    `toml:"max_connections"` // e.g. 2000
	Country        int    `toml:"country"`         // 5 = China
	ServerID       int    `toml:"server_id"`       // 10 = NCSoft original
}

// GatewayCrypto holds cryptographic parameters.
type GatewayCrypto struct {
	// BFStaticKey is the hex-encoded 16-byte static Blowfish key.
	// This is sent to clients inside SM_KEY and used to decrypt CM_AUTH_LOGIN.
	BFStaticKey string `toml:"bf_static_key"`

	// RSAKeyFile is the path to the PEM-encoded RSA-1024 private key.
	// If the file does not exist, a new key pair is generated and saved.
	RSAKeyFile string `toml:"rsa_key_file"`
}

// --- World config ---

// WorldConfig is the typed representation of config/world.toml.
type WorldConfig struct {
	Server   WorldServer    `toml:"server"`
	Database DatabaseConfig `toml:"database"`
	Redis    RedisConfig    `toml:"redis"`
	NATS     NATSConfig     `toml:"nats"`
	Lua      LuaConfig      `toml:"lua"`
	World    WorldSettings  `toml:"world"`
}

// WorldServer holds listener and capacity settings.
type WorldServer struct {
	TickRate   int `toml:"tick_rate"`   // game loop ticks/second, e.g. 20
	MaxPlayers int `toml:"max_players"` // max concurrent players, e.g. 1800
}

// LuaConfig controls the embedded Lua VM.
type LuaConfig struct {
	ScriptsDir      string `toml:"scripts_dir"`       // path to scripts/ directory
	HotReload       bool   `toml:"hot_reload"`        // enable fsnotify watcher
	ReloadIntervalMs int   `toml:"reload_interval_ms"` // debounce interval
}

// WorldSettings holds world-level parameters.
type WorldSettings struct {
	MaxUserLevel  int    `toml:"max_user_level"` // 80
	DropMultiple  int    `toml:"drop_multiple"`  // 200 = 2x drop rate
	SpawnVersion  string `toml:"spawn_version"`  // "040014200"
}

// --- Rates config (hot-reloadable) ---

// RatesConfig is the typed representation of config/rates.toml.
// This is the only config that supports hot-reload.
type RatesConfig struct {
	Exp  ExpRates  `toml:"exp"`
	Drop DropRates `toml:"drop"`
}

// ExpRates holds experience multipliers.
type ExpRates struct {
	Solo  float64 `toml:"solo"`
	Group float64 `toml:"group"`
}

// DropRates holds drop rate multipliers.
type DropRates struct {
	Normal float64 `toml:"normal"`
	Boss   float64 `toml:"boss"`
}

// --- Shared config types ---

// DatabaseConfig holds PostgreSQL connection parameters.
// The password is always read from the environment variable named by PasswordEnv.
type DatabaseConfig struct {
	Host        string `toml:"host"`
	Port        int    `toml:"port"`
	Name        string `toml:"name"`
	User        string `toml:"user"`
	PasswordEnv string `toml:"password_env"` // env var name, e.g. "AIONCORE_DB_PASS"
	PoolSize    int    `toml:"pool_size"`
}

// DSN returns the pgx connection string for this database.
// The password is resolved from the environment at call time.
func (d DatabaseConfig) DSN() string {
	pass := os.Getenv(d.PasswordEnv)
	return fmt.Sprintf("host=%s port=%d dbname=%s user=%s password=%s pool_max_conns=%d",
		d.Host, d.Port, d.Name, d.User, pass, d.PoolSize)
}

// RedisConfig holds Redis connection parameters.
type RedisConfig struct {
	Addr     string `toml:"addr"`
	DB       int    `toml:"db"`
	PoolSize int    `toml:"pool_size"`
}

// NATSConfig holds NATS connection parameters.
type NATSConfig struct {
	URL string `toml:"url"`
}

// --- Loader ---

// Loader reads TOML configuration files and watches rates.toml for changes.
type Loader struct {
	configDir string
	watcher   *fsnotify.Watcher
	mu        sync.RWMutex
	rates     RatesConfig
	onChange  []func(RatesConfig)
	done      chan struct{}
}

// NewLoader creates a Loader rooted at configDir and starts the file watcher.
func NewLoader(configDir string) (*Loader, error) {
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, fmt.Errorf("config: create watcher: %w", err)
	}
	l := &Loader{
		configDir: configDir,
		watcher:   w,
		done:      make(chan struct{}),
	}
	return l, nil
}

// LoadGateway reads and parses config/gateway.toml.
func (l *Loader) LoadGateway() (GatewayConfig, error) {
	var cfg GatewayConfig
	if err := l.decode("gateway.toml", &cfg); err != nil {
		return cfg, err
	}
	return cfg, nil
}

// LoadWorld reads and parses config/world.toml.
func (l *Loader) LoadWorld() (WorldConfig, error) {
	var cfg WorldConfig
	if err := l.decode("world.toml", &cfg); err != nil {
		return cfg, err
	}
	return cfg, nil
}

// LoadRates reads and parses config/rates.toml, caching the result.
// Subsequent calls to Rates() return the cached (possibly hot-reloaded) value.
func (l *Loader) LoadRates() (RatesConfig, error) {
	var cfg RatesConfig
	if err := l.decode("rates.toml", &cfg); err != nil {
		return cfg, err
	}
	l.mu.Lock()
	l.rates = cfg
	l.mu.Unlock()
	return cfg, nil
}

// Rates returns the most-recently-loaded rates configuration.
// Safe for concurrent use; updated automatically on hot-reload.
func (l *Loader) Rates() RatesConfig {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.rates
}

// OnRatesChange registers a callback that fires whenever rates.toml is reloaded.
// Callbacks are invoked on a background goroutine; they must not block.
func (l *Loader) OnRatesChange(fn func(RatesConfig)) {
	l.mu.Lock()
	l.onChange = append(l.onChange, fn)
	l.mu.Unlock()
}

// WatchRates starts a background goroutine that reloads rates.toml on file change.
// Call Close() to stop watching.
func (l *Loader) WatchRates() error {
	path := filepath.Join(l.configDir, "rates.toml")
	if err := l.watcher.Add(path); err != nil {
		return fmt.Errorf("config: watch %s: %w", path, err)
	}
	go l.watchLoop()
	return nil
}

// Close stops the file watcher and releases resources.
func (l *Loader) Close() error {
	close(l.done)
	return l.watcher.Close()
}

func (l *Loader) decode(filename string, v any) error {
	path := filepath.Join(l.configDir, filename)
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("config: read %s: %w", filename, err)
	}
	if err := toml.Unmarshal(data, v); err != nil {
		return fmt.Errorf("config: parse %s: %w", filename, err)
	}
	return nil
}

func (l *Loader) watchLoop() {
	// Debounce: coalesce rapid file events (editor save-and-swap sequences)
	// into a single reload after a short quiet period.
	const debounce = 200 * time.Millisecond
	var timer *time.Timer

	for {
		select {
		case <-l.done:
			if timer != nil {
				timer.Stop()
			}
			return

		case event, ok := <-l.watcher.Events:
			if !ok {
				return
			}
			if event.Has(fsnotify.Write) || event.Has(fsnotify.Create) {
				if timer != nil {
					timer.Stop()
				}
				timer = time.AfterFunc(debounce, l.reloadRates)
			}

		case err, ok := <-l.watcher.Errors:
			if !ok {
				return
			}
			slog.Warn("config watcher error", "err", err)
		}
	}
}

func (l *Loader) reloadRates() {
	cfg, err := l.LoadRates()
	if err != nil {
		slog.Warn("config: hot-reload rates.toml failed", "err", err)
		return
	}
	slog.Info("config: rates.toml reloaded",
		"exp.solo", cfg.Exp.Solo,
		"drop.normal", cfg.Drop.Normal)

	l.mu.RLock()
	callbacks := make([]func(RatesConfig), len(l.onChange))
	copy(callbacks, l.onChange)
	l.mu.RUnlock()

	for _, fn := range callbacks {
		fn(cfg)
	}
}
