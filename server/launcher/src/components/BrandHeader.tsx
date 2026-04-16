// BrandHeader.tsx — Displays the Myriad brand identity: logo + game title + version.
// Uses brand color tokens from palette.css via CSS custom properties.

import React from "react";

interface BrandHeaderProps {
  /** Current launcher version string to display below the logo. */
  version: string;
}

/** Inline SVG mark extracted from brand/logo/myriad-mark.svg (simplified for React). */
const MyriadMark: React.FC = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 200 200"
    width="64"
    height="64"
    aria-label="Myriad mark logo"
  >
    <defs>
      <radialGradient id="bh-bg" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stopColor="#1A3048" />
        <stop offset="100%" stopColor="#0D1B2A" />
      </radialGradient>
      <linearGradient id="bh-ring" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stopColor="#3A8FBF" />
        <stop offset="50%" stopColor="#D4AF37" />
        <stop offset="100%" stopColor="#FF9E40" />
      </linearGradient>
    </defs>
    <circle cx="100" cy="100" r="100" fill="url(#bh-bg)" />
    <circle cx="100" cy="100" r="88" fill="none" stroke="url(#bh-ring)" strokeWidth="2" opacity="0.7" />
    {/* Four arc quadrants */}
    <path d="M 100 100 m -62 0 a 62 62 0 0 1 62 -62" fill="none" stroke="#D4AF37" strokeWidth="7" strokeLinecap="round" strokeDasharray="5 3" opacity="0.85" />
    <path d="M 100 38 a 62 62 0 0 1 62 62" fill="none" stroke="#5BAFDF" strokeWidth="7" strokeLinecap="round" opacity="0.85" />
    <path d="M 162 100 a 62 62 0 0 1 -62 62" fill="none" stroke="#FF9E40" strokeWidth="7" strokeLinecap="square" strokeDasharray="12 4" opacity="0.85" />
    <path d="M 100 162 a 62 62 0 0 1 -62 -62" fill="none" stroke="#9FAFC0" strokeWidth="7" strokeLinecap="round" strokeDasharray="1 5" opacity="0.85" />
    {/* Inner glow + seal */}
    <circle cx="100" cy="100" r="30" fill="#0D1B2A" opacity="0.9" />
    <text x="100" y="108" fontFamily="Source Han Serif SC, serif" fontSize="22" fontWeight="700" fill="#FF9E40" textAnchor="middle" dominantBaseline="middle" opacity="0.95">拾</text>
  </svg>
);

const BrandHeader: React.FC<BrandHeaderProps> = ({ version }) => {
  return (
    <header className="brand-header">
      <div className="brand-logo">
        <MyriadMark />
      </div>
      <div className="brand-text">
        <h1 className="brand-title-zh">万象 · 拾光纪元</h1>
        <p className="brand-title-en">MYRIAD: The Shiguang Era</p>
        <span className="brand-version">v{version}</span>
      </div>
    </header>
  );
};

export default BrandHeader;
