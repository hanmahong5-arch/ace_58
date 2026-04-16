// main.rs — Tauri application entry point
// Initializes the shared HTTP client state and registers all Tauri commands.

// Prevent a console window from appearing on Windows in release builds.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod config;
mod game_launcher;
mod injector;
mod patcher;

use reqwest::Client;

/// Shared application state injected into every Tauri command via tauri::State.
/// Centralizes the reqwest client so TCP connections are reused across requests.
pub struct AppState {
    pub http: Client,
}

fn main() {
    env_logger::init();

    // Build a single reqwest client with connection pooling.
    let http_client = Client::builder()
        .user_agent("ShiguangLauncher/1.0.0")
        .build()
        .expect("Failed to create HTTP client");

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(AppState { http: http_client })
        .invoke_handler(tauri::generate_handler![
            commands::check_patch,
            commands::download_patch,
            commands::launch_game,
            commands::get_launcher_version,
            commands::get_server_list,
            commands::get_config,
            commands::save_config,
        ])
        .run(tauri::generate_context!())
        .expect("Error while running Shiguang Launcher");
}
