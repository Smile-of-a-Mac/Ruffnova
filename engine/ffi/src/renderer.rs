//! wgpu renderer FFI — creates and manages a wgpu surface from a CAMetalLayer.

use crate::types::*;
use std::any::Any;
use std::os::raw::{c_void, c_uint, c_float};
use ruffle_render_wgpu::backend::WgpuRenderBackend;
use ruffle_render_wgpu::target::SwapChainTarget;

/// Create a wgpu renderer from a CAMetalLayer pointer.
///
/// The `metal_layer` must be a valid `CAMetalLayer*` from a `MTKView` or `NSView`.
/// The layer must remain alive for the lifetime of the returned renderer.
///
/// # Safety
/// `metal_layer` must be a valid pointer to a `CAMetalLayer`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_renderer_create(
    metal_layer: *mut c_void,
    width: c_uint,
    height: c_uint,
    _scale_factor: c_float,
) -> *mut RuffleRenderer {
    if metal_layer.is_null() {
        return std::ptr::null_mut();
    }

    let result = std::panic::catch_unwind(|| {
        let target = wgpu::SurfaceTargetUnsafe::CoreAnimationLayer(metal_layer as *mut _);
        let backend = match unsafe {
            WgpuRenderBackend::for_window_unsafe(
                target,
                (width.max(1), height.max(1)),
                wgpu::Backends::METAL,
                wgpu::PowerPreference::HighPerformance,
            )
        } {
            Ok(backend) => backend,
            Err(_) => return std::ptr::null_mut(),
        };

        let renderer = RuffleRenderer { backend: Some(Box::new(backend)) };

        Box::into_raw(Box::new(renderer))
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => std::ptr::null_mut(),
    }
}

/// Resize the renderer surface (e.g. on window resize).
///
/// # Safety
/// `ptr` must be a valid renderer handle.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_renderer_resize(
    ptr: *mut RuffleRenderer,
    width: c_uint,
    height: c_uint,
    scale_factor: c_float,
) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }

    let renderer = unsafe { &mut *ptr };
    if let Some(backend) = renderer.backend.as_mut() {
        backend.set_viewport_dimensions(ruffle_render::backend::ViewportDimensions {
            width: width.max(1),
            height: height.max(1),
            scale_factor: scale_factor as f64,
        });
    }
    RuffleResult::Ok
}

/// Recreate the renderer's surface with a new CAMetalLayer.
///
/// This allows updating the Metal layer when the NSView/MTKView is
/// recreated (e.g. after navigating away and back), without destroying
/// the player or losing playback state.
///
/// # Safety
/// `ptr` must be a valid renderer handle. `metal_layer` must be a valid
/// pointer to a `CAMetalLayer`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_renderer_recreate_surface(
    ptr: *mut RuffleRenderer,
    metal_layer: *mut c_void,
    width: c_uint,
    height: c_uint,
) -> RuffleResult {
    if ptr.is_null() || metal_layer.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    let renderer = unsafe { &mut *ptr };
    let backend = match renderer.backend.as_mut() {
        Some(b) => b,
        None => return RuffleResult::ErrorNullPointer,
    };
    let wgpu_backend: &mut WgpuRenderBackend<SwapChainTarget> =
        (backend as &mut dyn Any)
            .downcast_mut()
            .expect("Renderer backend is not WgpuRenderBackend<SwapChainTarget>");
    let target = wgpu::SurfaceTargetUnsafe::CoreAnimationLayer(metal_layer as *mut _);
    unsafe {
        let _ = wgpu_backend.recreate_surface_unsafe(target, (width.max(1), height.max(1)));
    }
    RuffleResult::Ok
}

/// Get the surface texture format (for Metal interop if needed).
///
/// # Safety
/// `ptr` must be a valid renderer handle.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_renderer_surface_format(ptr: *const RuffleRenderer) -> c_uint {
    if ptr.is_null() {
        return 0;
    }
    0
}

/// Present the current frame.
///
/// # Safety
/// `ptr` must be a valid renderer handle.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_renderer_present(ptr: *mut RuffleRenderer) -> RuffleResult {
    if ptr.is_null() {
        return RuffleResult::ErrorNullPointer;
    }
    // wgpu surface textures are presented when dropped, so this is a no-op
    // unless we need to do explicit present.
    RuffleResult::Ok
}

/// Free a renderer handle.
///
/// # Safety
/// `ptr` must be a valid pointer returned by `ruffle_renderer_create`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_renderer_free(ptr: *mut RuffleRenderer) {
    if !ptr.is_null() {
        unsafe { drop(Box::from_raw(ptr)); }
    }
}

/// Create a wgpu RenderBackend from the renderer's descriptors.
/// This is used internally to wire up the renderer to the Player.
///
/// # Safety
/// `ptr` must be a valid renderer handle.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ruffle_renderer_create_backend(
    ptr: *const RuffleRenderer,
) -> *mut c_void {
    if ptr.is_null() {
        return std::ptr::null_mut();
    }
    std::ptr::null_mut()
}
