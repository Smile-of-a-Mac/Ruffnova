#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdbool.h>

typedef struct RufflePlayer RufflePlayer;
typedef struct RuffleRenderer RuffleRenderer;

typedef int RuffleResult;

#define RUFFLE_RESULT_OK                         0
#define RUFFLE_RESULT_ERROR_NULL_POINTER        -1
#define RUFFLE_RESULT_ERROR_LOCK_POISONED       -2
#define RUFFLE_RESULT_ERROR_INVALID_ARGUMENT    -3
#define RUFFLE_RESULT_ERROR_RENDERER_INIT       -4
#define RUFFLE_RESULT_ERROR_LOAD_FAILED         -5

typedef struct {
    unsigned int width;
    unsigned int height;
    float scale_factor;
    int quality;
    bool autoplay;
    float max_execution_secs;
} RuffleConfig;

typedef struct {
    unsigned int key_code;
    unsigned int char_code;
    bool is_down;
    unsigned int modifiers;
} RuffleKeyEvent;

typedef struct {
    float x;
    float y;
    int event_type;
    float scroll_delta;
} RuffleMouseEvent;

typedef struct {
    unsigned char swf_version;
    unsigned char player_version;
    bool is_action_script_3;
    float frame_rate;
    unsigned int movie_width;
    unsigned int movie_height;
    unsigned int total_frames;
    bool uses_avm2;
    unsigned int background_color;
} RuffleMetadata;

typedef struct {
    unsigned int current_frame;
    unsigned int total_frames;
    float frame_rate;
    float elapsed_time_secs;
    bool is_playing;
    bool is_looping;
    float speed_multiplier;
} RufflePlaybackInfo;

typedef enum {
    RuffleScaleMode_ShowAll = 0,
    RuffleScaleMode_NoScale = 1,
    RuffleScaleMode_ExactFit = 2,
    RuffleScaleMode_NoBorder = 3,
} RuffleScaleMode;

typedef enum {
    RuffleLetterbox_Off = 0,
    RuffleLetterbox_Fullscreen = 1,
    RuffleLetterbox_On = 2,
} RuffleLetterbox;

typedef struct {
    char *data;
    unsigned int len;
} RuffleString;

// ─── Phase 1: Functions ───────────────────────────────────────────────────────

RuffleResult ruffle_player_get_playback_info(const RufflePlayer*, RufflePlaybackInfo*);
RuffleResult ruffle_player_get_metadata(RufflePlayer*, RuffleMetadata*);
RuffleResult ruffle_player_seek_frame(RufflePlayer*, unsigned int frame);
RuffleResult ruffle_player_seek_time(RufflePlayer*, float seconds);
RuffleResult ruffle_player_step_back(RufflePlayer*, unsigned int frames);
RuffleResult ruffle_player_rewind(RufflePlayer*);
RuffleResult ruffle_player_set_looping(RufflePlayer*, bool looping);
RuffleResult ruffle_player_set_speed(RufflePlayer*, float speed);
RuffleResult ruffle_player_set_scale_mode(RufflePlayer*, RuffleScaleMode);
RuffleResult ruffle_player_set_letterbox_mode(RufflePlayer*, RuffleLetterbox);
RuffleResult ruffle_player_set_quality(RufflePlayer*, int quality);
RuffleResult ruffle_player_recreate_surface(RufflePlayer*, void *metal_layer, unsigned int width, unsigned int height);

RufflePlayer *ruffle_player_create(RuffleConfig config);
RufflePlayer *ruffle_player_create_with_renderer(RuffleConfig config, RuffleRenderer *renderer);
void ruffle_player_free(RufflePlayer *ptr);
RuffleResult ruffle_player_load_url(RufflePlayer *ptr, const char *url);
RuffleResult ruffle_player_load_data(RufflePlayer *ptr, const uint8_t *data, unsigned int len);
RuffleResult ruffle_player_load_data_with_url(RufflePlayer *ptr, const uint8_t *data, unsigned int len, const char *url);
RuffleResult ruffle_player_tick(RufflePlayer *ptr, float dt);
RuffleResult ruffle_player_render(RufflePlayer *ptr);
RuffleResult ruffle_player_set_playing(RufflePlayer *ptr, bool playing);
bool ruffle_player_is_playing(const RufflePlayer *ptr);
RuffleResult ruffle_player_set_volume(RufflePlayer *ptr, float volume);
float ruffle_player_get_volume(const RufflePlayer *ptr);
RuffleResult ruffle_player_key_event(RufflePlayer *ptr, RuffleKeyEvent event);
RuffleResult ruffle_player_mouse_event(RufflePlayer *ptr, RuffleMouseEvent event);
RuffleResult ruffle_player_set_viewport(RufflePlayer *ptr, unsigned int width, unsigned int height, float scale_factor);
RuffleResult ruffle_player_set_fullscreen(RufflePlayer *ptr, bool fullscreen);
unsigned int ruffle_player_stage_width(const RufflePlayer *ptr);
unsigned int ruffle_player_stage_height(const RufflePlayer *ptr);
void ruffle_string_free(RuffleString s);

RuffleRenderer *ruffle_renderer_create(void *metal_layer, unsigned int width, unsigned int height, float scale_factor);
RuffleResult ruffle_renderer_recreate_surface(RuffleRenderer *ptr, void *metal_layer, unsigned int width, unsigned int height);
RuffleResult ruffle_renderer_resize(RuffleRenderer *ptr, unsigned int width, unsigned int height, float scale_factor);
unsigned int ruffle_renderer_surface_format(const RuffleRenderer *ptr);
RuffleResult ruffle_renderer_present(RuffleRenderer *ptr);
void ruffle_renderer_free(RuffleRenderer *ptr);
void *ruffle_renderer_create_backend(const RuffleRenderer *ptr);
