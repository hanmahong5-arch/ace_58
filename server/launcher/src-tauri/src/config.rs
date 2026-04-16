// config.rs — Launcher configuration persisted to %APPDATA%/Shiguang/launcher.toml
// Provides read/write helpers for settings that survive restarts.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use thiserror::Error;

/// All fields stored in launcher.toml.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LauncherConfig {
    /// Portal API base URL, e.g. "http://127.0.0.1:8082/api/portal".
    /// Never hard-coded; read from this file on startup.
    pub api_base: String,

    /// ID of the server the user selected last session.
    pub selected_server_id: Option<String>,

    /// Self-reported launcher version string.
    pub launcher_version: String,

    /// RFC-3339 timestamp of the last successful game launch.
    pub last_run_at: Option<String>,

    /// Absolute path to the game client root directory.
    pub client_path: String,
}

impl Default for LauncherConfig {
    fn default() -> Self {
        Self {
            api_base: "http://127.0.0.1:8082/api/portal".to_string(),
            selected_server_id: None,
            launcher_version: "1.0.0".to_string(),
            last_run_at: None,
            client_path: "D:/拾光ai/server/beyond-4.8/client".to_string(),
        }
    }
}

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("TOML deserialize error: {0}")]
    TomlDe(#[from] toml::de::Error),

    #[error("TOML serialize error: {0}")]
    TomlSer(#[from] toml::ser::Error),
}

/// Returns the canonical path to %APPDATA%/Shiguang/launcher.toml.
fn config_path() -> PathBuf {
    let base = dirs_config();
    base.join("Shiguang").join("launcher.toml")
}

/// Cross-platform config directory helper (Windows: %APPDATA%).
fn dirs_config() -> PathBuf {
    std::env::var("APPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
}

/// Load config from disk, returning defaults if the file does not yet exist.
pub fn load() -> Result<LauncherConfig, ConfigError> {
    let path = config_path();
    if !path.exists() {
        return Ok(LauncherConfig::default());
    }
    let raw = std::fs::read_to_string(&path)?;
    let cfg: LauncherConfig = toml::from_str(&raw)?;
    Ok(cfg)
}

/// Persist config to disk, creating parent directories as needed.
pub fn save(cfg: &LauncherConfig) -> Result<(), ConfigError> {
    let path = config_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let serialized = toml::to_string_pretty(cfg)?;
    std::fs::write(&path, serialized)?;
    Ok(())
}
