// ProgressBar.tsx — Animated progress bar shown during patch download.
// Receives a 0-100 percentage and a human-readable status label.

import React from "react";

interface ProgressBarProps {
  /** Download progress as a percentage (0–100). */
  percent: number;
  /** Status text displayed above/beside the bar. */
  label: string;
  /** Whether to show the bar at all (hidden when idle / ready). */
  visible: boolean;
}

/** Format bytes to a human-readable string, e.g. "12.3 MB". */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const exp = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / Math.pow(1024, exp)).toFixed(1)} ${units[exp]}`;
}

const ProgressBar: React.FC<ProgressBarProps> = ({ percent, label, visible }) => {
  if (!visible) return null;

  const clamped = Math.min(100, Math.max(0, percent));

  return (
    <div className="progress-container" role="status" aria-label={label}>
      <div className="progress-label">
        <span className="progress-status">{label}</span>
        <span className="progress-pct">{clamped.toFixed(1)}%</span>
      </div>
      <div className="progress-track" aria-hidden="true">
        <div
          className="progress-fill"
          style={{ width: `${clamped}%` }}
        />
        {/* Animated shimmer overlay */}
        <div className="progress-shimmer" />
      </div>
    </div>
  );
};

export default ProgressBar;
