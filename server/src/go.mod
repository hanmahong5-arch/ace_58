module aion58

go 1.25.0

require (
	// File-system event watcher — drives Lua script hot-reload and TOML hot-reload
	github.com/fsnotify/fsnotify v1.8.0
	// PostgreSQL driver — async, connection pool, raw pgx (no ORM)
	// Used exclusively to call PL/pgSQL stored procedures; never raw SQL.
	github.com/jackc/pgx/v5 v5.9.1

	// NATS client — inter-service event bus (Gateway ↔ World Engine)
	github.com/nats-io/nats.go v1.37.0

	// TOML v2 config parser — hot-reload friendly, type-safe
	github.com/pelletier/go-toml/v2 v2.2.3

	// Redis client — session token store (one-time tokens, 60s TTL)
	github.com/redis/go-redis/v9 v9.14.1

	// Lua 5.1 VM in pure Go — no CGo, hot-reloadable business logic
	github.com/yuin/gopher-lua v1.1.1

	// Standard crypto: Blowfish (key schedule reference), RSA, SHA families
	golang.org/x/crypto v0.36.0
)

require (
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/hibiken/asynq v0.26.0 // indirect
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	github.com/klauspost/compress v1.17.2 // indirect
	github.com/nats-io/nkeys v0.4.7 // indirect
	github.com/nats-io/nuid v1.0.1 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/riverqueue/river v0.34.0 // indirect
	github.com/riverqueue/river/riverdriver v0.34.0 // indirect
	github.com/riverqueue/river/riverdriver/riverpgxv5 v0.34.0 // indirect
	github.com/riverqueue/river/rivershared v0.34.0 // indirect
	github.com/riverqueue/river/rivertype v0.34.0 // indirect
	github.com/robfig/cron/v3 v3.0.1 // indirect
	github.com/spf13/cast v1.10.0 // indirect
	github.com/stretchr/testify v1.11.1 // indirect
	github.com/tidwall/gjson v1.18.0 // indirect
	github.com/tidwall/match v1.2.0 // indirect
	github.com/tidwall/pretty v1.2.1 // indirect
	github.com/tidwall/sjson v1.2.5 // indirect
	go.uber.org/goleak v1.3.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/sys v0.37.0 // indirect
	golang.org/x/text v0.35.0 // indirect
	golang.org/x/time v0.14.0 // indirect
	google.golang.org/protobuf v1.36.10 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
