// types.ts — TypeScript interfaces aligned with Rust structs in commands.rs.
// Keep in sync whenever Rust-side types change.

/** A single file entry in the patch manifest (mirrors Rust PatchFile). */
export interface PatchFile {
  relativePath: string;
  sha256: string;
  sizeBytes: number;
  downloadUrl: string;
  /** "required" | "optional" | "cosmetic" | "legacy" */
  tier: string;
}

/** Full patch manifest returned by check_patch command (mirrors Rust PatchManifest). */
export interface PatchManifest {
  schemaVersion: number;
  version: string;
  clientEdition: string;
  publishedAt: string;
  mandatory: boolean;
  baselineSize: number;
  patchSize: number;
  files: PatchFile[];
  deletions: string[];
  releaseNotesMd: string;
}

/** A game server entry from get_server_list command (mirrors Rust ServerInfo). */
export interface ServerInfo {
  id: string;
  name: string;
  description: string;
  ip: string;
  port: number;
  /** "online" | "offline" | "maintenance" */
  status: string;
  onlineCount: number;
}

/** Launcher configuration from get_config command (mirrors Rust LauncherConfig). */
export interface LauncherConfig {
  apiBase: string;
  selectedServerId: string | null;
  launcherVersion: string;
  lastRunAt: string | null;
  clientPath: string;
}

/** Download progress event payload emitted on "patch://progress". */
export interface DownloadProgress {
  filePath: string;
  downloadedBytes: number;
  totalBytes: number;
  fileIndex: number;
  totalFiles: number;
}

/** Possible launcher UI states. */
export type LauncherStatus =
  | "idle"
  | "checking"
  | "downloading"
  | "ready"
  | "launching"
  | "offline";

/** News item from Portal API /api/portal/news. */
export interface NewsItem {
  id: string;
  title: string;
  summary: string;
  imageUrl?: string;
  publishedAt: string;
  url?: string;
}
