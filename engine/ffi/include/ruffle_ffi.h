#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <ostream>
#include <new>

/// Stage quality levels.
enum class RuffleQuality {
  Low = 0,
  Medium = 1,
  High = 2,
  Best = 3,
  High8x8 = 4,
  High8x8Linear = 5,
  High16x16 = 6,
  High16x16Linear = 7,
};

/// Result codes for FFI operations.
enum class RuffleResult {
  Ok = 0,
  ErrorNullPointer = -1,
  ErrorLockPoisoned = -2,
  ErrorInvalidArgument = -3,
  ErrorRendererInit = -4,
  ErrorLoadFailed = -5,
};

/// Stage scale mode.
enum class RuffleScaleMode {
  ShowAll = 0,
  NoScale = 1,
  ExactFit = 2,
  NoBorder = 3,
};

/// Letterbox mode.
enum class RuffleLetterbox {
  Off = 0,
  Fullscreen = 1,
  On = 2,
};

/// Opaque handle to a Ruffle player instance.
/// The Swift side holds this as `OpaquePointer`.
struct RufflePlayer;

/// Opaque handle to a wgpu renderer bound to a Metal layer.
struct RuffleRenderer;

/// Player configuration provided by Swift at creation time.
struct RuffleConfig {
  /// Stage width in pixels.
  unsigned int width;
  /// Stage height in pixels.
  unsigned int height;
  /// Retina scale factor (e.g. 2.0 for Retina).
  float scale_factor;
  /// Stage quality.
  RuffleQuality quality;
  /// Whether to autoplay on load.
  bool autoplay;
  /// Max ActionScript execution duration in seconds. 0 = unlimited.
  float max_execution_secs;
};

/// A key event forwarded from Swift.
struct RuffleKeyEvent {
  /// Physical key code (USB HID usage).
  unsigned int key_code;
  /// Character code point (0 if not a character key).
  unsigned int char_code;
  /// True if key is pressed down, false if released.
  bool is_down;
  /// Modifier keys bitmask: bit0=shift, bit1=control, bit2=alt, bit3=command.
  unsigned int modifiers;
};

/// A mouse event forwarded from Swift.
struct RuffleMouseEvent {
  /// X position in stage coordinates.
  float x;
  /// Y position in stage coordinates.
  float y;
  /// Event type: 0=move, 1=left-down, 2=left-up, 3=right-down, 4=right-up, 5=scroll.
  int event_type;
  /// Scroll delta Y (only for scroll events).
  float scroll_delta;
};

/// Playback state snapshot for UI polling.
struct RufflePlaybackInfo {
  uint32_t current_frame;
  uint32_t total_frames;
  float frame_rate;
  float elapsed_time_secs;
  bool is_playing;
  bool is_looping;
  float speed_multiplier;
};

/// SWF metadata returned from the player.
struct RuffleMetadata {
  uint8_t swf_version;
  uint8_t player_version;
  bool is_action_script_3;
  float frame_rate;
  uint32_t movie_width;
  uint32_t movie_height;
  uint32_t total_frames;
  bool uses_avm2;
  uint32_t background_color;
};

/// C-compatible string wrapper. Caller must free with `ruffle_string_free`.
struct RuffleString {
  char *data;
  unsigned int len;
};

extern "C" {

/// Create a new Ruffle player with the given configuration.
/// Returns an opaque handle, or null on failure.
///
/// # Safety
/// The returned handle must be freed with `ruffle_player_free`.
RufflePlayer *ruffle_player_create(RuffleConfig config);

/// Create a new Ruffle player using a renderer created by `ruffle_renderer_create`.
/// Returns an opaque handle, or null on failure.
///
/// # Safety
/// The returned handle must be freed with `ruffle_player_free`.
RufflePlayer *ruffle_player_create_with_renderer(RuffleConfig config, RuffleRenderer *renderer);

/// Free a player handle.
///
/// # Safety
/// `ptr` must be a valid pointer returned by `ruffle_player_create`, and must not be used after this call.
void ruffle_player_free(RufflePlayer *ptr);

/// Load a SWF from a file URL (file:// or http(s)://).
///
/// # Safety
/// `ptr` must be valid. `url` must be a null-terminated UTF-8 C string.
/// `url` must remain valid for the duration of this call.
RuffleResult ruffle_player_load_url(RufflePlayer *ptr, const char *url);

/// Load a SWF from a byte buffer.
///
/// # Safety
/// `ptr` must be valid. `data` must point to `len` valid bytes.
RuffleResult ruffle_player_load_data(RufflePlayer *ptr, const uint8_t *data, unsigned int len);

/// Load a SWF from a byte buffer using the provided URL as its base URL.
///
/// # Safety
/// `ptr` must be valid. `data` must point to `len` valid bytes.
/// `url` must be a null-terminated UTF-8 C string.
RuffleResult ruffle_player_load_data_with_url(RufflePlayer *ptr,
                                              const uint8_t *data,
                                              unsigned int len,
                                              const char *url);

/// Advance the player by `dt` seconds.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_tick(RufflePlayer *ptr, float dt);

/// Render the current frame.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_render(RufflePlayer *ptr);

/// Set whether the player is playing or paused.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_playing(RufflePlayer *ptr, bool playing);

/// Check if the player is currently playing.
///
/// # Safety
/// `ptr` must be valid.
bool ruffle_player_is_playing(const RufflePlayer *ptr);

/// Set volume (0.0 to 1.0).
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_volume(RufflePlayer *ptr, float volume);

/// Get current volume.
///
/// # Safety
/// `ptr` must be valid.
float ruffle_player_get_volume(const RufflePlayer *ptr);

/// Forward a key event from Swift.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_key_event(RufflePlayer *ptr, RuffleKeyEvent event);

/// Forward a mouse event from Swift.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_mouse_event(RufflePlayer *ptr, RuffleMouseEvent event);

/// Update the viewport dimensions (e.g. on window resize).
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_viewport(RufflePlayer *ptr,
                                        unsigned int width,
                                        unsigned int height,
                                        float scale_factor);

/// Set fullscreen state.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_fullscreen(RufflePlayer *ptr, bool fullscreen);

/// Get a snapshot of the current playback state.
///
/// # Safety
/// `ptr` must be valid. `info` must be a valid pointer to a `RufflePlaybackInfo`.
RuffleResult ruffle_player_get_playback_info(const RufflePlayer *ptr, RufflePlaybackInfo *info);

/// Get SWF metadata.
///
/// # Safety
/// `ptr` must be valid. `out` must be a valid pointer to a `RuffleMetadata`.
RuffleResult ruffle_player_get_metadata(RufflePlayer *ptr, RuffleMetadata *out);

/// Set the stage background color used by Ruffle when the SWF does not provide one.
/// Color format is AARRGGBB.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_background_color(RufflePlayer *ptr, unsigned int color);

/// Seek to a specific frame number.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_seek_frame(RufflePlayer *ptr, uint32_t frame);

/// Seek to a time in seconds.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_seek_time(RufflePlayer *ptr, float seconds);

/// Step backward by N frames.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_step_back(RufflePlayer *ptr, uint32_t frames);

/// Rewind to the first frame.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_rewind(RufflePlayer *ptr);

/// Set whether playback should loop. (Stub — looping is handled on Swift side.)
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_looping(RufflePlayer *_ptr, bool _looping);

/// Set playback speed multiplier. (Stub — speed is applied via dt on Swift side.)
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_speed(RufflePlayer *_ptr, float _speed);

/// Set the stage scale mode.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_scale_mode(RufflePlayer *ptr, RuffleScaleMode mode);

/// Set the letterbox mode.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_letterbox_mode(RufflePlayer *ptr, RuffleLetterbox mode);

/// Set the stage quality.
///
/// # Safety
/// `ptr` must be valid.
RuffleResult ruffle_player_set_quality(RufflePlayer *ptr, RuffleQuality quality);

/// Recreate the renderer's GPU surface with a new CAMetalLayer.
///
/// This is called when the NSView/MTKView is recreated (e.g. after navigating
/// away and back in the SwiftUI sidebar). Unlike `ruffle_renderer_recreate_surface`,
/// this operates on the Player which still owns the render backend.
///
/// # Safety
/// `ptr` must be valid. `metal_layer` must be a valid pointer to a `CAMetalLayer`.
RuffleResult ruffle_player_recreate_surface(RufflePlayer *ptr,
                                            void *metal_layer,
                                            unsigned int width,
                                            unsigned int height);

/// Get the SWF stage width.
///
/// # Safety
/// `ptr` must be valid.
unsigned int ruffle_player_stage_width(const RufflePlayer *ptr);

/// Get the SWF stage height.
///
/// # Safety
/// `ptr` must be valid.
unsigned int ruffle_player_stage_height(const RufflePlayer *ptr);

/// Free a string returned by the FFI.
///
/// # Safety
/// `s` must have been returned by an FFI function.
void ruffle_string_free(RuffleString s);

/// Create a wgpu renderer from a CAMetalLayer pointer.
///
/// The `metal_layer` must be a valid `CAMetalLayer*` from a `MTKView` or `NSView`.
/// The layer must remain alive for the lifetime of the returned renderer.
///
/// # Safety
/// `metal_layer` must be a valid pointer to a `CAMetalLayer`.
RuffleRenderer *ruffle_renderer_create(void *metal_layer,
                                       unsigned int width,
                                       unsigned int height,
                                       float _scale_factor);

/// Resize the renderer surface (e.g. on window resize).
///
/// # Safety
/// `ptr` must be a valid renderer handle.
RuffleResult ruffle_renderer_resize(RuffleRenderer *ptr,
                                    unsigned int width,
                                    unsigned int height,
                                    float scale_factor);

/// Recreate the renderer's surface with a new CAMetalLayer.
///
/// This allows updating the Metal layer when the NSView/MTKView is
/// recreated (e.g. after navigating away and back), without destroying
/// the player or losing playback state.
///
/// # Safety
/// `ptr` must be a valid renderer handle. `metal_layer` must be a valid
/// pointer to a `CAMetalLayer`.
RuffleResult ruffle_renderer_recreate_surface(RuffleRenderer *ptr,
                                              void *metal_layer,
                                              unsigned int width,
                                              unsigned int height);

/// Get the surface texture format (for Metal interop if needed).
///
/// # Safety
/// `ptr` must be a valid renderer handle.
unsigned int ruffle_renderer_surface_format(const RuffleRenderer *ptr);

/// Present the current frame.
///
/// # Safety
/// `ptr` must be a valid renderer handle.
RuffleResult ruffle_renderer_present(RuffleRenderer *ptr);

/// Free a renderer handle.
///
/// # Safety
/// `ptr` must be a valid pointer returned by `ruffle_renderer_create`.
void ruffle_renderer_free(RuffleRenderer *ptr);

/// Create a wgpu RenderBackend from the renderer's descriptors.
/// This is used internally to wire up the renderer to the Player.
///
/// # Safety
/// `ptr` must be a valid renderer handle.
void *ruffle_renderer_create_backend(const RuffleRenderer *ptr);

}  // extern "C"
