// ServerSelector.tsx — Dropdown for selecting the game server to connect to.
// Calls get_server_list Tauri command and reflects selection back to the parent.

import React, { useEffect, useState } from "react";
import type { ServerInfo } from "../types";
import { getServerList } from "../api/tauri";

interface ServerSelectorProps {
  /** Currently selected server ID (from config). */
  selectedId: string | null;
  /** Called when the user picks a different server. */
  onChange: (server: ServerInfo) => void;
  /** Disable interaction while patching or launching. */
  disabled?: boolean;
}

/** Status indicator dot: green = online, yellow = maintenance, red = offline. */
const StatusDot: React.FC<{ status: string }> = ({ status }) => {
  const color =
    status === "online"
      ? "var(--color-success)"
      : status === "maintenance"
      ? "var(--color-warning)"
      : "var(--color-error)";
  return (
    <span
      className="status-dot"
      style={{ background: color }}
      aria-label={status}
    />
  );
};

const ServerSelector: React.FC<ServerSelectorProps> = ({
  selectedId,
  onChange,
  disabled = false,
}) => {
  const [servers, setServers] = useState<ServerInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    getServerList()
      .then((list) => {
        if (cancelled) return;
        setServers(list);
        setLoading(false);
        // Auto-select the first server if none is configured.
        if (list.length > 0 && !selectedId) {
          onChange(list[0]);
        }
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        setError(String(e));
        setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return <div className="server-selector loading">加载服务器列表… / Loading servers…</div>;
  }

  if (error || servers.length === 0) {
    return (
      <div className="server-selector error">
        <span>⚠ 无法获取服务器列表 / Could not load server list</span>
      </div>
    );
  }

  const selected = servers.find((s) => s.id === selectedId) ?? servers[0];

  return (
    <div className="server-selector">
      <label htmlFor="server-select" className="server-label">
        选择服务器 / Select Server
      </label>
      <div className="server-select-wrapper">
        <StatusDot status={selected.status} />
        <select
          id="server-select"
          className="server-select"
          value={selected.id}
          disabled={disabled}
          onChange={(e) => {
            const srv = servers.find((s) => s.id === e.target.value);
            if (srv) onChange(srv);
          }}
        >
          {servers.map((srv) => (
            <option key={srv.id} value={srv.id}>
              {srv.name}
            </option>
          ))}
        </select>
      </div>
      <p className="server-info">
        {selected.description} &middot; 在线 {selected.onlineCount} 人
      </p>
    </div>
  );
};

export default ServerSelector;
