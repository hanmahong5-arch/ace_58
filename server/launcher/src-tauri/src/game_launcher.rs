// game_launcher.rs — Spawn the Aion game process with the correct arguments and environment.
//
// Protocol compliance (launcher-protocol.md §6 + §7):
//   - Primary binary: bin64/aion.bin (64-bit)
//   - Fallback binary: bin32/aion.bin (32-bit, if 64-bit not found)
//   - Environment variables: SHIGUANG_SESSION / SHIGUANG_LAUNCHER_VER /
//                            SHIGUANG_SERVER_ID / SHIGUANG_API_BASE
//   - Launch args: -ip / -port / -cc:5 / -lang:eng / plus all feature flags

use std::path::{Path, PathBuf};
use std::process::Command;
use thiserror::Error;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum LaunchError {
    #[error("Game binary not found at '{0}' or fallback path")]
    BinaryNotFound(String),

    #[error("Failed to spawn game process: {0}")]
    SpawnFailed(#[from] std::io::Error),
}

/// Resolve the game binary path: prefer bin64/aion.bin, fall back to bin32/aion.bin.
fn resolve_binary(client_root: &Path) -> Result<PathBuf, LaunchError> {
    let bin64 = client_root.join("bin64").join("aion.bin");
    if bin64.exists() {
        return Ok(bin64);
    }
    let bin32 = client_root.join("bin32").join("aion.bin");
    if bin32.exists() {
        return Ok(bin32);
    }
    Err(LaunchError::BinaryNotFound(
        client_root.join("bin64/aion.bin").display().to_string(),
    ))
}

/// Assemble the full list of command-line arguments as specified in §6.
fn build_args(server_ip: &str, server_port: u16) -> Vec<String> {
    vec![
        format!("-ip:{}", server_ip),
        format!("-port:{}", server_port),
        "-cc:5".to_string(),
        "-lang:eng".to_string(),
        "-noauthgg".to_string(),
        "-noweb".to_string(),
        "-nb".to_string(),
        "-nowebshop".to_string(),
        "-charnamemenu".to_string(),
        "-ingameshop".to_string(),
        "-megaphone".to_string(),
        "-st".to_string(),
        "-multithread".to_string(),
        "-disable-xigncode".to_string(),
        "-win10-mouse-fix".to_string(),
        "-unlimited-gfx".to_string(),
    ]
}

/// Spawn the game process and return its PID.
pub fn spawn_game(
    client_root: &Path,
    server_ip: &str,
    server_port: u16,
    server_id: &str,
    launcher_version: &str,
    api_base: &str,
) -> Result<u32, LaunchError> {
    let binary = resolve_binary(client_root)?;
    let args = build_args(server_ip, server_port);

    // Generate a fresh UUID for this game session (used by in-game Awesomium plugin).
    let session_id = Uuid::new_v4().to_string();

    log::info!(
        "Launching {} with session={} server={}:{}",
        binary.display(),
        session_id,
        server_ip,
        server_port
    );

    let child = Command::new(&binary)
        .args(&args)
        .current_dir(client_root)
        // Protocol §7 environment variables
        .env("SHIGUANG_SESSION", &session_id)
        .env("SHIGUANG_LAUNCHER_VER", launcher_version)
        .env("SHIGUANG_SERVER_ID", server_id)
        .env("SHIGUANG_API_BASE", api_base)
        .spawn()?;

    let pid = child.id();
    log::info!("Game process spawned with PID {}", pid);
    Ok(pid)
}
