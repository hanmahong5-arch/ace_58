// commands.rs — Tauri command handlers exposed to the React frontend.
// Each function annotated with #[tauri::command] is callable via invoke() in the browser context.

use crate::config::{self, LauncherConfig};
use crate::game_launcher;
use crate::injector::version_dll;
use crate::patcher::{downloader, manifest};
use crate::AppState;
use serde::{Deserialize, Serialize};
use tauri::State;

// ── Types shared between Rust and TypeScript ─────────────────────────────────

/// Represents a single file entry in the patch manifest.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatchFile {
    pub relative_path: String,
    pub sha256: String,
    pub size_bytes: u64,
    pub download_url: String,
    pub tier: String,
}

/// Top-level patch manifest returned by the Portal backend.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatchManifest {
    pub schema_version: u32,
    pub version: String,
    pub client_edition: String,
    pub published_at: String,
    pub mandatory: bool,
    pub baseline_size: u64,
    pub patch_size: u64,
    pub files: Vec<PatchFile>,
    pub deletions: Vec<String>,
    pub release_notes_md: String,
}

/// One server entry from /api/portal/launcher/server-list.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerInfo {
    pub id: String,
    pub name: String,
    pub description: String,
    pub ip: String,
    pub port: u16,
    pub status: String,   // "online" | "offline" | "maintenance"
    pub online_count: u32,
}

/// Download progress event emitted to the frontend.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadProgress {
    pub file_path: String,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub file_index: usize,
    pub total_files: usize,
}

// ── Tauri Commands ────────────────────────────────────────────────────────────

/// Fetch and parse the patch manifest from the Portal backend.
/// Returns the manifest if any files need updating, or an empty file list if up-to-date.
#[tauri::command]
pub async fn check_patch(state: State<'_, AppState>) -> Result<PatchManifest, String> {
    let cfg = config::load().map_err(|e| e.to_string())?;
    let url = format!("{}/launcher/patch/manifest?client=beyond48", cfg.api_base);

    match manifest::fetch_manifest(&state.http, &url).await {
        Ok(m) => Ok(m),
        Err(e) => {
            // Failure mode: network unavailable — return a minimal stub so the UI
            // can offer offline launch without crashing.
            log::warn!("Manifest fetch failed ({}), entering offline mode.", e);
            Err(format!("OFFLINE:{}", e))
        }
    }
}

/// Download all files listed in the given manifest that differ from local copies.
/// Emits progress events to the Tauri event bus during download.
/// Returns Ok(()) when all files are verified; returns Err with a descriptive message on failure.
#[tauri::command]
pub async fn download_patch(
    manifest: PatchManifest,
    app: tauri::AppHandle,
) -> Result<(), String> {
    let cfg = config::load().map_err(|e| e.to_string())?;
    let client_root = std::path::PathBuf::from(&cfg.client_path);
    let pending_dir = client_root.join(".pending");

    downloader::download_all(&manifest, &cfg.api_base, &client_root, &pending_dir, &app)
        .await
        .map_err(|e| e.to_string())
}

/// Ensure version.dll is in place, spawn the game binary, and inject environment variables.
/// Returns the OS process ID of the spawned game process on success.
#[tauri::command]
pub async fn launch_game(server_id: String, state: State<'_, AppState>) -> Result<u32, String> {
    let mut cfg = config::load().map_err(|e| e.to_string())?;

    // Persist the selected server so we remember it next time.
    cfg.selected_server_id = Some(server_id.clone());
    config::save(&cfg).map_err(|e| e.to_string())?;

    let client_root = std::path::PathBuf::from(&cfg.client_path);

    // Ensure version.dll is present before spawning.
    version_dll::ensure_version_dll(&client_root, &state.http, &cfg.api_base)
        .await
        .map_err(|e| format!("version.dll check failed: {}", e))?;

    // Resolve server IP/port from the known server list or use a reasonable default.
    let (server_ip, server_port) = resolve_server_address(&server_id, &state, &cfg).await;

    game_launcher::spawn_game(
        &client_root,
        &server_ip,
        server_port,
        &server_id,
        &cfg.launcher_version,
        &cfg.api_base,
    )
    .map_err(|e| e.to_string())
}

/// Return the current launcher version string from launcher.toml (or default).
#[tauri::command]
pub fn get_launcher_version() -> String {
    config::load()
        .map(|c| c.launcher_version)
        .unwrap_or_else(|_| "1.0.0".to_string())
}

/// Fetch the available server list from /api/portal/launcher/server-list.
#[tauri::command]
pub async fn get_server_list(state: State<'_, AppState>) -> Result<Vec<ServerInfo>, String> {
    let cfg = config::load().map_err(|e| e.to_string())?;
    let url = format!("{}/launcher/server-list", cfg.api_base);

    let resp = state
        .http
        .get(&url)
        .send()
        .await
        .map_err(|e| format!("Network error: {}", e))?;

    if !resp.status().is_success() {
        return Err(format!("Server list returned HTTP {}", resp.status()));
    }

    resp.json::<Vec<ServerInfo>>()
        .await
        .map_err(|e| format!("Failed to parse server list: {}", e))
}

/// Read the current launcher configuration (safe to expose — no secrets stored here).
#[tauri::command]
pub fn get_config() -> Result<LauncherConfig, String> {
    config::load().map_err(|e| e.to_string())
}

/// Persist updated configuration values sent from the frontend.
#[tauri::command]
pub fn save_config(cfg: LauncherConfig) -> Result<(), String> {
    config::save(&cfg).map_err(|e| e.to_string())
}

// ── Internal helpers ──────────────────────────────────────────────────────────

/// Attempt to resolve the IP and port for the given server_id by querying the server list.
/// Falls back to localhost dev defaults if the network is unreachable.
async fn resolve_server_address(
    server_id: &str,
    state: &State<'_, AppState>,
    cfg: &LauncherConfig,
) -> (String, u16) {
    let url = format!("{}/launcher/server-list", cfg.api_base);
    if let Ok(resp) = state.http.get(&url).send().await {
        if let Ok(servers) = resp.json::<Vec<ServerInfo>>().await {
            if let Some(srv) = servers.iter().find(|s| s.id == server_id) {
                return (srv.ip.clone(), srv.port);
            }
        }
    }
    // Offline fallback: connect to local dev server
    log::warn!("Could not resolve server '{}', falling back to 127.0.0.1:2107", server_id);
    ("127.0.0.1".to_string(), 2107)
}
