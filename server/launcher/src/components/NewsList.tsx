// NewsList.tsx — Fetches and renders the latest news from the Portal backend.
// Gracefully falls back to an empty state when the network is unavailable.

import React, { useEffect, useState } from "react";
import type { NewsItem } from "../types";

interface NewsListProps {
  /** Portal API base URL, e.g. "http://127.0.0.1:8082/api/portal". */
  apiBase: string;
}

/** Format an ISO date string to a localized display string. */
function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString("zh-CN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
  } catch {
    return iso.slice(0, 10);
  }
}

const NewsList: React.FC<NewsListProps> = ({ apiBase }) => {
  const [items, setItems] = useState<NewsItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [active, setActive] = useState<number>(0);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetch(`${apiBase}/news`, { signal: AbortSignal.timeout(8000) })
      .then((r) => (r.ok ? r.json() : []))
      .then((data: NewsItem[]) => {
        if (!cancelled) {
          setItems(Array.isArray(data) ? data.slice(0, 5) : []);
          setLoading(false);
        }
      })
      .catch(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [apiBase]);

  if (loading) {
    return (
      <div className="news-panel news-loading">
        <span className="spinner" aria-label="Loading news" />
        <p>加载新闻中 / Loading news…</p>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div className="news-panel news-empty">
        <p>暂无新闻 / No news available</p>
      </div>
    );
  }

  const current = items[active];

  return (
    <div className="news-panel">
      {/* Main news image / headline display */}
      <div className="news-main">
        {current.imageUrl && (
          <img
            className="news-image"
            src={current.imageUrl}
            alt={current.title}
          />
        )}
        <div className="news-content">
          <p className="news-date">{formatDate(current.publishedAt)}</p>
          <h3 className="news-title">{current.title}</h3>
          <p className="news-summary">{current.summary}</p>
        </div>
      </div>

      {/* Thumbnail row for quick navigation */}
      <ul className="news-thumbs" role="tablist" aria-label="News items">
        {items.map((item, i) => (
          <li
            key={item.id}
            role="tab"
            aria-selected={i === active}
            className={`news-thumb ${i === active ? "active" : ""}`}
            onClick={() => setActive(i)}
          >
            <span className="news-thumb-title">{item.title}</span>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default NewsList;
