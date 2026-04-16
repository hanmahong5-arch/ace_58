// App.tsx — Root component for the Shiguang Launcher.
// Layout: left sidebar (brand + server selector + progress + launch),
//         main area (news), frameless window with custom title bar.

import React, { useCallback, useEffect, useRef, useState } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { listen } from "@tauri-apps/api/event";
import BrandHeader from "./components/BrandHeader";
import NewsList from "./components/NewsList";
import ServerSelector from "./components/ServerSelector";
import ProgressBar from "./components/ProgressBar";
import LaunchButton from "./components/LaunchButton";
import { checkPatch, downloadPatch, getLauncherVersion, getConfig, saveConfig } from "./api/tauri";
import type { DownloadProgress, LauncherConfig, LauncherStatus, PatchManifest, ServerInfo } from "./types";
import "./App.css";

const App: React.FC = () => {
  // Launcher state
  const [status, setStatus] = useState<LauncherStatus>("idle");
  const [version, setVersion] = useState("1.0.0");
  const [config, setConfig] = useState<LauncherConfig | null>(null);
  const [selectedServer, setSelectedServer] = useState<ServerInfo | null>(null);
  const [manifest, setManifest] = useState<PatchManifest | null>(null);

  // Download progress state
  const [progressPercent, setProgressPercent] = useState(0);
  const [progressLabel, setProgressLabel] = useState("");

  // Error/notification message
  const [notification, setNotification] = useState<string | null>(null);

  // Track the unlisten fn for the progress event subscription
  const unlistenRef = useRef<(() => void) | null>(null);

  // ── Initialization ──────────────────────────────────────────────────────────

  useEffect(() => {
    let cancelled = false;

    const init = async () => {
      try {
        const [ver, cfg] = await Promise.all([getLauncherVersion(), getConfig()]);
        if (cancelled) return;
        setVersion(ver);
        setConfig(cfg);

        // Subscribe to download progress events
        const unlisten = await listen<DownloadProgress>("patch://progress", (event) => {
          const { downloadedBytes, totalBytes, fileIndex, totalFiles, filePath } = event.payload;
          const filePercent = totalBytes > 0 ? (downloadedBytes / totalBytes) * 100 : 0;
          // Blend file-level and overall progress for a smoother experience
          const overall = totalFiles > 0
            ? ((fileIndex / totalFiles) * 100 + filePercent / totalFiles)
            : filePercent;
          setProgressPercent(overall);
          setProgressLabel(`${filePath.split("/").pop() ?? filePath} (${fileIndex + 1}/${totalFiles})`);
        });
        unlistenRef.current = unlisten;

        // Run the patch check immediately on startup
        await runPatchCheck(cfg);
      } catch (e) {
        if (!cancelled) {
          setStatus("offline");
          setNotification("无法连接拾光服务器，使用离线模式启动 / Offline mode");
        }
      }
    };

    init();
    return () => {
      cancelled = true;
      unlistenRef.current?.();
    };
  }, []);

  // ── Patch check ─────────────────────────────────────────────────────────────

  const runPatchCheck = async (cfg: LauncherConfig) => {
    setStatus("checking");
    setNotification(null);
    try {
      const m = await checkPatch();
      setManifest(m);

      if (m.files.length > 0) {
        // Files need downloading — start automatically for mandatory patches
        if (m.mandatory) {
          await runDownload(m);
        } else {
          setStatus("ready");
          setNotification(`可选更新 v${m.version} 可用 / Optional update available`);
        }
      } else {
        setStatus("ready");
      }
    } catch (err) {
      const msg = String(err);
      if (msg.startsWith("OFFLINE:")) {
        setStatus("offline");
        setNotification("无法连接拾光服务器，使用离线模式启动 / Offline mode — network unavailable");
      } else {
        setStatus("offline");
        setNotification(`服务器维护中，请稍后 / Server maintenance: ${msg}`);
      }
    }
  };

  // ── Download ─────────────────────────────────────────────────────────────────

  const runDownload = async (m: PatchManifest) => {
    setStatus("downloading");
    setProgressPercent(0);
    setProgressLabel("准备下载 / Preparing…");
    try {
      await downloadPatch(m);
      setProgressPercent(100);
      setProgressLabel("更新完成 / Update complete");
      setStatus("ready");
      setNotification(`已更新至 v${m.version} / Updated to v${m.version}`);
    } catch (e) {
      setStatus("ready");
      setNotification(`下载失败，将尝试直接启动 / Download failed: ${String(e)}`);
    }
  };

  // ── Server selection ─────────────────────────────────────────────────────────

  const handleServerChange = useCallback(
    (server: ServerInfo) => {
      setSelectedServer(server);
      if (config) {
        const updated = { ...config, selectedServerId: server.id };
        setConfig(updated);
        saveConfig(updated).catch(() => {});
      }
    },
    [config]
  );

  // ── Game launch ──────────────────────────────────────────────────────────────

  const handleLaunch = useCallback(async () => {
    if (!selectedServer && status !== "offline") {
      setNotification("请先选择服务器 / Please select a server");
      return;
    }

    // If there's a pending non-mandatory patch and the user hits Play, download first.
    if (manifest && manifest.files.length > 0 && status === "ready") {
      await runDownload(manifest);
    }

    setStatus("launching");
    setNotification(null);
    try {
      const { launchGame } = await import("./api/tauri");
      const serverId = selectedServer?.id ?? "default";
      const pid = await launchGame(serverId);
      setNotification(`游戏已启动 (PID ${pid}) / Game launched`);

      // Minimize launcher after successful launch
      const win = getCurrentWindow();
      await win.minimize();
    } catch (e) {
      setStatus("ready");
      setNotification(`游戏启动失败 / Launch failed: ${String(e)}`);
    }
  }, [selectedServer, status, manifest]);

  // ── Window controls ──────────────────────────────────────────────────────────

  const handleMinimize = () => getCurrentWindow().minimize();
  const handleClose = () => getCurrentWindow().close();

  // ── Render ───────────────────────────────────────────────────────────────────

  const showProgress = status === "downloading" || (status === "ready" && progressPercent > 0 && progressPercent < 100);

  return (
    <div className="app-shell">
      {/* Frameless window title bar with drag region and controls */}
      <div className="title-bar">
        <div className="title-bar-controls">
          <button className="title-bar-btn" onClick={handleMinimize} aria-label="最小化 / Minimize" title="Minimize">
            &#8211;
          </button>
          <button className="title-bar-btn title-bar-btn--close" onClick={handleClose} aria-label="关闭 / Close" title="Close">
            &#10005;
          </button>
        </div>
      </div>

      {/* Left sidebar */}
      <aside className="sidebar">
        <BrandHeader version={version} />

        <div className="sidebar-bottom">
          {notification && (
            <p className="sidebar-notification" style={{
              fontSize: "var(--font-size-xs)",
              color: "var(--color-text-secondary)",
              lineHeight: "var(--line-height-base)",
            }}>
              {notification}
            </p>
          )}

          <ProgressBar
            visible={showProgress}
            percent={progressPercent}
            label={progressLabel}
          />

          <ServerSelector
            selectedId={config?.selectedServerId ?? null}
            onChange={handleServerChange}
            disabled={status === "downloading" || status === "launching"}
          />

          <LaunchButton status={status} onClick={handleLaunch} />
        </div>
      </aside>

      {/* Main content — news */}
      <main className="main-content">
        <NewsList apiBase={config?.apiBase ?? "http://127.0.0.1:8082/api/portal"} />
      </main>
    </div>
  );
};

export default App;
