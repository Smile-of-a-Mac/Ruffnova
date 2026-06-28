# Ruffle Native — macOS SwiftUI Frontend

A native macOS frontend for the [Ruffle](https://ruffle.rs) Flash Player emulator, built with SwiftUI and Metal.

## Architecture

```
┌─────────────────────────────────────┐
│  SwiftUI App (macOS 13+)            │
│  ├─ RuffleApp.swift      (入口)     │
│  ├─ ContentView.swift    (主视图)   │
│  ├─ RufflePlayerView.swift (Metal)  │
│  ├─ RuffleCommands.swift (菜单栏)   │
│  ├─ SettingsView.swift   (设置)     │
│  └─ AppState.swift       (状态)     │
├─────────────────────────────────────┤
│  RuffleBridge.swift      (FFI桥接)  │
├─────────────────────────────────────┤
│  libruffle_ffi.a (Rust 静态库)      │
│  ├─ ruffle_core          (Flash引擎)│
│  ├─ ruffle_render_wgpu   (渲染)     │
│  └─ ruffle_frontend_utils(前端工具) │
└─────────────────────────────────────┘
```

## Prerequisites

- macOS 13+ (Ventura)
- Xcode 15+
- Rust toolchain (via `rustup`)
- macOS SDK

## Build

### 1. Build the Rust FFI library

```bash
cd native/ruffle
chmod +x build.sh
./build.sh
```

This will:
- Compile `ruffle_ffi` as a static library
- Copy `ruffle_ffi.h` and `libruffle_ffi.a` to the Swift project

### 2. Build with Swift Package Manager

```bash
cd native/swift
swift build
```

### 3. Or open in Xcode

```bash
cd native/swift
open Package.swift
```

Then in Xcode:
1. Set the target to "Ruffnova"
2. Set the Bridging Header to `Ruffnova/RuffleBridgingHeader.h`
3. Add `libruffle_ffi.a` to "Link Binary With Libraries"
4. Build and run (⌘R)

## Features

### macOS Native UI
- **SwiftUI** declarative UI with native macOS look and feel
- **Native menu bar** with File, Control, View, and Help menus
- **Settings window** (macOS 13+ Settings scene)
- **Dark mode** support
- **Retina** display support

### Player Controls
- Play/Pause (⌘P)
- Step Forward (⌘Space)
- Volume slider with mute toggle
- Fullscreen toggle (⌃⌘F)
- Quality selector

### File Handling
- Open SWF files via File → Open (⌘O)
- Drag and drop SWF files onto the window
- Recent files list
- Bookmarks

### Rendering
- **Metal** backend via wgpu
- Hardware-accelerated rendering
- Automatic Retina scaling

## Project Structure

```
ruffle/                          ← Git 仓库根
├── native/                      ← Xcode 工程（macOS 原生前端）
│   ├── ruffle/
│   │   └── build.sh             # Rust FFI 构建脚本
│   └── swift/
│       ├── Package.swift        # SPM 包定义（Xcode 入口）
│       ├── engine/              ← Ruffle 引擎（Rust workspace）
│       │   ├── Cargo.toml       # Workspace 定义
│       │   ├── core/            # Flash 引擎核心
│       │   ├── render/          # 渲染后端（wgpu）
│       │   ├── ffi/             # C FFI 接口层
│       │   └── ...
       └── Ruffnova/
           ├── RuffleApp.swift        # App 入口
           ├── AppDelegate.swift      # macOS App Delegate
           ├── AppState.swift         # Observable 状态
           ├── ContentView.swift      # 主视图 + 控件
           ├── RufflePlayerView.swift # Metal 渲染视图
           ├── RuffleBridge.swift     # C FFI 桥接
           ├── RuffleCommands.swift   # 菜单栏命令
           ├── SettingsView.swift     # 偏好设置
           ├── RuffleBridgingHeader.h # C 桥接头文件
           ├── Info.plist             # App 元数据
           └── Ruffnova.entitlements
└── README.md
```

## FFI Interface

The Swift code communicates with the Rust core via a C ABI exposed in `ffi/include/ruffle_ffi.h`:

```c
// Player lifecycle
RufflePlayer* ruffle_player_create(RuffleConfig config);
void ruffle_player_free(RufflePlayer* ptr);

// Loading
RuffleResult ruffle_player_load_url(RufflePlayer* ptr, const char* url);

// Playback
RuffleResult ruffle_player_tick(RufflePlayer* ptr, float dt);
RuffleResult ruffle_player_render(RufflePlayer* ptr);

// Input
RuffleResult ruffle_player_key_event(RufflePlayer* ptr, RuffleKeyEvent event);
RuffleResult ruffle_player_mouse_event(RufflePlayer* ptr, RuffleMouseEvent event);

// Renderer
RuffleRenderer* ruffle_renderer_create(void* metal_layer, ...);
```

## Troubleshooting

### "ruffle_ffi.h not found"
Run `./build.sh` first to generate the header.

### "Undefined symbols for architecture arm64"
Make sure `libruffle_ffi.a` is added to the Xcode project's "Link Binary With Libraries" build phase.

### "Thread sanitizer" warnings
The FFI layer uses `Mutex<Player>` for thread safety. Some TSan warnings are expected due to the FFI boundary.

## License

Same as Ruffle — dual-licensed under MIT and Apache 2.0.
