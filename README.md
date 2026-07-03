<h1 align="center">Ruffnova</h1>

<p align="center">
  <strong>A native macOS &amp; iOS Flash Player powered by the Ruffle engine.</strong>
</p>

<p align="center">
  <a href="https://www.swift.org"><img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift" alt="Swift 5.9+"></a>
  <a href="https://www.rust-lang.org"><img src="https://img.shields.io/badge/Rust-edition%202024-000000?logo=rust" alt="Rust"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Non--Commercial-blue" alt="License"></a>
  <a><img src="https://img.shields.io/badge/Platform-macOS%2013%2B%20%7C%20iOS%2017%2B-lightgrey" alt="Platform"></a>
</p>

---

## About

Ruffnova is an unofficial native Apple-platform frontend for [Ruffle](https://ruffle.rs), the open-source Flash Player emulator. It wraps the Rust Flash emulation engine behind a C FFI layer, exposing it through a SwiftUI interface with Metal-accelerated rendering.

No browser, no Electron — just a first-class native app for playing `.swf` files.

## Features

- **SwiftUI Interface** — Native menu bar, Settings scene, Dark Mode, Retina displays
- **Metal Rendering** — Hardware-accelerated via wgpu with CAMetalLayer / MTKView
- **Player Controls** — Play/Pause, step forward, volume, mute, fullscreen, quality selector
- **Library** — Recent files, bookmark Favorites, search
- **File Handling** — Open via menu, drag-and-drop, registered `.swf` file handler
- **Localization** — English and Simplified Chinese
- **iOS** — Adapted UI with touch input (iOS 17+)

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| macOS | 13+ (Ventura) | |
| Xcode | 15+ | macOS SDK included |
| Swift | 5.9+ | Included with Xcode |
| Rust | stable | [rustup](https://rustup.rs) |
| Rust targets | `aarch64-apple-darwin` | iOS: `aarch64-apple-ios`, `aarch64-apple-ios-sim` |

## Quick Start

```bash
git clone https://github.com/anomalyco/ruffnova.git
cd ruffnova

# Build the Rust FFI engine
./build_engine.sh --target macos

# Build and run
swift build -c release
./build_app.sh --release
open .build/Ruffnova.app
```

Or open in Xcode:

```bash
open Package.swift
# Select Ruffnova scheme, press ⌘R
```

### iOS

```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
./build_engine.sh --target ios
./build_engine.sh --target ios-sim
open Package.swift
```

## Architecture

```
┌──────────────────────────────────────────────┐
│  SwiftUI App                                 │
│  ├── Features/Player   (Metal rendering)     │
│  ├── Features/Library  (sidebar, grid)       │
│  ├── Features/Settings (preferences)         │
│  ├── App/Commands      (menu bar)            │
│  └── App/Environment   (AppState)            │
├──────────────────────────────────────────────┤
│  RuffleBridge           (Swift → C FFI)      │
├──────────────────────────────────────────────┤
│  libruffle_ffi.a        (C static library)   │
│  ├── ruffle_core        (AVM1/AVM2 runtimes) │
│  ├── ruffle_render_wgpu (Metal via wgpu)     │
│  └── ruffle_swf         (SWF parser)         │
└──────────────────────────────────────────────┘
```

## Project Layout

```
Ruffnova/
├── App/                # Entry points, app delegate, commands, root state
├── Features/
│   ├── Player/         # Metal render view, controls, debug overlay
│   ├── Library/        # Sidebar, file grid, favorites
│   ├── Import/         # File import + ZIP handler
│   ├── Search/         # Search bar + results
│   ├── Settings/       # Preferences UI + persistence
│   └── Diagnostics/    # SWF compatibility reports
├── Core/Security/      # Permission policy
├── Platform/
│   ├── macOS/          # File picker, input, localization
│   └── iOS/            # File picker, input, adapted views
├── Shared/             # Shared models, persistence, styles, extensions
├── Ruffle/Bridge/      # Swift wrapper around CRuffleFFI
├── CRuffleFFI/         # C headers + prebuilt static libs
├── Resources/          # lproj bundles + localization JSON
├── Assets.xcassets/    # App icon + assets
├── engine/             # Ruffle Rust workspace (30+ crates)
├── Tests/              # Swift unit tests
├── build_engine.sh     # Rust FFI build script
├── build_app.sh        # .app bundle assembler
└── Package.swift       # SPM package manifest
```

## Acknowledgments

Ruffnova is built on [Ruffle](https://ruffle.rs), created by Michael R. Welsh and the Ruffle community. This project would not exist without their years of reverse-engineering the Flash runtime.

Ruffnova is not affiliated with, endorsed by, or maintained by the Ruffle project.

## License

The original Ruffnova application code is available for non-commercial use only. Commercial use requires prior written permission from the Ruffnova copyright holders.

Ruffle and other third-party components retain their original copyright notices and license terms. Ruffle components are licensed under [MIT](LICENSE-MIT) or [Apache 2.0](LICENSE-APACHE), at your option.
