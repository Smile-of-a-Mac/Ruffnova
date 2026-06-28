//! Ruffle FFI — C ABI bridge between the Rust core engine and Swift UI.
//!
//! This crate exposes a minimal C API that wraps `ruffle_core::Player` and
//! the wgpu rendering pipeline, designed to be called from Swift via a
//! static library.

mod player;
mod renderer;
mod types;

pub use player::*;
pub use renderer::*;
pub use types::*;
