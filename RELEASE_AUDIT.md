# 🏁 Release Audit Report — Swuffle (Ruffle Native macOS)

**Audit Date:** 2026-06-28  
**Auditor:** Release Review Board (Independent QA)  
**Target:** Mac App Store Submission  
**Application:** Swuffle (Ruffle Native macOS)  
**Version:** 1.0 (Build 1)  
**Files Audited:** 23/23 Swift source files + entitlements + Info.plist + Package.swift + FFI headers  

---

## ⛔ RELEASE DECISION: NO

**Apple would NOT approve this build.**

This application fails at least 5 hard App Store rejection criteria, has 3 completely non-functional feature categories (ZIP import, Settings-to-player bridge, persistent library), and numerous HIG violations. The build cannot be submitted in its current state without guaranteed rejection.

---

## Executive Summary

After exhaustive review of all 23 Swift source files, configuration files, FFI headers, localization resources, and entitlements, **the application is NOT ready for release**. 

The most severe problems are:

1. **Missing App Sandbox entitlement** — hard App Store rejection
2. **Settings are disconnected from the player** — UI exists but has zero effect
3. **Library/Favorites/Collections are lost on every restart** — no persistence
4. **Loading indicator never shows** — `isLoading` flickers for <1ms
5. **ZIP import is a no-op** — UX is actively misleading
6. **`@unchecked Sendable` without synchronization** — data race in render loop
7. **Multiple fake features** — Collections, Downloads, SWFInfo, TraceConsole

---

# Pass 1 — Product Architecture

## P1.1 — Does every feature have a complete workflow?

### ❌ Favorites workflow is broken

| Field | Value |
|---|---|
| **Severity** | Critical |
| **Confidence** | 100% |

**Evidence:** `toggleFavorite(for:)` adds a URL to `AppState.bookmarks`, which is an in-memory `[URL]` array. `BookmarkManager` has proper persistence logic (`bookmarks.json` in Application Support), but it is **never wired to AppState**. `AppState` instantiates `BookmarkManager()` but never reads from it or writes to it.

```swift
// AppState.swift Line ~73
let bookmarkManager = BookmarkManager()  // Instantiated but NEVER USED

// AppState.swift Line ~754  
func toggleFavorite(for url: URL) {
    if bookmarks.contains(url) {           // Uses AppState.bookmarks (in-memory)
        bookmarks.removeAll { $0 == url }
    } else {
        bookmarks.insert(url, at: 0)
    }
}
```

**Impact:** Users lose all favorites on every quit. The "Favorites" sidebar section is empty after restart. Users will believe the feature is broken.

**Root Cause:** `BookmarkManager` was implemented as a standalone persistence layer but never integrated with `AppState`. Two separate `bookmarks` data structures exist with no sync.

---

### ❌ Collections workflow is a dead end

| Field | Value |
|---|---|
| **Severity** | High |
| **Confidence** | 100% |

**Evidence:** `FlashCollection` has `createCollection`, `addToCollection`, and `removeFromCollection` methods in `AppState`. But:
1. There is **no UI to create a collection** — no button, no menu item, no context menu
2. There is **no UI to add files to a collection**
3. There is **no UI to view collection contents** beyond an empty state view in `LibraryContentView`
4. Collections are **never persisted** — `FlashCollection` is `Codable` but never encoded/decoded

**Impact:** The Collections sidebar section shows "No Collections. Organize your files into collections." with no way to actually create one. This is a dead-end feature.

**Root Cause:** Backend data model was built before the UI. The UI was never completed.

---

### ❌ "Downloads" section is permanently empty

| Field | Value |
|---|---|
| **Severity** | Medium |
| **Confidence** | 100% |

**Evidence:** `LibraryContentView.swift` Line ~15:
```swift
case .downloads:
    emptySection("square.and.arrow.down", "Downloads", "Downloaded content will appear here.")
```

There is **no download functionality anywhere in the application**. No URL input field, no network download capability beyond the FFI `loadURL` for SWF playback (which never saves files locally). This section can never be populated.

---

### ❌ SWFInfo panel has no visible invocation

| Field | Value |
|---|---|
| **Severity** | Medium |
| **Confidence** | 100% |

**Evidence:** `SWFInfoPanel` exists but is **never integrated into any view hierarchy**. `RuffleCommands` has a menu item that posts `.toggleSWFInfo` notification, but **no view listens to this notification**. The panel is defined but orphaned.

---

### ❌ TraceConsole has no visible invocation

| Field | Value |
|---|---|
| **Severity** | Medium |
| **Confidence** | 100% |

**Evidence:** Same pattern as SWFInfo — `TraceConsoleView` exists, `.toggleTraceConsole` notification is posted from menu, but **no view subscribes**. `TraceConsole.shared.append()` is **never called** anywhere in the codebase.

---

### ❌ `browseDirectory` adds files but never opens them

| Field | Value |
|---|---|
| **Severity** | High |
| **Confidence** | 100% |

**Evidence:** `browseDirectory(_:)` in `AppState` scans a folder for SWF files and adds them to `recentFiles`. It does NOT open any of them for playback. The user sees files appear in the library but the player remains on the empty state.

---

### ❌ `openFile` immediately resets `isLoading` (already documented as C4 in previous audit)

**Status:** UNRESOLVED. Still present in code.

---

### ✅ Can every created object later be edited?
- Collections: Can be created (programmatically, no UI), but cannot be renamed or edited → **FAIL**
- Favorites: Can be toggled, no metadata editing → **PASS for intended scope**
- Recent files: No editing capability, which is appropriate → **PASS**

### ✅ Can every object later be deleted?
- Favorites: `bookmarks.removeAll` exists but deletes ALL → **PARTIAL** (no individual delete UI)
- Collections: No delete method exists at all → **FAIL**
- Recent files: Only "Clear Menu" in File menu → **PARTIAL** (no individual removal)

### ✅ Are there dead ends?
- **YES:** Collections → empty state with no creation UI
- **YES:** Downloads → permanently empty
- **YES:** SWFInfo → no way to open it
- **YES:** TraceConsole → no way to open it

### ✅ Can users become trapped?
- **Potential:** If user navigates to Settings while playing, the player pauses (`.onChange(of: selectedSection)` in ContentView). If they don't realize this, they may think playback stopped unexpectedly.

---

# Pass 2 — Human Interface Review

## P2.1 — Navigation

| Issue | Severity | Detail |
|---|---|---|
| Sidebar toggle icon doesn't change | Low | `sidebarToggle` always shows `sidebar.left` regardless of collapsed state |
| No back/forward navigation | Medium | No way to return to previous section without clicking sidebar |
| Sidebar section changes pause playback | Medium | `.onChange(of: selectedSection)` always pauses if not `.library` — even if user just wants to check favorites briefly |

## P2.2 — Toolbar

| Issue | Severity | Detail |
|---|---|---|
| Search bar has no placeholder text | Low | `TextField("Search", ...)` — "Search" appears as placeholder but localized string is missing |
| Import menu "+" icon is ambiguous | Medium | "+" conventionally means "new document", not "import file" |
| Settings gear in toolbar is redundant | Low | Also accessible via ⌘, / sidebar / menu |

## P2.3 — Window Hierarchy

| Issue | Severity | Detail |
|---|---|---|
| No NSDocument architecture | Critical | App doesn't use `NSDocument`/`NSDocumentController`. Each SWF should be a document with its own window. |
| `applicationShouldTerminateAfterLastWindowClosed` = true | Medium | Quits when window closes. macOS convention is to keep running for document-based apps. Contradicts `.isRestorable = true` |
| `.hiddenTitleBar` with `.fullSizeContentView` | High | Removing all window chrome is an iOS pattern. macOS users expect a title bar with document title. This violates macOS HIG explicitly. |
| No proxy icon in title bar | Medium | macOS document apps show a proxy icon next to the title for drag-and-drop |
| About window is a modal | Medium | `NSApp.runModal(for:)` blocks the entire application. macOS convention is a non-modal About panel. |

## P2.4 — Spacing & Typography

| Issue | Severity | Detail |
|---|---|---|
| SF Pro Rounded not in font stack | Low | Comment says "SF Pro exclusively" but doesn't include rounded variant |
| Monospaced font for time display | Medium | `glassMono` uses `.monospaced` design — time displays in Finder use proportional digits |
| No Dynamic Type support | High | `Font.system(size: N)` hardcodes sizes. No `@ScaledMetric` usage. Accessibility users cannot resize text. |

## P2.5 — Context Menus

**MISSING ENTIRELY.** No right-click context menus on:
- Library file cells
- Recent file items  
- Favorite items
- Collection items
- Player stage

Every macOS app should have context menus. This is a significant HIG violation.

## P2.6 — Does this feel like Finder/Preview/Photos?

**NO.** It feels like an iOS app ported to macOS:

- Hidden title bar with no window chrome → iOS pattern
- Single-window with sidebar → iOS/iPadOS pattern  
- Haptic feedback on sidebar clicks → iOS pattern (`UIImpactFeedbackGenerator` equivalent)
- No document model → not how macOS handles files
- Glass morphism everywhere → not Apple's macOS design language (which uses subtle materials, not heavy translucency)

## P2.7 — Apple HIG Violations Summary

1. **Hidden title bar** (`windowStyle(.hiddenTitleBar)`) — violates "Windows" guideline: "Always display a title bar."
2. **No document architecture** — SWF files should use NSDocument
3. **About modal blocks app** — should be non-modal panel
4. **No context menus** — violates "Menus" guideline
5. **No Dynamic Type** — violates accessibility requirements
6. **No Touch Bar support** — not required but expected for media apps
7. **No Dock menu** — media players should have play/pause in Dock menu
8. **No Quick Look support** — SWF files should have Quick Look previews
9. **No Open Recent integration** — `NSDocumentController` would provide this free
10. **Import menu uses "+" icon** — "+" means "new", not "import" per HIG

---

# Pass 3 — Runtime State Machine

## States Identified

| State | Entry | Exit | Recovery |
|---|---|---|---|
| **Idle** (no file loaded) | App launch, `closeFile()` | `openFile()` | N/A |
| **Loading** | `openFile()` sets `isLoading=true` | Immediately set to `false` (BUG) | Timeout exists but broken |
| **Playing** | `afterMovieLoaded()` → `setPlaying(true)` | `togglePlayPause()`, `pausePlayback()` | N/A |
| **Paused** | `togglePlayPause()`, sidebar navigation | `togglePlayPause()` | N/A |
| **Error** | `startLoadTimeout()` fires | `errorMessage = nil` | No retry mechanism |
| **Searching** | Search bar text non-empty | Clear search | N/A |
| **Settings** | `selectedSection = .settings` | Any other section | Playback pauses (side effect) |
| **Fullscreen** | `toggleFullscreen()` | `toggleFullscreen()` or ESC | Window state can desync |
| **Importing** | NSOpenPanel shown | User selects/cancels | Sandbox may block |

## Critical State Machine Issues

### SM-1: Loading state is invisible
`isLoading` is set to `true` and immediately back to `false` in the same synchronous call. The Loading overlay never renders. The timeout is cancelled before it can fire.

### SM-2: Fullscreen state desync
```swift
func toggleFullscreen() {
    isFullscreen.toggle()
    bridge?.setFullscreen(isFullscreen)
    if let window = NSApp.keyWindow {
        window.toggleFullScreen(nil)   // Animates — callbacks asynchronous
    }
}
```
`isFullscreen` is toggled BEFORE `window.toggleFullScreen` completes. If the user presses ESC (which triggers native fullscreen exit), `isFullscreen` remains `true`. The bridge FFI and SwiftUI state are desynchronized.

### SM-3: Playing state doesn't reflect actual player state
`isPlaying` is set optimistically in `togglePlayPause()` and `afterMovieLoaded()`, but only synced from the bridge in `syncPlayingState()`. If the SWF auto-stops (end of timeline, no loop), `isPlaying` stays `true` while the bridge has stopped. `pollPlaybackInfo()` doesn't update `isPlaying`.

### SM-4: Impossible state: `isPlayerVisible` without bridge
If `currentFileURL != nil && selectedSection == .library` but the bridge hasn't initialized yet (race between `RufflePlayerView` appearance and `AppState`), the player view renders with no bridge. This happens on first launch with a pending file.

### SM-5: Sidebar navigation during fullscreen
No guard prevents navigating to Settings while in fullscreen. The player view is replaced with settings inline, but the window is still in macOS native fullscreen space.

---

# Pass 4 — Exploratory QA

| Attack | Expected Result | Actual Result |
|---|---|---|
| Double-click file cell rapidly | Opens twice | `openFile` called twice — second call resets the first silently |
| Rapid sidebar toggle | Smooth animation | Animation may stutter — no debounce |
| Drag non-SWF, non-ZIP, non-folder | Rejected | `handleDrop` silently ignores. No error feedback. |
| Drag 100+ SWF files | All added to library | O(n²) check: `.contains(where:)` on every insert — UI may freeze |
| Open file, ⌘W, reopen same file | File reopens | Bridge may hold stale reference to old MetalLayer (see `viewDidMoveToWindow` sets `bridgeInitialized = false`) |
| ⌘Q while "loading" | App quits | `isLoading` already `false` — no data loss but no cleanup |
| Resize window during fullscreen animation | Crash or visual glitch | No guard against resize during `toggleFullScreen` animation |
| Open two windows (if possible) | Second window works | App likely prevents this with default WindowGroup behavior, but untested |
| Change language while playing | UI updates, playback continues | LocalizationManager posts `objectWillChange` but ContentView may not re-render toolbar labels |

---

# Pass 5 — Persistence

## What survives restart?

| State | Persisted? | Mechanism |
|---|---|---|
| `volume` | YES | `SettingsPersistence` → UserDefaults |
| `isMuted` | YES | `SettingsPersistence` → UserDefaults |
| `isLooping` | YES | `SettingsPersistence` → UserDefaults |
| `playbackSpeed` | YES | `SettingsPersistence` → UserDefaults |
| `quality` | YES | `SettingsPersistence` → UserDefaults |
| `showDebugUI` | YES | `SettingsPersistence` → UserDefaults |
| `showToolbar` | YES | `SettingsPersistence` → UserDefaults |
| `maxExecutionDuration` | YES | `SettingsPersistence` → UserDefaults |
| `selectedLanguage` | YES | `LocalizationManager` → UserDefaults |
| `recentFiles` | **NO** | In-memory only |
| `bookmarks` (favorites) | **NO** | In-memory only (`BookmarkManager` has persistence but is disconnected) |
| `collections` | **NO** | In-memory only |
| `currentFileURL` | **NO** | In-memory only |
| `selectedSection` | **NO** | In-memory only |
| `sidebarCollapsed` | **NO** | In-memory only |
| `autoplay` | YES | `@AppStorage` in InlineSettingsView |

## Persistence Issues

### PERS-1: Two competing persistence systems
`SettingsPersistence` uses raw UserDefaults keys (prefixed `ruffle.`). `InlineSettingsView` and `SettingsView` use `@AppStorage` with unprefixed keys (`"autoplay"`, `"letterbox"`, `"graphicsBackend"`, `"networkAccess"`, `"filesystemAccess"`, `"maxExecutionDuration"`). These are **different keys** — `SettingsPersistence.maxExecutionDuration` reads `"ruffle.maxExecutionDuration"` but `@AppStorage("maxExecutionDuration")` reads `"maxExecutionDuration"`. Two copies of the same settings exist independently.

### PERS-2: Settings reset doesn't clear @AppStorage
`SettingsPersistence.resetAll()` clears `ruffle.*` keys but NOT the `@AppStorage` keys. Inconsistent reset behavior.

### PERS-3: No sandbox bookmark persistence
`BookmarkManager` stores raw URLs, not security-scoped bookmarks. Under App Sandbox, raw URLs expire after app restart. Security-scoped bookmarks (`URL.bookmarkData()`) are required.

### PERS-4: `window.isRestorable = true` but no encodeRestorableState
`ImmersiveWindowConfigurator` sets `window.isRestorable = true` but `AppDelegate` doesn't implement `NSWindowRestoration` protocol. Window position/size is not actually restored.

---

# Pass 6 — Performance

### PERF-1: Main-thread FFI calls in render loop
`RufflePlayerView.updateViewport()` posts `.viewportChanged` notification, which triggers `bridge?.setViewport()` from the main thread. This calls `ruffle_player_set_viewport` and `ruffle_renderer_resize` — potentially expensive Metal operations on the main thread.

### PERF-2: O(n²) in `browseDirectory`
```swift
if !recentFiles.contains(where: { $0.url == fileURL }) {
    recentFiles.append(recentFile)
}
```
`contains(where:)` scans the entire array for each file. With 1000 files, this is 500k comparisons.

### PERF-3: Double timer overhead
Both `displayTimer` (60fps in RuffleBridge) and `timelinePollTimer` (4Hz in AppState) run simultaneously. The timeline poll could use the `onFrameUpdate` callback instead.

### PERF-4: `mach_absolute_time()` on Timer thread
`renderFrame()` calls `mach_absolute_time()` on every frame via a `Timer` (not a `CADisplayLink`). This means rendering is not synchronized with display refresh, causing potential tearing.

### PERF-5: Screenshot reads GPU memory synchronously
```swift
texture.getBytes(&pixelData, ...)  // Blocks CPU waiting for GPU
```
This stalls the main thread while the GPU finishes rendering. For large textures (Retina displays), this can take 10-50ms.

### PERF-6: No memory limit on recentFiles
`recentFiles` has a cap of 20 but `browseDirectory` bypasses this cap — it appends without checking the limit.

### PERF-7: CAMetalLayer retained across view lifecycle
When `viewDidMoveToWindow` sets `bridgeInitialized = false` and window is nil, the old `CAMetalLayer` is not explicitly released. The bridge's deinit will free it, but there's a window where two MetalLayers might exist.

---

# Pass 7 — Native macOS Review

## App Sandbox

| Requirement | Status |
|---|---|
| `com.apple.security.app-sandbox` = true | **MISSING** |
| Security-scoped bookmarks | **MISSING** (raw URLs used) |
| Entitlements for file access | Partial: read-only for user-selected and downloads only |

## Hardened Runtime

| Requirement | Status |
|---|---|
| Hardened Runtime enabled | Unknown (not in entitlements, possibly in Xcode build settings) |
| `com.apple.security.cs.disable-library-validation` | Not present — may need for FFI dylib |

## App Lifecycle

| Requirement | Status |
|---|---|
| `applicationWillFinishLaunching` | **NOT IMPLEMENTED** |
| `applicationWillTerminate` | **NOT IMPLEMENTED** — no cleanup/state save |
| `applicationShouldSaveApplicationState` | **NOT IMPLEMENTED** |
| `applicationShouldEncodeApplicationState` | **NOT IMPLEMENTED** |
| NSApplicationDelegate adoption | Partial — only 3 methods implemented |

## Document Architecture

**COMPLETELY MISSING.** An SWF player should use `NSDocument`:
- Each SWF = one document
- `NSDocumentController` manages Open Recent
- Proxy icon in title bar
- "Edited" state tracking
- Autosave
- Versions support

## Missing Integrations

| Feature | Status |
|---|---|
| Dock Menu | **MISSING** |
| Quick Look (`QLPreviewingController`) | **MISSING** |
| Spotlight importer | **MISSING** |
| Open Recent (NSDocumentController) | Custom implementation (fragile) |
| NSUserActivity (Handoff) | **MISSING** |
| Touch Bar (`NSTouchBarProvider`) | **MISSING** |
| Services menu | **MISSING** |
| Apple Events (`open`, `print`, `quit`) | Partial — only `open` via `application(_:open:)` |
| Scripting Bridge / AppleScript | **MISSING** |
| Drag & Drop (export/drag-out) | **MISSING** — can drop in, can't drag out |
| Stage Manager | Unknown — no testing |
| Multiple Displays | Fullscreen uses `keyWindow?.toggleFullScreen` — may go to wrong display |
| Mission Control / Spaces | No space-switching handling |

## Accessibility

| Requirement | Status |
|---|---|
| VoiceOver labels | Minimal: only sidebar rows have `.accessibilityLabel` |
| Accessibility traits | Minimal: only sidebar rows |
| `accessibilityElementCount()` | **NOT IMPLEMENTED** |
| `isAccessibilityElement` overrides | **NOT IMPLEMENTED** |
| Custom rotor support | **NOT IMPLEMENTED** |
| Reduce Motion | **NOT RESPECTED** — `glassSpring` animations bypass `UIAccessibility.isReduceMotionEnabled` equivalent |
| Reduce Transparency | **NOT RESPECTED** — glass effects everywhere |
| High Contrast | **NOT RESPECTED** |
| Dynamic Type | **NOT SUPPORTED** — all font sizes hardcoded |
| Keyboard navigation | Partial: sidebar, menu commands. No Tab key navigation between controls. |
| Full Keyboard Access | Not tested — likely broken without proper `NSView.focusRingType` |

---

# Pass 8 — Failure Injection

| Failure | Current Behavior | Required Behavior |
|---|---|---|
| FFI dylib missing at launch | Mock mode — runs but no rendering | Should show clear error: "Ruffle engine not installed" |
| Metal device unavailable | `MTLCreateSystemDefaultDevice()` returns nil → force unwrap crash | Graceful fallback or error |
| Corrupt SWF loaded | `ruffle_player_load_url` returns error code, logged but not shown to user | User-visible error with retry option |
| Load timeout (15s) | Sets `errorMessage` — but `isLoading` is already false, so overlay never showed | Loading overlay must be visible for the full 15s |
| Disk full during screenshot save | `try? png.write(to:)` silently fails | Error message to user |
| Permission denied (sandbox) | `openFile` silently fails — `errorMessage` stays nil | Permissions error shown |
| Invalid UTF-8 in SWF URL | `url.absoluteString.withCString` — may produce garbled C string | URL encoding validation |
| `ruffle_renderer_create` returns nil | `RuffleBridge.init?` returns nil — AppState gets nil bridge | No user-visible error. App appears empty. |
| NSOpenPanel cancelled | `panel.runModal() != .OK` — nothing happens | Correct, but no distinction from error |
| Bookmark data corrupted | `JSONDecoder.decode` throws → `bookmarks = []` silent | Should notify or migrate |
| Window closed during loading | `viewDidMoveToWindow` sets `bridgeInitialized = false` | Old bridge dealloc'd, new bridge created on open. Could leak Metal resources. |
| Multiple rapid ⌘O | Multiple NSOpenPanel can stack | macOS handles this natively (only one modal at a time) |
| GPU restart (eGPU disconnect) | `currentDrawable` becomes nil, `renderFrame` silently no-ops | Should detect and recreate renderer |

### FAIL-1: Metal device nil is a crash
```swift
init() {
    super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
    // If this returns nil (VM, recovery mode, future Mac without Metal),
    // MTKView init crashes.
}
```
No guard against unavailable Metal. This is a hard blocker for App Store — the app must gracefully handle Metal unavailability.

---

# Pass 9 — Code Architecture

## ARC-1: Duplicate settings systems
Three separate settings storage mechanisms coexist:
1. `SettingsPersistence` (raw UserDefaults, `ruffle.*` keys)
2. `@AppStorage` in `InlineSettingsView`/`SettingsView` (unprefixed keys)
3. `@Published` properties in `AppState` synced via Combine to `SettingsPersistence`

These systems have **different key namespaces** and **different defaults**. `SettingsPersistence.volume` defaults to `1.0` (via fallback), but `@AppStorage("volume")` doesn't exist — there's no second copy for volume, but the pattern is inconsistent.

## ARC-2: God object — `AppState`
`AppState` is 500+ lines and manages:
- Player state (play/pause/volume/fullscreen)
- Navigation (selectedSection, sidebarCollapsed)
- Library (recentFiles, bookmarks, collections)
- Settings (quality, language, debugUI)
- Timeline (currentFrame, totalFrames, frameRate)
- Search (searchText, isSearching, searchResults)
- Bridge lifecycle
- Screenshot logic
- File browsing
- Notification handling
- Timeout management

This violates Single Responsibility Principle. It should be split into:
- `PlayerState` (playback, timeline, bridge)
- `LibraryState` (recent files, bookmarks, collections, search)
- `NavigationState` (routes, sidebar)
- `SettingsState` (preferences)

## ARC-3: Orphaned BookmarkManager
`AppState` creates a `BookmarkManager` instance but never reads from it or writes to it. The manager has full CRUD with JSON persistence but is dead code in practice.

## ARC-4: Two divergent Settings views
`InlineSettingsView` (in `ContentView.swift`) and `SettingsView` (in `SettingsView.swift`) are **near-duplicates** with identical form layouts, identical `@AppStorage` bindings. They differ only in layout structure (one uses helper functions, one is inline). Any change must be made in two places.

## ARC-5: `@unchecked Sendable` without synchronization
`RuffleBridge` is `@unchecked Sendable` but:
- `renderFrame()` runs on Timer thread
- `loadURL()`, `setPlaying()` etc. can be called from main thread
- `playerPointer` and `rendererPointer` are read/written without locks
- `mockIsPlaying`, `mockVolume` same issue
- `playbackSpeed`, `loopFlag` same issue

This is a data race. The `@unchecked Sendable` annotation is an assertion that the developer has ensured thread safety, but no synchronization exists.

## ARC-6: Tight coupling via EnvironmentObject
Every view depends on `@EnvironmentObject var appState: AppState`. This means:
- Any view can modify any state
- No compile-time guarantees about which state a view needs
- Testing individual views requires constructing the entire AppState
- No clear data flow boundaries

## ARC-7: Magic string notifications
```swift
static let openSWFFile = Notification.Name("openSWFFile")
static let viewportChanged = Notification.Name("viewportChanged")
static let keyEvent = Notification.Name("keyEvent")
static let swfLoaded = Notification.Name("swfLoaded")
static let toggleSWFInfo = Notification.Name("toggleSWFInfo")
static let toggleTraceConsole = Notification.Name("toggleTraceConsole")
```
UserInfo keys are also magic strings (`"url"`, `"width"`, `"height"`, `"scaleFactor"`, `"keyCode"`, `"charCode"`, `"isDown"`, `"modifiers"`). No type-safe notification payloads.

## ARC-8: Dead code — `swfLoaded` notification
`.swfLoaded` is defined and posted nowhere except SWFInfoPanel subscribes to it. The notification is never sent.

## ARC-9: `Error` protocol not used
All errors are communicated via `errorMessage: String?`. No Swift `Error` types, no `Result` types, no structured error handling. This prevents:
- Typed error recovery (e.g., `.fileNotFound` vs `.permissionDenied`)
- Error localization
- Error logging with context

---

# Pass 10 — Polish

## P10-1: Logging is inconsistent
- Some use `print("[RuffleBridge] ...")`
- Some use `print("[Swuffle] ...")`
- Some use `print("[AppState] ...")`
- No unified logging (no `os.Logger`, no `OSLog`)
- Debug prints leak into release builds (no `#if DEBUG` guards)

## P10-2: Inconsistent naming
- Product is called "Swuffle" in `Info.plist` (`CFBundleDisplayName`, `CFBundleName`), "Flash Player" in `AboutView`, "Ruffle Flash Player" in `SettingsPersistence` directory, "Ruffle" in `StatusBarView`
- No consistent product identity

## P10-3: Comment quality
- Many "Phase N" markers suggest staged development — but all "phases" are in the same build
- `// Note: Full extraction requires a ZIP library. For now, just notify the user.` — but it doesn't even notify the user properly
- `/// Content is the experience. The interface quietly supports it.` — marketing copy, not documentation

## P10-4: Animation stutter risk
- `glassSpring` animation on `sidebarCollapsed` uses spring physics that can overshoot
- No `NSAnimationContext.runAnimationGroup` for coordinated animations
- `withAnimation` closures may trigger during layout

## P10-5: Icon
- `CFBundleIconName` = `"AppIcon"` but `Assets.xcassets` contents not audited — icon may be placeholder

## P10-6: Missing toolbar items
A media player toolbar should include:
- Play/Pause button (currently only in Control bar overlay)
- Volume slider (currently only in Control bar overlay)  
- Timeline scrubber
- Fullscreen button

---

# Mandatory Deliverables

## Incomplete Features

1. **ZIP import** — Handler exists, extraction is not implemented
2. **Collections** — Data model exists, UI for creation/management does not
3. **Downloads** — Section exists, download capability does not
4. **SWF Info Panel** — View exists, not connected to any trigger
5. **Trace Console** — View exists, logging never feeds it, not connected
6. **Window restoration** — `isRestorable = true` but no encode/decode
7. **Favorites persistence** — `BookmarkManager` disconnected from `AppState`
8. **Open Recent** — Custom implementation, doesn't use NSDocumentController
9. **Screenshot** — BGRA→RGBA swap is suspicious (Metal typically uses BGRA, not RGBA for output)
10. **Loading overlay** — Exists in view hierarchy, never visible due to state bug

## Fake Features (UI exists, does nothing)

1. **Settings → Graphics Backend** — Picker has Metal/Vulkan/Auto, but `graphicsBackend` @AppStorage is never read by any code
2. **Settings → Network Access** — Picker has Allow/Deny/Prompt, never read by bridge or FFI
3. **Settings → File System Access** — Same as above
4. **Settings → Autoplay** — `autoplay` @AppStorage is never read by `afterMovieLoaded()` or bridge init
5. **Settings → Letterbox** — `letterbox` @AppStorage is never applied to `RuffleBridge.setLetterboxMode()`
6. **Settings → Max Execution Duration** — `maxExecutionDuration` @AppStorage is never passed to `RuffleConfig` (which uses hardcoded `15.0`)
7. **Collections sidebar section** — Shows empty state, no creation UI

## Misleading UI

1. **"Your Flash Library" empty state** — Suggests a library system exists. It doesn't persist.
2. **"Import Folder" button** — Imports files to library but doesn't open any. Library doesn't persist.
3. **"+"" button** — Suggests creating something new. Actually imports files.
4. **Search bar with "Search" placeholder** — Searches only `recentFiles` (max 20), not all imported files
5. **"No Collections. Organize your files into collections."** — Impossible to do
6. **"Downloaded content will appear here."** — No download feature exists
7. **Status bar showing file count** — Count resets on restart

## Technical Debt

1. Three competing settings systems (UserDefaults raw, @AppStorage, SettingsPersistence)
2. 500+ line God object (`AppState`)
3. Duplicate Settings views (`InlineSettingsView` and `SettingsView`)
4. Orphaned `BookmarkManager` (full implementation, never used)
5. `@unchecked Sendable` without synchronization — time bomb
6. Magic string notifications instead of typed payloads
7. No structured error handling
8. Debug prints in release code paths
9. "Phase N" comments suggest unfinished staged rollout
10. Two competing naming conventions (`ruffle.*` vs unprefixed UserDefaults keys)

## App Store Rejection Risks

| # | Risk | Certainty |
|---|---|---|
| 1 | **Missing App Sandbox entitlement** | 100% — automatic rejection |
| 2 | **Hidden title bar** violated HIG | 80% — reviewer discretion but likely |
| 3 | **No NSDocument architecture** for file type | 60% — registered as Viewer for .swf but no document model |
| 4 | **Non-functional features** (fake settings, empty sections) | 90% — "app must function as advertised" |
| 5 | **No accessibility support** | 70% — increasingly enforced |
| 6 | **Metal unavailability crash** | 50% — unlikely trigger but zero-tolerance for crashes |
| 7 | **`@unchecked Sendable` data race** | 40% — crashes may manifest in review |
| 8 | **Hardcoded library path in Package.swift** (`/Users/wangdaoyu/...`) | 100% — won't compile on Apple's machines |

## Apple HIG Violations

1. Hidden title bar with fullSizeContentView
2. No document architecture for file-based app
3. No context menus
4. No Dock menu
5. No proxy icon
6. About window blocks app (modal)
7. "+" icon for import (should be "new")
8. No Dynamic Type support
9. No Reduce Motion/Transparency respect
10. iOS-style haptic feedback on macOS

## Accessibility Issues

1. No VoiceOver labels except on sidebar rows
2. No custom accessibility elements for player stage
3. No Reduce Motion support
4. No Reduce Transparency support
5. No Dynamic Type
6. No keyboard navigation for library grid
7. No Full Keyboard Access support
8. Controls auto-hide — invisible to VoiceOver

## Performance Risks

1. Main-thread Metal operations during viewport changes
2. Timer-based rendering instead of CADisplayLink
3. O(n²) file insertion
4. Synchronous GPU read in screenshot
5. No memory limit on `browseDirectory` imports
6. Double timer overhead (display + timeline poll)

## Maintainability Risks

1. God object pattern — any change risks breaking unrelated features
2. No unit tests (none found in codebase)
3. No UI tests
4. No SwiftUI preview data — previews use empty `AppState()`
5. Duplicate settings views
6. Hardcoded file paths in `Package.swift`
7. Magic strings for notifications and UserInfo

## Future Scalability Risks

1. Single-window architecture prevents opening multiple SWFs simultaneously
2. No plugin/extension system for new SWF features
3. `recentFiles` hard-capped at 20
4. No lazy loading of library thumbnails
5. No caching of SWF metadata
6. Fixed 200px sidebar width

## Architectural Inconsistencies

1. Three settings systems with overlapping domains
2. `AppState.bookmarks` vs `BookmarkManager.bookmarks` — two sources of truth
3. `SettingsPersistence` + `@AppStorage` — two key namespaces
4. `InlineSettingsView` vs `SettingsView` — two identical settings UIs
5. `AppState.maxExecutionDuration` (published, synced to SettingsPersistence) vs `@AppStorage("maxExecutionDuration")` (in Settings views) — two separate values
6. Mock mode (#else in RuffleBridge) returns synthetic data that doesn't match real FFI behavior

---

# Product Design Challenges

Per the iron rule — "Never assume the product design is correct":

## Why does this product need Collections?

A Flash player is not a photo library. macOS users organize files in Finder. Adding a parallel organization system (Collections) inside the app creates confusion: which is the source of truth — Finder folders or Collections? A Flash player should mirror the file system, not compete with it. **Recommendation:** Remove Collections. Use Finder folders + file system browsing instead.

## Why does this product need a Library separate from Finder?

The "Library" section duplicates Finder functionality. Users already have their files organized on disk. A "Library" with no persistence is actively harmful — it suggests files are stored in the app when they're not. **Recommendation:** Replace Library with a file browser that mirrors the file system.

## Why "Favorites" instead of Finder tags?

macOS has a system-wide tagging mechanism. Users can tag SWF files in Finder with "Red" or custom tags. Reimplementing Favorites in-app creates a walled garden that doesn't interoperate with the rest of the system. **Recommendation:** Use Finder tags or remove Favorites.

## Why is this a single-window app?

macOS is a multi-window OS. A Flash player should be able to open multiple SWFs in separate windows (like Preview opens multiple images). The current single-window-with-sidebar design is an iOS paradigm forced onto macOS. **Recommendation:** Adopt NSDocument architecture with one window per SWF.

## Why does "Downloads" exist as a section?

There is no download feature. This is a promise to the user that the app cannot fulfill. **Recommendation:** Remove until URL download is implemented, or implement it properly.

## Is the auto-hiding control bar correct for a desktop app?

Auto-hiding UI is a mobile/touch pattern where screen real estate is precious. On macOS, users have large displays and expect persistent controls. Hiding the play/pause/volume controls after 3 seconds makes them undiscoverable and violates the principle of direct manipulation. **Recommendation:** Keep controls visible, or use a toggle (like QuickTime Player's "Show Closed Captioning + Audio Controls" hover).

---

# Release Decision

## ⛔ Would Apple approve this build? **NO**

### Reasons:

1. **App Sandbox missing** — hard rejection, no discretion
2. **Hardcoded local path in Package.swift** — won't compile on Apple's CI
3. **Multiple non-functional features** — App Store Review Guideline 2.1: "Apps that are not fully functional may be rejected"
4. **Hidden title bar with no document title** — HIG violation, reviewer discretion
5. **No accessibility support** — increasingly enforced for new submissions
6. **Settings that don't work** — "app must function as described"

### Even if these were fixed, I remain uncomfortable about:

1. The `@unchecked Sendable` time bomb — data races are Heisenbugs that may pass review but crash in production
2. The God object architecture — any post-launch feature will be expensive and risky
3. The lack of unit tests — regression risk is extremely high
4. The iOS-first design philosophy — users will feel the app "doesn't belong" on macOS
5. The three-way settings system — data corruption risk when settings diverge
6. Mock mode silently returning fake data — could mask real FFI bugs during development
7. No error recovery anywhere — if anything goes wrong, the user's only option is to relaunch
8. `Metal device nil` crash — edge case, but zero-tolerance for crashes in App Store

---

*End of Release Audit. This application must not be submitted to the Mac App Store in its current state.*
- `loadURL()`, `setPlaying()`, `setVolume()`, etc. are called from the main thread
- `playerPointer`, `rendererPointer`, `displayTimer` are accessed from both threads without any locks

**Reason:** `@unchecked Sendable` silences the compiler but doesn't add actual synchronization.

**Impact:** Potential race conditions: reading `playerPointer` while `deinit` frees it, concurrent `ruffle_player_tick` + `ruffle_player_set_playing` calls. Could cause crashes or data corruption.

**Suggested Fix:** Either dispatch all FFI calls through a serial queue, or ensure the Timer fires on the main RunLoop. At minimum, remove `@unchecked Sendable` and add `@MainActor` or use an actor.

---

### H2 — Favorites System Has Two Disconnected Implementations

| Field | Value |
|-------|-------|
| **Location** | `AppState.swift` (`bookmarks: [URL]`), `BookmarkManager.swift` |
| **Severity** | High |
| **Confidence** | 100% |

**Evidence:** `AppState` has `@Published var bookmarks: [URL] = []` for favorites. `BookmarkManager` is a separate class with its own `bookmarks: [Bookmark]` that has persistence, URL resolution, and metadata. `AppState` creates `let bookmarkManager = BookmarkManager()` but **never uses it**. The `toggleFavorite()` method operates on `AppState.bookmarks`, not `bookmarkManager.bookmarks`.

**Reason:** Architectural disconnect — two parallel systems for the same feature.

**Impact:** Favorites never persist. `BookmarkManager` wastes resources loading/saving data that's never used.

**Suggested Fix:** Use `bookmarkManager` as the single source of truth for favorites. Remove `AppState.bookmarks` or delegate to `bookmarkManager`.

---

### H3 — Collections: No Way to Add Files

| Field | Value |
|-------|-------|
| **Location** | `LibraryContentView.swift` (`CollectionsListView`), `AppState.swift` |
| **Severity** | High |
| **Confidence** | 100% |

**Evidence:** The Collections view shows a "+" button to create a collection and a `CollectionRow` that displays file count. However:
- There is no UI to add files to a collection
- `CollectionRow` has no tap action — tapping does nothing
- `addToCollection()` exists in `AppState` but is never called from any view
- Collections are not persisted

**Reason:** Feature was designed but implementation is incomplete.

**Impact:** Users can create empty collections but can never populate them. Dead-end workflow.

**Suggested Fix:** Either implement a file picker / drag-to-collection flow, or hide the Collections section until it's complete.

---

### H4 — Duplicate `maxExecutionDuration` Storage

| Field | Value |
|-------|-------|
| **Location** | `InlineSettingsView.swift`, `SettingsView.swift`, `AppState.swift`, `SettingsPersistence.swift` |
| **Severity** | High |
| **Confidence** | 95% |

**Evidence:** `maxExecutionDuration` is stored in three independent places:
1. `@AppStorage("maxExecutionDuration")` in both settings views
2. `SettingsPersistence.shared.maxExecutionDuration` in `AppState`
3. `AppState.maxExecutionDuration` (published property)

The settings views write to `@AppStorage` but `AppState` reads from `SettingsPersistence`. Changes in the settings UI may not be reflected in the player, depending on timing.

**Reason:** Three independent storage mechanisms for one setting.

**Impact:** Settings may appear to save but not take effect. Inconsistent behavior.

**Suggested Fix:** Use a single source of truth — either `@AppStorage` or `SettingsPersistence`, not both.

---

### H5 — `autoplay` Setting Ignored

| Field | Value |
|-------|-------|
| **Location** | `InlineSettingsView.swift`, `SettingsView.swift`, `AppState.swift` |
| **Severity** | High |
| **Confidence** | 100% |

**Evidence:** Both settings views have `@AppStorage("autoplay") private var autoplay = true`. The toggle is fully functional in the UI. However, `AppState.openFile()` always calls `bridge?.setPlaying(true)` via `afterMovieLoaded()`. The `autoplay` value is never checked.

**Reason:** Missing `if autoplay` guard in `afterMovieLoaded()`.

**Impact:** Users who disable autoplay will still see content auto-play on load.

**Suggested Fix:** Read `UserDefaults.standard.bool(forKey: "autoplay")` in `afterMovieLoaded()` and conditionally set playing state.

---

### H6 — Debug Logging in Production Build

| Field | Value |
|-------|-------|
| **Location** | `RuffleBridge.swift`, `RufflePlayerView.swift` |
| **Severity** | High |
| **Confidence** | 100% |

**Evidence:** Extensive `print()` statements throughout:
```swift
print("[RuffleBridge] frame=\(renderedFrames) dt=\(String(format: "%.4f", dt))...")
print("[Swuffle] mouseDown x=\(Int(location.x)) y=\(Int(location.y))...")
print("[RuffleBridge] loadURL ok url=\(url.absoluteString)")
```

Frame logging fires every 120 frames (~2 seconds at 60fps). Mouse event logging fires on every click.

**Reason:** Development debugging left in source.

**Impact:** Console spam. Performance overhead from string formatting (especially the `String(format:)` call in the display timer). Potential information leakage of file paths.

**Suggested Fix:** Replace with `os_log` or `Logger` at `.debug` level, or use `#if DEBUG` / `#if RUST_FFI_AVAILABLE` guards.

---

### H7 — Typo in Log Prefix

| Field | Value |
|-------|-------|
| **Location** | `RufflePlayerView.swift` |
| **Severity** | High |
| **Confidence** | 100% |

**Evidence:** `print("[Swuffle] mouseDown...")` — "Swuffle" instead of "Ruffle" or "Swuffle" (the app name). This is inconsistent with all other log prefixes which use `[RuffleBridge]`.

**Reason:** Typo during development.

**Impact:** Confusing log output. Minor professionalism concern.

**Suggested Fix:** Change `[Swuffle]` to `[RufflePlayerView]` or the correct app name.

---

## Medium Priority Issues

### M1 — `RuffleMetalView.mouseLocation(from:scale:)` Not Verified

| Field | Value |
|-------|-------|
| **Location** | `RufflePlayerView.swift` |
| **Severity** | Medium |
| **Confidence** | 70% |

**Evidence:** Multiple mouse handlers call `mouseLocation(from: event, scale: scale)` but this method implementation is not visible. macOS uses bottom-left origin for `NSView` while Flash uses top-left origin. The debug log shows `flipped=\(isFlipped)` suggesting this was a known concern.

**Impact:** Mouse click coordinates may be inverted vertically in some SWF content, causing incorrect interactions.

**Suggested Fix:** Verify `isFlipped` is handled correctly in the coordinate transformation. Add unit tests for coordinate mapping.

---

### M2 — About Window Uses Deprecated Modal Pattern

| Field | Value |
|-------|-------|
| **Location** | `RuffleCommands.swift` |
| **Severity** | Medium |
| **Confidence** | 85% |

**Evidence:**
```swift
let window = NSWindow(...)
NSApp.runModal(for: window)
```

Modal windows block the entire app. The window is never explicitly released (no `window.close()` or `NSApp.stopModal()` after dismissal).

**Impact:** If the user closes the About window via the close button, `runModal` returns but the `NSWindow` object may leak. Blocks all other windows while open.

**Suggested Fix:** Use `window.makeKeyAndOrderFront()` instead of `runModal`, or use a SwiftUI `.sheet`.

---

### M3 — `handleDrop` Returns Incorrect Boolean

| Field | Value |
|-------|-------|
| **Location** | `ContentView.swift` |
| **Severity** | Medium |
| **Confidence** | 95% |

**Evidence:**
```swift
private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
    var handled = false
    for p in providers {
        p.loadItem(forTypeIdentifier: ...) { data, _ in
            // ... async work ...
            handled = true  // Sets local variable in closure
        }
    }
    return handled  // Always returns false — closure hasn't fired yet
}
```

**Reason:** `loadItem` is async but `handleDrop` is synchronous.

**Impact:** SwiftUI's `onDrop` may show a rejection animation even though the drop was accepted.

**Suggested Fix:** Return `true` immediately if any provider can handle the type, or use `NSItemProvider.loadDataRepresentation` with async/await.

---

### M4 — Search Bar Width Animation Causes Layout Shift

| Field | Value |
|-------|-------|
| **Location** | `AppToolbar.swift` |
| **Severity** | Medium |
| **Confidence** | 80% |

**Evidence:**
```swift
.frame(width: searchFocused || !appState.searchText.isEmpty ? 180 : 100)
```

The search bar jumps 80px when focused. Combined with the toolbar's `Spacer()` layout, this causes the right-side buttons (import menu, settings) to shift suddenly.

**Impact:** Toolbar buttons jump when clicking search. Not a polished feel.

**Suggested Fix:** Use `.frame(minWidth: 100, maxWidth: 180)` with `layoutPriority` or a fixed toolbar layout.

---

### M5 — DebugOverlayView Shows Wrong Frame Rate

| Field | Value |
|-------|-------|
| **Location** | `DebugOverlayView.swift` |
| **Severity** | Medium |
| **Confidence** | 100% |

**Evidence:**
```swift
Text("FPS: \(String(format: "%.1f", appState.frameRate))  Frame: \(appState.currentFrame)")
```

`appState.frameRate` is the SWF's **configured frame rate** (e.g., 30.0), not the actual rendering FPS. The actual FPS is in `appState.debugFrameRate`.

**Impact:** Debug overlay shows misleading information.

**Suggested Fix:** Change to `appState.debugFrameRate` for the FPS display.

---

### M6 — `getMetadata()` Returns Fake Data

| Field | Value |
|-------|-------|
| **Location** | `RuffleBridge.swift` |
| **Severity** | Medium |
| **Confidence** | 100% |

**Evidence:**
```swift
func getMetadata() -> ... {
    // The FFI doesn't expose full metadata yet, so return best-effort values.
    return (
        swfVersion: 0,      // Always 0
        playerVersion: 0,   // Always 0
        isAS3: false,       // Always false
        frameRate: Float(currentFPS),  // Render FPS, not SWF frame rate
        ...
        totalFrames: UInt32(renderedFrames)  // Render frames, not SWF total
    )
}
```

The SWF Info panel will show incorrect metadata for all files.

**Impact:** SWF Info panel is actively misleading.

**Suggested Fix:** Either implement the `ruffle_player_get_metadata` FFI call properly, or hide the SWF Info panel until it returns real data.

---

### M7 — `SettingsPersistence.resetAll()` Not Called by UI Reset

| Field | Value |
|-------|-------|
| **Location** | `SettingsView.swift`, `SettingsPersistence.swift` |
| **Severity** | Medium |
| **Confidence** | 95% |

**Evidence:** The UI's "Reset All Settings" button calls a local `resetSettings()` method that resets `@AppStorage` keys and `AppState` properties. But it does **not** call `SettingsPersistence.shared.resetAll()`. So `ruffle.quality`, `ruffle.volume`, `ruffle.isMuted`, etc. in `UserDefaults` are never cleared.

**Impact:** After "Reset All Settings", some values persist via `SettingsPersistence` and re-apply on next launch.

**Suggested Fix:** Call `SettingsPersistence.shared.resetAll()` inside the UI reset handler.

---

### M8 — `recentFiles` Duplicate Detection Uses URL Only

| Field | Value |
|-------|-------|
| **Location** | `AppState.swift`, `openFile()` |
| **Severity** | Medium |
| **Confidence** | 70% |

**Evidence:**
```swift
if !recentFiles.contains(where: { $0.url == url }) {
    recentFiles.insert(recentFile, at: 0)
```

If a file is moved/renamed on disk but the URL remains the same, the old entry persists with stale metadata.

**Suggested Fix:** Update the existing entry's metadata when re-opening a file.

---

## Low Priority Issues

### L1 — Unused Components in `LiquidGlassStyles.swift`

| Field | Value |
|-------|-------|
| **Location** | `LiquidGlassStyles.swift` |
| **Severity** | Low |
| **Confidence** | 90% |

**Evidence:** `GlassCardContainer`, `GlassPickerRow`, `GlassBadge`, `GlassTextField`, `GlassIconFrame` are all defined but never referenced in any view.

**Suggested Fix:** Remove unused view types, or keep as design system library if planned for future use.

---

### L2 — `UTType.folder` Extension Returns `nil`

| Field | Value |
|-------|-------|
| **Location** | `ContentView.swift` |
| **Severity** | Low |
| **Confidence** | 75% |

**Evidence:**
```swift
static var folder: UTType? { UTType(filenameExtension: "folder") }
```

`UTType(filenameExtension: "folder")` returns `nil` on macOS — folders don't have file extensions.

**Suggested Fix:** Use `.folder` as the type identifier or handle folders via `NSItemProvider`.

---

### L3 — `applicationShouldHandleReopen` Logic Slightly Confusing

| Field | Value |
|-------|-------|
| **Location** | `AppDelegate.swift` |
| **Severity** | Low |
| **Confidence** | 50% |

**Suggested Fix:** Simplify to just handle the no-window case.

---

### L4 — `StatusBarView` Never Shown

| Field | Value |
|-------|-------|
| **Location** | `StatusBarView.swift` |
| **Severity** | Low |
| **Confidence** | 95% |

**Evidence:** `StatusBarView` is defined with a `#Preview` but never referenced in any view hierarchy.

**Suggested Fix:** Either integrate into the layout or remove the file.

---

### L5 — Haptic Feedback on Every Sidebar Click

| Field | Value |
|-------|-------|
| **Location** | `AppSidebar.swift` |
| **Severity** | Low |
| **Confidence** | 40% |

**Evidence:** Every sidebar navigation triggers `NSHapticFeedbackManager.glassTap()`.

**Suggested Fix:** Consider limiting haptics to meaningful actions (file open, play/pause) rather than every navigation.

---

## Remaining Risks

| Risk | Severity | Notes |
|------|----------|-------|
| App Sandbox may break file access patterns | **High** | Untested — sandbox may prevent opening files via drag-to-Dock or `application(_:open:)` |
| FFI library not bundled in SPM build | **High** | `Package.swift` uses `unsafeFlags` with absolute path `/Users/wangdaoyu/...` — won't work on other machines or CI |
| `window.isRestorable = true` without `NSWindowRestoration` | Medium | Window state restoration may fail silently |
| macOS 27+ APIs (`Glass.regular`, `.glassEffect`) | Medium | macOS 27 is unreleased — availability guards are correct but behavior is unverified |
| No crash reporting or crash recovery | Low | Crashes in production will be invisible to developers |
| `ruffle_ffi` dylib not embedded in app bundle | **High** | The Rust FFI library must be bundled via build phase — not confirmed in current setup |
| Key event handling sends raw macOS key codes | Medium | SWF expects USB HID key codes — mapping may be incorrect for non-US keyboards |

---

## Subsystem Audit Checklist

| # | Subsystem | Status | Issues Found |
|---|-----------|--------|-------------|
| 1 | Application Architecture & State Management | ✅ Complete | C2, C3, C4, H2, H4, H5, M7, M8 |
| 2 | SwiftUI View Hierarchy | ✅ Complete | L1, L4 |
| 3 | FFI Bridge Layer (RuffleBridge) | ✅ Complete | C2, H1, H6, M6 |
| 4 | Player View & Controls | ✅ Complete | M1, M5 |
| 5 | Sidebar & Navigation | ✅ Complete | L5 |
| 6 | Settings View | ✅ Complete | C2, H4, H5, H6, M7 |
| 7 | File Import & Management | ✅ Complete | C4, C5, H3, M3, L2 |
| 8 | Menu Bar & Toolbar | ✅ Complete | M2, M4, L3 |
| 9 | Localization & Internationalization | ✅ Complete | — |
| 10 | Dark Mode & Accessibility | ✅ Complete | — |
| 11 | Memory & Resource Management | ✅ Complete | H1, H6 |
| 12 | Info.plist & Entitlements & Code Signing | ✅ Complete | C1 |
| 13 | Swift Package Configuration | ✅ Complete | — |

---

## Scores

| Metric | Score | Interpretation |
|--------|-------|----------------|
| **Product Experience** | 35/100 | Multiple dead-end workflows, broken feedback loops |
| **User Interface** | 82/100 | Excellent design language, minor animation jank |
| **Human Interaction** | 55/100 | Drop handling broken, loading invisible |
| **Runtime Stability** | 60/100 | Thread safety concerns in bridge |
| **Architecture** | 50/100 | Dual persistence, disconnected systems |
| **Performance** | 78/100 | Debug logging overhead, otherwise good |
| **Native macOS Experience** | 45/100 | Missing sandbox, incomplete features |
| **Accessibility** | 60/100 | Labels present but untested with VoiceOver |
| **Localization** | 80/100 | Good coverage with 2 languages |

---

**Mac App Store Readiness Score: 25/100**  
**Production Readiness Score: 42/100**

---

## Final Verdict

# **NO** ❌

**This release should NOT be approved.**

### Justification

1. **Mac App Store rejection is certain** — App Sandbox entitlement is missing. Apple will reject during automated review before a human even sees it.

2. **Core user workflows are broken** — Settings don't apply, favorites/collections don't persist, ZIP import is a no-op, loading states are invisible. Users will encounter these within minutes of first use.

3. **Data loss on every quit** — The library, favorites, and collections are all ephemeral. This is unacceptable for a "library manager" application.

4. **Incomplete features shipped as complete** — Collections can be created but never populated. ZIP drag-and-drop accepts files but does nothing. These create confusing dead ends.

### Recommended Path to Release

| Sprint | Focus | Key Deliverables |
|--------|-------|------------------|
| **Sprint 1** | Critical blockers | Add App Sandbox entitlement, fix `openFile` loading state, implement persistent storage for recent/favorites/collections, fix settings → player binding |
| **Sprint 2** | High severity | Fix thread safety in bridge, remove or implement ZIP support, unify persistence layer (remove dual systems), remove debug logging |
| **Sprint 3** | Polish | Fix metadata display, complete collections UX, accessibility audit with VoiceOver, performance profiling, verify sandbox compatibility |

**Estimated effort to reach release readiness: 2–3 weeks.**
