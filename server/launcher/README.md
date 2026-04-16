# 拾光启动器 / Shiguang Launcher

**Phase P-4** — 《万象 · 拾光纪元》/ MYRIAD: The Shiguang Era 官方游戏启动器

The official game launcher for *MYRIAD: The Shiguang Era*, built with Tauri 2 (Rust + React). It handles patch management, server selection, and game process launching — with no login UI (authentication happens inside the game client).

---

## 目录结构 / Directory Structure

```
launcher/
├── src/                        React 18 + TypeScript frontend
│   ├── api/tauri.ts            Typed wrappers for all Tauri invoke() calls
│   ├── components/
│   │   ├── BrandHeader.tsx     Brand logo + title + version display
│   │   ├── NewsList.tsx        News panel (fetches from Portal /api/portal/news)
│   │   ├── ServerSelector.tsx  Server dropdown (fetches from /api/portal/launcher/server-list)
│   │   ├── ProgressBar.tsx     Download progress bar with shimmer animation
│   │   └── LaunchButton.tsx    Primary CTA button with status-aware labeling
│   ├── App.tsx                 Root layout: sidebar + news main area
│   ├── App.css                 All UI styles, uses brand CSS custom properties
│   ├── brand-tokens.css        Copy of D:/拾光ai/brand/palette.css tokens
│   └── types.ts                TypeScript interfaces aligned with Rust structs
├── src-tauri/
│   ├── Cargo.toml              Rust dependencies (Tauri 2, reqwest, sha2, uuid…)
│   ├── tauri.conf.json         Window 1200×720, no decorations, MSI+NSIS bundle
│   ├── build.rs                Tauri build script
│   ├── icons/                  Placeholder icons (replace with real brand icons)
│   └── src/
│       ├── main.rs             Tauri app entry; initializes shared reqwest client
│       ├── commands.rs         All #[tauri::command] handlers
│       ├── config.rs           launcher.toml I/O (%APPDATA%/Shiguang/launcher.toml)
│       ├── game_launcher.rs    Spawns bin64/aion.bin with protocol §6 args + §7 env vars
│       ├── patcher/
│       │   ├── manifest.rs     Fetches and parses the patch manifest
│       │   ├── downloader.rs   Concurrent (≤4) downloads, resume, sha256 verify, atomic rename
│       │   └── verifier.rs     SHA-256 file and byte-slice checksum helpers
│       └── injector/
│           └── version_dll.rs  Ensures bin32/version.dll is present and correct
├── index.html
├── vite.config.ts
├── tsconfig.json
├── package.json
├── .gitignore
└── README.md
```

---

## 开发运行 / Development

### 前置条件 / Prerequisites

- **Node.js** ≥ 18  
- **Rust** stable (via `rustup`)  
- **Windows SDK** (for Tauri's NSIS/MSI bundler)  
- 品牌字体（可选）/ Brand fonts (optional, loaded at runtime):  
  `Source Han Serif SC`, `Source Han Sans SC`, `Cinzel`, `Inter`  
  → Install from Google Fonts or Adobe Fonts as needed.

### 首次安装 / First install

```bash
cd D:/拾光ai/launcher
npm install
```

> 需要联网拉取 Node 和 Rust crate 依赖。  
> Requires internet access to download Node modules and Rust crates on first run.

### 启动开发服务器 / Start dev server

```bash
npm run tauri dev
```

This starts Vite on port 5173 and opens the Tauri window in dev mode with hot-reload.

### 构建安装包 / Build installer

```bash
npm run tauri build
```

Produces MSI and NSIS installers in `src-tauri/target/release/bundle/`.

---

## 依赖的后端接口 / Required Backend API Endpoints

The launcher communicates with the Portal backend (`platform/backend`, default: `http://127.0.0.1:8082/api/portal`):

| 接口 | 方法 | 用途 |
|------|------|------|
| `/launcher/patch/manifest?client=beyond48` | GET | 获取补丁清单 / Fetch patch manifest |
| `/launcher/patch/file/{sha256}` | GET | 下载补丁文件 (支持 Range) / Download patch file (resume-capable) |
| `/launcher/server-list` | GET | 获取服务器列表 / Fetch server list |
| `/launcher/self-manifest` | GET | 启动器自更新检查 (stub, 未实现) / Launcher self-update (stub) |
| `/news` | GET | 获取新闻列表 / Fetch news items |

API base URL is read from `%APPDATA%/Shiguang/launcher.toml` — never hard-coded.

---

## 已知限制 / Known Limitations

- **启动器自更新**: `self-manifest` 端点已保留 stub，本阶段未实现自动更新逻辑。  
  Launcher self-update is stubbed; not implemented in Phase P-4.

- **托盘图标**: 系统托盘最小化功能需要 `tauri-plugin-tray`，尚未集成。  
  System tray minimize requires `tauri-plugin-tray`, not yet integrated.

- **Brand icons**: `src-tauri/icons/` 中的图标为纯色占位图，正式发布前需替换为真实品牌图标。  
  Icons are placeholder flat-color images; replace with real brand art before shipping.

- **字体**: 品牌字体 `Source Han Serif SC` / `Cinzel` 未打包进安装包，依赖系统已安装。  
  Brand fonts are not bundled; users need them installed or the UI falls back to system serif/sans.

- **BitTorrent / P2P 下载**: 未实现，首版使用 HTTP 直连。  
  P2P download not implemented; HTTP direct only in v1.

---

## 协议文档 / Protocol Reference

See `D:/拾光ai/doc/portal/launcher-protocol.md` for the complete specification of:
- Patch manifest schema (§3)
- File download protocol with resume (§4)
- version.dll injection (§5)
- Launch arguments (§6)
- Environment variables (§7)
- Failure modes (§8)
