//! Player lifecycle and control FFI functions.

use crate::types::*;
use ruffle_core::backend::ui::{
    DialogResultFuture, FileDialogResult, FileFilter, FontDefinition, FullscreenError,
    MouseCursor, MultiDialogResultFuture, MultiFileDialogResult, UiBackend, US_ENGLISH,
};
use ruffle_core::{PlayerBuilder, PlayerEvent, StageScaleMode};
use ruffle_core::backend::navigator::{
    ErrorResponse, NavigationMethod, NavigatorBackend, NullExecutor, NullSpawner, OwnedFuture,
    Request, SuccessResponse, fetch_path, resolve_url_with_relative_base_path,
};
use ruffle_core::events::{MouseButton, KeyDescriptor, PhysicalKey, LogicalKey, KeyLocation};
use ruffle_core::font::{FontFileData, FontQuery};
use ruffle_core::config::Letterbox;
use ruffle_core::indexmap::IndexMap;
use ruffle_core::loader::Error;
use ruffle_core::socket::{ConnectionState, SocketAction, SocketHandle};
use async_channel::{Receiver, Sender};
use std::any::Any;
use std::os::raw::{c_char, c_float, c_uint, c_void};
use ruffle_render_wgpu::backend::WgpuRenderBackend;
use ruffle_render_wgpu::target::SwapChainTarget;
use std::ffi::CStr;
use std::path::PathBuf;
use std::panic::AssertUnwindSafe;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use url::{ParseError, Url};

struct FfiUiBackend {
    font_database: Arc<fontdb::Database>,
}

impl FfiUiBackend {
    fn new() -> Self {
        let mut font_database = fontdb::Database::default();
        font_database.load_system_fonts();
        Self { font_database: Arc::new(font_database) }
    }

    fn register_face(
        &self,
        requested_name: &str,
        face: &fontdb::FaceInfo,
        register: &mut dyn FnMut(FontDefinition),
    ) {
        let bytes = match &face.source {
            fontdb::Source::File(path) => std::fs::read(path).ok(),
            fontdb::Source::Binary(data) | fontdb::Source::SharedFile(_, data) => {
                Some(data.as_ref().as_ref().to_vec())
            }
        };

        if let Some(bytes) = bytes {
            register(FontDefinition::FontFile {
                name: requested_name.to_string(),
                is_bold: face.weight > fontdb::Weight::NORMAL,
                is_italic: face.style != fontdb::Style::Normal,
                data: FontFileData::new(bytes),
                index: face.index,
            });
        }
    }
}

impl UiBackend for FfiUiBackend {
    fn mouse_visible(&self) -> bool { true }
    fn set_mouse_visible(&mut self, _visible: bool) {}
    fn set_mouse_cursor(&mut self, _cursor: MouseCursor) {}
    fn clipboard_content(&mut self) -> String { String::new() }
    fn set_clipboard_content(&mut self, _content: String) {}
    fn set_fullscreen(&mut self, _is_full: bool) -> Result<(), FullscreenError> { Ok(()) }
    fn display_root_movie_download_failed_message(&self, _invalid_swf: bool, _fetched_error: String) {}
    fn message(&self, _message: &str) {}
    fn open_virtual_keyboard(&self) {}
    fn close_virtual_keyboard(&self) {}
    fn language(&self) -> ruffle_core::backend::ui::LanguageIdentifier { US_ENGLISH.clone() }
    fn display_unsupported_video(&self, url: Url) { println!("[ruffle_ffi] unsupported video: {url}"); }

    fn load_device_font(&self, query: &FontQuery, register: &mut dyn FnMut(FontDefinition)) {
        let font_query = fontdb::Query {
            families: &[fontdb::Family::Name(&query.name)],
            weight: if query.is_bold { fontdb::Weight::BOLD } else { fontdb::Weight::NORMAL },
            style: if query.is_italic { fontdb::Style::Italic } else { fontdb::Style::Normal },
            ..Default::default()
        };

        if let Some(id) = self.font_database.query(&font_query)
            && let Some(face) = self.font_database.face(id)
        {
            self.register_face(&query.name, face, register);
        }
    }

    fn sort_device_fonts(&self, _query: &FontQuery, _register: &mut dyn FnMut(FontDefinition)) -> Vec<FontQuery> {
        Vec::new()
    }

    fn display_file_open_dialog(&mut self, _filters: Vec<FileFilter>) -> Option<DialogResultFuture> {
        Some(Box::pin(async move { Ok(FileDialogResult::Canceled) }))
    }

    fn display_file_open_dialog_multiple(&mut self, _filters: Vec<FileFilter>) -> Option<MultiDialogResultFuture> {
        Some(Box::pin(async move { Ok(MultiFileDialogResult::Canceled) }))
    }

    fn display_file_save_dialog(&mut self, _file_name: String, _title: String) -> Option<DialogResultFuture> {
        None
    }

    fn close_file_dialog(&mut self) {}
}

struct FfiNavigatorBackend {
    spawner: NullSpawner,
    base_path: Arc<Mutex<PathBuf>>,
}

impl NavigatorBackend for FfiNavigatorBackend {
    fn navigate_to_url(
        &self,
        url: &str,
        _target: &str,
        _vars_method: Option<(NavigationMethod, IndexMap<String, String>)>,
    ) {
        println!("[ruffle_ffi] navigate_to_url ignored: {url}");
    }

    fn fetch(&self, request: Request) -> OwnedFuture<Box<dyn SuccessResponse>, ErrorResponse> {
        let base_path = self.base_path.lock().ok().map(|path| path.clone());
        fetch_path(self, "FfiNavigatorBackend", request.url(), base_path.as_deref())
    }

    fn resolve_url(&self, url: &str) -> Result<Url, ParseError> {
        let base_path = self.base_path.lock().map(|path| path.clone()).unwrap_or_default();
        resolve_url_with_relative_base_path(self, base_path, url)
    }

    fn spawn_future(&mut self, future: OwnedFuture<(), Error>) {
        self.spawner.spawn_local(future);
    }

    fn pre_process_url(&self, url: Url) -> Url {
        url
    }

    fn connect_socket(
        &mut self,
        _host: String,
        _port: u16,
        _timeout: Duration,
        handle: SocketHandle,
        _receiver: Receiver<Vec<u8>>,
        sender: Sender<SocketAction>,
    ) {
        let _ = sender.try_send(SocketAction::Connect(handle, ConnectionState::Failed));
    }
}

// ─── Lifecycle ────────────────────────────────────────────────────────────────

/// Create a new Ruffle player with the given configuration.
/// Returns an opaque handle, or null on failure.
///
/// # Safety
/// The returned handle must be freed with `ruffle_player_free`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_create(config: RuffleConfig) -> *mut RufflePlayer {
    unsafe { ruffle_player_create_with_renderer(config, std::ptr::null_mut()) }
}

/// Create a new Ruffle player using a renderer created by `ruffle_renderer_create`.
/// Returns an opaque handle, or null on failure.
///
/// # Safety
/// The returned handle must be freed with `ruffle_player_free`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_create_with_renderer(
    config: RuffleConfig,
    renderer: *mut RuffleRenderer,
) -> *mut RufflePlayer {
    let result = std::panic::catch_unwind(AssertUnwindSafe(|| {
        let executor = NullExecutor::new();
        let base_path = Arc::new(Mutex::new(PathBuf::new()));
        let mut builder = PlayerBuilder::new()
            .with_navigator(FfiNavigatorBackend {
                spawner: executor.spawner(),
                base_path: base_path.clone(),
            })
            .with_viewport_dimensions(config.width, config.height, config.scale_factor as f64)
            .with_quality(config.quality.into())
            .with_autoplay(config.autoplay)
            .with_letterbox(Letterbox::Fullscreen)
            .with_ui(FfiUiBackend::new())
            .with_scale_mode(StageScaleMode::ShowAll, false)
            .with_align(Default::default(), false)
            .with_video(ruffle_video_software::backend::SoftwareVideoBackend::new())
            .with_max_execution_duration(if config.max_execution_secs > 0.0 {
                Duration::from_secs_f32(config.max_execution_secs)
            } else {
                Duration::from_secs(u64::MAX)
            });

        match ruffle_frontend_utils::backends::audio::CpalAudioBackend::new(None) {
            Ok(audio) => {
                builder = builder.with_audio(audio);
            }
            Err(error) => {
                println!("[ruffle_ffi] audio backend unavailable, using silent fallback: {error}");
            }
        }

        if !renderer.is_null() {
            let renderer = unsafe { &mut *renderer };
            if let Some(backend) = renderer.backend.take() {
                builder = builder.with_boxed_renderer(backend);
            }
        }

        let player_arc = builder.build();

        let wrapper = RufflePlayer { inner: player_arc, executor, base_path };
        Box::into_raw(Box::new(wrapper))
    }));

    match result {
        Ok(ptr) => ptr,
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free a player handle.
///
/// # Safety
/// `ptr` must be a valid pointer returned by `ruffle_player_create`, and must not be used after this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_free(ptr: *mut RufflePlayer) {
    if !ptr.is_null() {
        unsafe { drop(Box::from_raw(ptr)); }
    }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

/// Load a SWF from a file URL (file:// or http(s)://).
///
/// # Safety
/// `ptr` must be valid. `url` must be a null-terminated UTF-8 C string.
/// `url` must remain valid for the duration of this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_load_url(ptr: *mut RufflePlayer, url: *const c_char) -> RuffleResult {
    if ptr.is_null() || url.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let url_str = match unsafe { CStr::from_ptr(url) }.to_str() {
        Ok(s) => s.to_owned(),
        Err(_) => return RuffleResult::ErrorInvalidArgument,
    };
    let base_path = Url::parse(&url_str)
        .ok()
        .and_then(|url| url.to_file_path().ok())
        .and_then(|path| path.parent().map(|parent| parent.to_path_buf()))
        .unwrap_or_default();

    let player = unsafe { &(*ptr).inner };
    if let Ok(mut path) = unsafe { &(*ptr).base_path }.lock() {
        *path = base_path;
    }
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };

    guard.fetch_root_movie(url_str, Vec::new(), Box::new(|_| {}));
    RuffleResult::Ok
}

/// Load a SWF from a byte buffer.
///
/// # Safety
/// `ptr` must be valid. `data` must point to `len` valid bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_load_data(
    ptr: *mut RufflePlayer,
    data: *const u8,
    len: c_uint,
) -> RuffleResult {
    unsafe { ruffle_player_load_data_with_url(ptr, data, len, c"file:///movie.swf".as_ptr()) }
}

/// Load a SWF from a byte buffer using the provided URL as its base URL.
///
/// # Safety
/// `ptr` must be valid. `data` must point to `len` valid bytes.
/// `url` must be a null-terminated UTF-8 C string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_load_data_with_url(
    ptr: *mut RufflePlayer,
    data: *const u8,
    len: c_uint,
    url: *const c_char,
) -> RuffleResult {
    if ptr.is_null() || data.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let url_str = match unsafe { CStr::from_ptr(url) }.to_str() {
        Ok(s) => s.to_owned(),
        Err(_) => return RuffleResult::ErrorInvalidArgument,
    };
    let base_path = Url::parse(&url_str)
        .ok()
        .and_then(|url| url.to_file_path().ok())
        .and_then(|path| path.parent().map(|parent| parent.to_path_buf()))
        .unwrap_or_default();

    let bytes = unsafe { std::slice::from_raw_parts(data, len as usize) };
    let movie = match ruffle_core::tag_utils::SwfMovie::from_data(bytes, url_str, None) {
        Ok(m) => m,
        Err(_) => return RuffleResult::ErrorLoadFailed,
    };

    let player = unsafe { &(*ptr).inner };
    if let Ok(mut path) = unsafe { &(*ptr).base_path }.lock() {
        *path = base_path;
    }
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };

    guard.mutate_with_update_context(|uc| uc.set_root_movie(movie));
    RuffleResult::Ok
}

// ─── Playback control ─────────────────────────────────────────────────────────

/// Advance the player by `dt` seconds.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_tick(ptr: *mut RufflePlayer, dt: c_float) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    unsafe { &mut *ptr }.executor.run();
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.tick(ruffle_core::FloatDuration::from_secs(dt as f64));
    drop(guard);
    unsafe { &mut *ptr }.executor.run();
    RuffleResult::Ok
}

/// Render the current frame.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_render(ptr: *mut RufflePlayer) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.render();
    RuffleResult::Ok
}

/// Set whether the player is playing or paused.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_playing(ptr: *mut RufflePlayer, playing: bool) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_is_playing(playing);
    RuffleResult::Ok
}

/// Check if the player is currently playing.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_is_playing(ptr: *const RufflePlayer) -> bool {
    if ptr.is_null() {
        return false;
    }
    let player = unsafe { &(*ptr).inner };
    player.lock().map(|g| g.is_playing()).unwrap_or(false)
}

/// Set volume (0.0 to 1.0).
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_volume(ptr: *mut RufflePlayer, volume: c_float) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_volume(volume.clamp(0.0, 1.0));
    RuffleResult::Ok
}

/// Get current volume.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_get_volume(ptr: *const RufflePlayer) -> c_float {
    if ptr.is_null() {
        return 0.0;
    }
    let player = unsafe { &(*ptr).inner };
    player.lock().map(|g| g.volume()).unwrap_or(0.0)
}

// ─── Input events ─────────────────────────────────────────────────────────────

/// Forward a key event from Swift.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_key_event(ptr: *mut RufflePlayer, event: RuffleKeyEvent) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }

    let physical = physical_key_from_hid(event.key_code);
    let logical = logical_key_from_hid(event.key_code, event.char_code);

    let descriptor = KeyDescriptor {
        physical_key: physical,
        logical_key: logical,
        key_location: KeyLocation::Standard,
    };

    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };

    if event.is_down {
        guard.handle_event(PlayerEvent::KeyDown { key: descriptor });
        if event.char_code > 0 {
            if let Some(ch) = char::from_u32(event.char_code) {
                guard.handle_event(PlayerEvent::TextInput { codepoint: ch });
            }
        }
    } else {
        guard.handle_event(PlayerEvent::KeyUp { key: descriptor });
    }
    RuffleResult::Ok
}

/// Forward a mouse event from Swift.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_mouse_event(ptr: *mut RufflePlayer, event: RuffleMouseEvent) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }

    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };

    match event.event_type {
        0 => {
            guard.handle_event(PlayerEvent::MouseMove {
                x: event.x as f64,
                y: event.y as f64,
            });
        }
        1 => {
            guard.handle_event(PlayerEvent::MouseDown {
                x: event.x as f64,
                y: event.y as f64,
                button: MouseButton::Left,
                index: None,
            });
        }
        2 => {
            guard.handle_event(PlayerEvent::MouseUp {
                x: event.x as f64,
                y: event.y as f64,
                button: MouseButton::Left,
            });
        }
        3 => {
            guard.handle_event(PlayerEvent::MouseDown {
                x: event.x as f64,
                y: event.y as f64,
                button: MouseButton::Right,
                index: None,
            });
        }
        4 => {
            guard.handle_event(PlayerEvent::MouseUp {
                x: event.x as f64,
                y: event.y as f64,
                button: MouseButton::Right,
            });
        }
        5 => {
            guard.handle_event(PlayerEvent::MouseWheel {
                delta: ruffle_core::events::MouseWheelDelta::Lines(event.scroll_delta as f64),
            });
        }
        _ => {}
    }
    RuffleResult::Ok
}

/// Update the viewport dimensions (e.g. on window resize).
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_viewport(
    ptr: *mut RufflePlayer,
    width: c_uint,
    height: c_uint,
    scale_factor: c_float,
) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_viewport_dimensions(ruffle_render::backend::ViewportDimensions {
        width,
        height,
        scale_factor: scale_factor as f64,
    });
    RuffleResult::Ok
}

/// Set fullscreen state.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_fullscreen(ptr: *mut RufflePlayer, fullscreen: bool) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_fullscreen(fullscreen);
    RuffleResult::Ok
}

// ─── Playback Info Query ─────────────────────────────────────────────────────

/// Get a snapshot of the current playback state.
///
/// # Safety
/// `ptr` must be valid. `info` must be a valid pointer to a `RufflePlaybackInfo`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_get_playback_info(
    ptr: *const RufflePlayer,
    info: *mut RufflePlaybackInfo,
) -> RuffleResult {
    if ptr.is_null() || info.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    let info_ref = unsafe { &mut *info };
    info_ref.current_frame = guard.current_frame().unwrap_or(0) as u32;
    info_ref.frame_rate = guard.frame_rate() as f32;
    info_ref.is_playing = guard.is_playing();
    info_ref.is_looping = false;
    info_ref.speed_multiplier = 1.0;
    info_ref.total_frames = 0;
    info_ref.elapsed_time_secs = 0.0;
    RuffleResult::Ok
}

// ─── Metadata Query ─────────────────────────────────────────────────────────

/// Get SWF metadata.
///
/// # Safety
/// `ptr` must be valid. `out` must be a valid pointer to a `RuffleMetadata`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_get_metadata(
    ptr: *mut RufflePlayer,
    out: *mut RuffleMetadata,
) -> RuffleResult {
    if ptr.is_null() || out.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    let out_ref = unsafe { &mut *out };
    out_ref.swf_version = guard.swf_version();
    out_ref.player_version = guard.player_version();
    out_ref.is_action_script_3 = guard.is_action_script_3();
    out_ref.frame_rate = guard.frame_rate() as f32;
    out_ref.movie_width = guard.movie_width();
    out_ref.movie_height = guard.movie_height();
    out_ref.total_frames = guard.current_frame().unwrap_or(0) as u32;
    out_ref.uses_avm2 = guard.is_action_script_3();
    out_ref.background_color = 0xFFFFFFFF;
    RuffleResult::Ok
}

/// Set the stage background color used by Ruffle when the SWF does not provide one.
/// Color format is AARRGGBB.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_background_color(
    ptr: *mut RufflePlayer,
    color: c_uint,
) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_background_color(Some(ruffle_core::Color::from_rgba(color)));
    RuffleResult::Ok
}

// ─── Seek ────────────────────────────────────────────────────────────────────

/// Seek to a specific frame number.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_seek_frame(
    ptr: *mut RufflePlayer,
    frame: u32,
) -> RuffleResult {
    if ptr.is_null() { return RuffleResult::ErrorNullPointer; }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.mutate_with_update_context(|context| {
        if let Some(mc) = context.stage.root_clip().and_then(|r| r.as_movie_clip()) {
            mc.goto_frame(context, (frame.max(1) as u16).min(u16::MAX), true);
        }
    });
    RuffleResult::Ok
}

/// Seek to a time in seconds.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_seek_time(
    ptr: *mut RufflePlayer,
    seconds: f32,
) -> RuffleResult {
    if ptr.is_null() { return RuffleResult::ErrorNullPointer; }
    let player = unsafe { &(*ptr).inner };
    let guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    let frame_rate = guard.frame_rate();
    drop(guard);
    if frame_rate > 0.0 {
        let target = ((seconds as f64) * frame_rate).round() as u32;
        return unsafe { ruffle_player_seek_frame(ptr, target.max(1)) };
    }
    RuffleResult::ErrorInvalidArgument
}

/// Step backward by N frames.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_step_back(
    ptr: *mut RufflePlayer,
    frames: u32,
) -> RuffleResult {
    if ptr.is_null() { return RuffleResult::ErrorNullPointer; }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    for _ in 0..frames {
        guard.mutate_with_update_context(|context| {
            if let Some(mc) = context.stage.root_clip().and_then(|r| r.as_movie_clip()) {
                mc.prev_frame(context);
            }
        });
    }
    RuffleResult::Ok
}

/// Rewind to the first frame.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_rewind(ptr: *mut RufflePlayer) -> RuffleResult {
    if ptr.is_null() { return RuffleResult::ErrorNullPointer; }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.mutate_with_update_context(|context| {
        ruffle_core::Player::rewind_root_movie(context);
    });
    RuffleResult::Ok
}

// ─── Loop / Speed / Stage Control ────────────────────────────────────────────

/// Set whether playback should loop. (Stub — looping is handled on Swift side.)
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_looping(
    _ptr: *mut RufflePlayer, _looping: bool
) -> RuffleResult { RuffleResult::Ok }

/// Set playback speed multiplier. (Stub — speed is applied via dt on Swift side.)
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_speed(
    _ptr: *mut RufflePlayer, _speed: f32
) -> RuffleResult { RuffleResult::Ok }

/// Set the stage scale mode.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_scale_mode(
    ptr: *mut RufflePlayer, mode: RuffleScaleMode,
) -> RuffleResult {
    if ptr.is_null() { return RuffleResult::ErrorNullPointer; }
    let scale_mode = match mode {
        RuffleScaleMode::ShowAll => ruffle_core::StageScaleMode::ShowAll,
        RuffleScaleMode::NoScale => ruffle_core::StageScaleMode::NoScale,
        RuffleScaleMode::ExactFit => ruffle_core::StageScaleMode::ExactFit,
        RuffleScaleMode::NoBorder => ruffle_core::StageScaleMode::NoBorder,
    };
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g, Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_scale_mode(scale_mode);
    RuffleResult::Ok
}

/// Set the letterbox mode.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_letterbox_mode(
    ptr: *mut RufflePlayer, mode: RuffleLetterbox,
) -> RuffleResult {
    if ptr.is_null() { return RuffleResult::ErrorNullPointer; }
    let letterbox = match mode {
        RuffleLetterbox::Off => ruffle_core::config::Letterbox::Off,
        RuffleLetterbox::Fullscreen => ruffle_core::config::Letterbox::Fullscreen,
        RuffleLetterbox::On => ruffle_core::config::Letterbox::On,
    };
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g, Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_letterbox(letterbox);
    RuffleResult::Ok
}

/// Set the stage quality.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_set_quality(
    ptr: *mut RufflePlayer, quality: RuffleQuality,
) -> RuffleResult {
    if ptr.is_null() { return RuffleResult::ErrorNullPointer; }
    let sq: ruffle_render::quality::StageQuality = quality.into();
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g, Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    guard.set_quality(sq);
    RuffleResult::Ok
}

/// Recreate the renderer's GPU surface with a new CAMetalLayer.
///
/// This is called when the NSView/MTKView is recreated (e.g. after navigating
/// away and back in the SwiftUI sidebar). Unlike `ruffle_renderer_recreate_surface`,
/// this operates on the Player which still owns the render backend.
///
/// # Safety
/// `ptr` must be valid. `metal_layer` must be a valid pointer to a `CAMetalLayer`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_recreate_surface(
    ptr: *mut RufflePlayer,
    metal_layer: *mut c_void,
    width: c_uint,
    height: c_uint,
) -> RuffleResult {
    if ptr.is_null() || metal_layer.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let player = unsafe { &(*ptr).inner };
    let mut guard = match player.lock() {
        Ok(g) => g,
        Err(_) => return RuffleResult::ErrorLockPoisoned,
    };
    let target = wgpu::SurfaceTargetUnsafe::CoreAnimationLayer(metal_layer as *mut _);
    guard.mutate_with_update_context(|context| {
        let renderer: &mut dyn ruffle_render::backend::RenderBackend = context.renderer;
        let wgpu_backend: &mut WgpuRenderBackend<SwapChainTarget> =
            (renderer as &mut dyn Any)
                .downcast_mut::<WgpuRenderBackend<SwapChainTarget>>()
                .expect("Renderer backend is not WgpuRenderBackend<SwapChainTarget>");
        // recreate_surface_unsafe is unsafe because it takes a raw layer pointer.
        unsafe {
            let _ = wgpu_backend.recreate_surface_unsafe(target, (width.max(1), height.max(1)));
        }
    });
    RuffleResult::Ok
}

/// Get the SWF stage width.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_stage_width(ptr: *const RufflePlayer) -> c_uint {
    if ptr.is_null() {
        return 0;
    }
    let player = unsafe { &(*ptr).inner };
    player.lock().map(|mut g| g.movie_width()).unwrap_or(0)
}

/// Get the SWF stage height.
///
/// # Safety
/// `ptr` must be valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_player_stage_height(ptr: *const RufflePlayer) -> c_uint {
    if ptr.is_null() {
        return 0;
    }
    let player = unsafe { &(*ptr).inner };
    player.lock().map(|mut g| g.movie_height()).unwrap_or(0)
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

fn physical_key_from_hid(hid: c_uint) -> PhysicalKey {
    match hid {
        0x04 => PhysicalKey::KeyA,
        0x05 => PhysicalKey::KeyB,
        0x06 => PhysicalKey::KeyC,
        0x07 => PhysicalKey::KeyD,
        0x08 => PhysicalKey::KeyE,
        0x09 => PhysicalKey::KeyF,
        0x0A => PhysicalKey::KeyG,
        0x0B => PhysicalKey::KeyH,
        0x0C => PhysicalKey::KeyI,
        0x0D => PhysicalKey::KeyJ,
        0x0E => PhysicalKey::KeyK,
        0x0F => PhysicalKey::KeyL,
        0x10 => PhysicalKey::KeyM,
        0x11 => PhysicalKey::KeyN,
        0x12 => PhysicalKey::KeyO,
        0x13 => PhysicalKey::KeyP,
        0x14 => PhysicalKey::KeyQ,
        0x15 => PhysicalKey::KeyR,
        0x16 => PhysicalKey::KeyS,
        0x17 => PhysicalKey::KeyT,
        0x18 => PhysicalKey::KeyU,
        0x19 => PhysicalKey::KeyV,
        0x1A => PhysicalKey::KeyW,
        0x1B => PhysicalKey::KeyX,
        0x1C => PhysicalKey::KeyY,
        0x1D => PhysicalKey::KeyZ,
        0x1E => PhysicalKey::Digit1,
        0x1F => PhysicalKey::Digit2,
        0x20 => PhysicalKey::Digit3,
        0x21 => PhysicalKey::Digit4,
        0x22 => PhysicalKey::Digit5,
        0x23 => PhysicalKey::Digit6,
        0x24 => PhysicalKey::Digit7,
        0x25 => PhysicalKey::Digit8,
        0x26 => PhysicalKey::Digit9,
        0x27 => PhysicalKey::Digit0,
        0x28 => PhysicalKey::Enter,
        0x29 => PhysicalKey::Escape,
        0x2A => PhysicalKey::Backspace,
        0x2B => PhysicalKey::Tab,
        0x2C => PhysicalKey::Space,
        0x4F => PhysicalKey::ArrowRight,
        0x50 => PhysicalKey::ArrowLeft,
        0x51 => PhysicalKey::ArrowDown,
        0x52 => PhysicalKey::ArrowUp,
        _ => PhysicalKey::Unknown,
    }
}

fn logical_key_from_hid(hid: c_uint, char_code: c_uint) -> LogicalKey {
    if char_code > 0 {
        if let Some(ch) = char::from_u32(char_code) {
            return LogicalKey::Character(ch);
        }
    }
    match hid {
        0x28 => LogicalKey::Named(ruffle_core::events::NamedKey::Enter),
        0x29 => LogicalKey::Named(ruffle_core::events::NamedKey::Escape),
        0x2A => LogicalKey::Named(ruffle_core::events::NamedKey::Backspace),
        0x2B => LogicalKey::Named(ruffle_core::events::NamedKey::Tab),
        0x2C => LogicalKey::Character(' '),
        0x4F => LogicalKey::Named(ruffle_core::events::NamedKey::ArrowRight),
        0x50 => LogicalKey::Named(ruffle_core::events::NamedKey::ArrowLeft),
        0x51 => LogicalKey::Named(ruffle_core::events::NamedKey::ArrowDown),
        0x52 => LogicalKey::Named(ruffle_core::events::NamedKey::ArrowUp),
        _ => LogicalKey::Unknown,
    }
}

/// Free a string returned by the FFI.
///
/// # Safety
/// `s` must have been returned by an FFI function.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_string_free(s: RuffleString) {
    if !s.data.is_null() {
        unsafe {
            let _ = Box::from_raw(std::slice::from_raw_parts_mut(s.data, s.len as usize));
        }
    }
}
