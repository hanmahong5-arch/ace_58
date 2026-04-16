// LaunchButton.tsx — The primary CTA button for launching the game.
// Visual state reflects the current launcher workflow phase.

import React from "react";
import type { LauncherStatus } from "../types";

interface LaunchButtonProps {
  status: LauncherStatus;
  onClick: () => void;
}

/** Map launcher status to Chinese + English label text shown on the button. */
function getLabel(status: LauncherStatus): string {
  switch (status) {
    case "checking":
      return "检查更新 / Checking…";
    case "downloading":
      return "下载中 / Downloading…";
    case "launching":
      return "启动中 / Launching…";
    case "offline":
      return "离线启动 / Launch Offline";
    case "ready":
    case "idle":
    default:
      return "开始游戏 / Play";
  }
}

/** Button is interactive only in "ready", "idle", and "offline" states. */
function isDisabled(status: LauncherStatus): boolean {
  return status === "checking" || status === "downloading" || status === "launching";
}

const LaunchButton: React.FC<LaunchButtonProps> = ({ status, onClick }) => {
  const disabled = isDisabled(status);

  return (
    <button
      className={`launch-btn launch-btn--${status}`}
      disabled={disabled}
      onClick={onClick}
      aria-label={getLabel(status)}
      aria-busy={status === "launching" || status === "downloading"}
    >
      {(status === "downloading" || status === "launching") && (
        <span className="launch-btn-spinner" aria-hidden="true" />
      )}
      <span className="launch-btn-label">{getLabel(status)}</span>
    </button>
  );
};

export default LaunchButton;
