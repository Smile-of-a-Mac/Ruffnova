//! C-compatible type definitions for the FFI boundary.

use std::os::raw::{c_char, c_float, c_int, c_uint};

// ─── Opaque handles ───────────────────────────────────────────────────────────

/// Opaque handle to a Ruffle player instance.
/// The Swift side holds this as `OpaquePointer`.
pub struct RufflePlayer {
    pub inner: std::sync::Arc<std::sync::Mutex<ruffle_core::Player>>,
    pub executor: ruffle_core::backend::navigator::NullExecutor,
    pub base_path: std::sync::Arc<std::sync::Mutex<std::path::PathBuf>>,
}

/// Opaque handle to a wgpu renderer bound to a Metal layer.
pub struct RuffleRenderer {
    pub backend: Option<Box<dyn ruffle_render::backend::RenderBackend>>,
}

// ─── Enumerations ─────────────────────────────────────────────────────────────

/// Mouse cursor types exposed to Swift.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RuffleMouseCursor {
    Arrow = 0,
    Hand = 1,
    Ibeam = 2,
}

/// Stage quality levels.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RuffleQuality {
    Low = 0,
    Medium = 1,
    High = 2,
    Best = 3,
    High8x8 = 4,
    High8x8Linear = 5,
    High16x16 = 6,
    High16x16Linear = 7,
}

impl From<RuffleQuality> for ruffle_render::quality::StageQuality {
    fn from(q: RuffleQuality) -> Self {
        match q {
            RuffleQuality::Low => Self::Low,
            RuffleQuality::Medium => Self::Medium,
            RuffleQuality::High => Self::High,
            RuffleQuality::Best => Self::Best,
            RuffleQuality::High8x8 => Self::High8x8,
            RuffleQuality::High8x8Linear => Self::High8x8Linear,
            RuffleQuality::High16x16 => Self::High16x16,
            RuffleQuality::High16x16Linear => Self::High16x16Linear,
        }
    }
}

// ─── Structures passed across FFI ─────────────────────────────────────────────

/// Player configuration provided by Swift at creation time.
#[repr(C)]
pub struct RuffleConfig {
    /// Stage width in pixels.
    pub width: c_uint,
    /// Stage height in pixels.
    pub height: c_uint,
    /// Retina scale factor (e.g. 2.0 for Retina).
    pub scale_factor: c_float,
    /// Stage quality.
    pub quality: RuffleQuality,
    /// Whether to autoplay on load.
    pub autoplay: bool,
    /// Max ActionScript execution duration in seconds. 0 = unlimited.
    pub max_execution_secs: c_float,
}

/// A key event forwarded from Swift.
#[repr(C)]
pub struct RuffleKeyEvent {
    /// Physical key code (USB HID usage).
    pub key_code: c_uint,
    /// Character code point (0 if not a character key).
    pub char_code: c_uint,
    /// True if key is pressed down, false if released.
    pub is_down: bool,
    /// Modifier keys bitmask: bit0=shift, bit1=control, bit2=alt, bit3=command.
    pub modifiers: c_uint,
}

/// A mouse event forwarded from Swift.
#[repr(C)]
pub struct RuffleMouseEvent {
    /// X position in stage coordinates.
    pub x: c_float,
    /// Y position in stage coordinates.
    pub y: c_float,
    /// Event type: 0=move, 1=left-down, 2=left-up, 3=right-down, 4=right-up, 5=scroll.
    pub event_type: c_int,
    /// Scroll delta Y (only for scroll events).
    pub scroll_delta: c_float,
}

/// C-compatible string wrapper. Caller must free with `ruffle_string_free`.
#[repr(C)]
pub struct RuffleString {
    pub data: *mut c_char,
    pub len: c_uint,
}

impl RuffleString {
    pub fn from_rust(s: String) -> Self {
        let len = s.len() as c_uint;
        let boxed = s.into_boxed_str();
        let ptr = Box::into_raw(boxed) as *mut c_char;
        Self { data: ptr, len }
    }
}

// ─── Metadata ─────────────────────────────────────────────────────────────────

/// SWF metadata returned from the player.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct RuffleMetadata {
    pub swf_version: u8,
    pub player_version: u8,
    pub is_action_script_3: bool,
    pub frame_rate: f32,
    pub movie_width: u32,
    pub movie_height: u32,
    pub total_frames: u32,
    pub uses_avm2: bool,
    pub background_color: u32,
}

/// Playback state snapshot for UI polling.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct RufflePlaybackInfo {
    pub current_frame: u32,
    pub total_frames: u32,
    pub frame_rate: f32,
    pub elapsed_time_secs: f32,
    pub is_playing: bool,
    pub is_looping: bool,
    pub speed_multiplier: f32,
}

/// Stage scale mode.
#[repr(C)]
#[derive(Clone, Copy)]
pub enum RuffleScaleMode {
    ShowAll = 0,
    NoScale = 1,
    ExactFit = 2,
    NoBorder = 3,
}

/// Letterbox mode.
#[repr(C)]
#[derive(Clone, Copy)]
pub enum RuffleLetterbox {
    Off = 0,
    Fullscreen = 1,
    On = 2,
}

/// Result codes for FFI operations.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RuffleResult {
    Ok = 0,
    ErrorNullPointer = -1,
    ErrorLockPoisoned = -2,
    ErrorInvalidArgument = -3,
    ErrorRendererInit = -4,
    ErrorLoadFailed = -5,
}
