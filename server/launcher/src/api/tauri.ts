// api/tauri.ts — Typed wrappers around @tauri-apps/api invoke() calls.
// Centralizes all IPC calls so the rest of the frontend never imports invoke() directly.

import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import type {
  DownloadProgress,
  LauncherConfig,
  PatchManifest,
  ServerInfo,
} from "../types";

// ── Patch management ──────────────────────────────────────────────────────────

/**
 * Fetch the patch manifest from the backend and identify files needing update.
 * On network failure, the Rust side returns an error string prefixed with "OFFLINE:".
 */
export async function checkPatch(): Promise<PatchManifest> {
  return invoke<PatchManifest>("check_patch");
}

/**
 * Download all pending patch files described in the given manifest.
 * Progress events are emitted on the "patch://progress" channel.
 */
export async function downloadPatch(manifest: PatchManifest): Promise<void> {
  return invoke<void>("download_patch", { manifest });
}

/** Subscribe to download progress events. Returns an unsubscribe function. */
export async function onDownloadProgress(
  callback: (progress: DownloadProgress) => void
): Promise<UnlistenFn> {
  return listen<DownloadProgress>("patch://progress", (event) => {
    callback(event.payload);
  });
}

// ── Server list ───────────────────────────────────────────────────────────────

/** Fetch the list of available game servers from the Portal backend. */
export async function getServerList(): Promise<ServerInfo[]> {
  return invoke<ServerInfo[]>("get_server_list");
}

// ── Game launch ───────────────────────────────────────────────────────────────

/**
 * Spawn the game process for the given server.
 * Returns the OS process ID of the spawned game binary.
 */
export async function launchGame(serverId: string): Promise<number> {
  return invoke<number>("launch_game", { serverId });
}

// ── Launcher metadata ─────────────────────────────────────────────────────────

/** Return the current launcher version string from launcher.toml. */
export async function getLauncherVersion(): Promise<string> {
  return invoke<string>("get_launcher_version");
}

// ── Configuration ─────────────────────────────────────────────────────────────

/** Read the launcher configuration from %APPDATA%/Shiguang/launcher.toml. */
export async function getConfig(): Promise<LauncherConfig> {
  return invoke<LauncherConfig>("get_config");
}

/** Persist updated configuration values to launcher.toml. */
export async function saveConfig(config: LauncherConfig): Promise<void> {
  return invoke<void>("save_config", { cfg: config });
}

// ── Portal REST (direct HTTP via fetch, not Tauri invoke) ────────────────────

/** Fetch news items from the Portal REST API. */
export async function fetchNews(
  apiBase: string
): Promise<import("../types").NewsItem[]> {
  try {
    const resp = await fetch(`${apiBase}/news`, {
      signal: AbortSignal.timeout(8000),
    });
    if (!resp.ok) return [];
    return resp.json();
  } catch {
    return [];
  }
}
