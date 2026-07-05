# Ruffle Engine

This directory contains the [Ruffle](https://github.com/ruffle-rs/ruffle) Flash
emulator source code, cloned as a Git submodule-style dependency. Ruffle is a
Flash Player emulator written in Rust.

## Structure

```
engine/
├── core/          — Core Flash rendering engine
├── desktop/       — Desktop (egui) application
├── web/           — WebAssembly/web target and browser extension
├── render/        — Render backends (wgpu, OpenGL, etc.)
├── swf/           — SWF parser and format definitions
├── video/         — Video codec decoders
├── flv/           — FLV container parser
├── wstr/          — Flash-compatible wide string handling
├── scanner/       — File system scanner for SWF files
├── fuzz/          — Fuzzing harness
├── tests/         — Test SWF assets and visual test suite
├── tools/         — Build tools and utilities
├── ffmpeg/        — FFmpeg bindings (optional)
├── exporter/      — Standalone SWF exporter
├── frontend-utils/— Shared frontend UI utilities (web)
├── docs/          — Ruffle documentation
├── Cargo.toml     — Rust workspace manifest
└── Cargo.lock     — Locked Rust dependency versions
```

## Usage

Run `setup.sh` from the repository root to clone or update Ruffle and build the
FFI library:

```bash
./setup.sh --target macos    # Build for macOS only
./setup.sh --target ios      # Build for iOS (arm64)
./setup.sh --target all      # Build all targets
```

The FFI build output goes to `CRuffleFFI/` and is linked into the Ruffnova
Xcode project.
