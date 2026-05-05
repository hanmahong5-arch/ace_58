-- AionCore 5.8 — postgres bootstrap
--
-- 在 postgres:17-alpine 容器首次启动时自动执行（/docker-entrypoint-initdb.d/）。
-- 创建 4 个业务数据库；schema 由 world 进程的 goose embed migrations 落库。
--
-- 执行环境：postgres 用户（POSTGRES_USER）已经具备 SUPERUSER。
-- aion_world_live 已经被 POSTGRES_DB 创建过一次，所以这里 IF NOT EXISTS 兜底。

SELECT 'CREATE DATABASE aion_account_db'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'aion_account_db')\gexec

SELECT 'CREATE DATABASE aion_account_cache_db'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'aion_account_cache_db')\gexec

SELECT 'CREATE DATABASE aion_gm'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'aion_gm')\gexec

SELECT 'CREATE DATABASE aion_world_live'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'aion_world_live')\gexec
