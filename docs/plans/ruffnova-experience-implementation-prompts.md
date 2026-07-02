# Ruffnova Experience Implementation Prompts

This document contains staged implementation prompts for DeepSeek. Each prompt is intended to be executed independently and sequentially. Do not skip stages unless the repository already contains an equivalent implementation that passes the acceptance criteria.

Before starting any stage, DeepSeek must read and follow:

- `docs/DESIGN_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/UI_RULES.md`
- `docs/CODE_STYLE.md`

Global constraints for every stage:

- Follow the Feature-First architecture from `docs/ARCHITECTURE.md`.
- Keep Views presentation-only. Move file IO, persistence, import, diagnostics, playback coordination, and search logic into services or view models.
- Prefer native SwiftUI and Apple APIs. Do not add third-party dependencies unless there is no native solution.
- Do not hardcode user-facing strings. Add localized keys where needed.
- Use semantic colors, native materials, SF Symbols, and the existing spacing/design tokens.
- Do not create heavy cards, fake glass, decorative gradients, or custom controls when native controls work.
- Keep changes incremental. Build after each stage.
- Do not leave the project in a partially migrated state.
- Preserve existing user data. Never delete existing recent files or bookmarks during migration.

## Stage 1 Prompt: Architecture Foundation

You are implementing the architecture foundation for Ruffnova's improved user experience.

Read the required docs first:

- `docs/DESIGN_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/UI_RULES.md`
- `docs/CODE_STYLE.md`

Goal:

Refactor the current app toward feature-owned state and service-owned work without changing visible behavior. Prepare the codebase for a real Library, Search, Import, Player, and Diagnostics system.

Current issues to address:

- `AppState` owns too much: playback, library, search, bookmarks, errors, settings sync, and navigation.
- `ContentView` contains file drop handling, zip extraction, search UI, player layout, error toast, and sheet coordination.
- Library data is currently modeled mostly as `RecentFile`, which cannot support long-term management.

Implementation tasks:

1. Add a Library domain model under `Features/Library/Models/`.
   - Create `LibraryItem`.
   - Include at least: `id`, `url`, `name`, `fileSize`, `lastOpened`, `dateAdded`, `thumbnailData`, `tags`, `notes`, `isFavorite`, `lastPlaybackFrame`, and `compatibilityStatus`.
   - Add a small `CompatibilityStatus` enum suitable for persistence.

2. Add `LibraryService` under `Features/Library/Services/`.
   - It should load, save, add, update, remove, and resolve library items.
   - It should preserve existing recent file behavior for now.
   - It should not depend on Views.

3. Add `ImportService` under `Features/Import/Services/`.
   - Move file classification logic out of `ContentView`.
   - Support SWF files, folders, and ZIP files at the service boundary.
   - Keep the first implementation minimal and behavior-compatible.

4. Add a player-facing view model or session type under `Features/Player/ViewModels/`.
   - Start by moving presentation-level player state coordination that is not truly global.
   - Do not attempt a full playback rewrite in this stage.

5. Add a diagnostics model under `Features/Diagnostics/Models/`.
   - Create a structured `PlayerIssue` or equivalent enum.
   - Keep existing `errorMessage` visible behavior working until later stages replace it.

6. Keep `AppState` as a compatibility coordinator for now.
   - Do not break existing views.
   - Avoid large rewrites in one commit-sized step.

Acceptance criteria:

- The app builds successfully.
- Existing open-file, recent-files, favorites, search display, and playback flows still work.
- New service/model files follow the project structure from `docs/ARCHITECTURE.md`.
- No new user-facing hardcoded strings are introduced.
- No file IO remains newly added inside Views.

Suggested verification:

- Run `swift build`.
- Manually inspect that `ContentView` has less business logic than before.
- Confirm existing JSON persistence still loads existing recent files and bookmarks.

## Stage 2 Prompt: Library Management

You are upgrading Ruffnova's Library from a recent-files list into a persistent SWF management feature.

Read and follow all required docs before editing.

Goal:

Make Library the user's long-term SWF collection manager while preserving existing recent-files data.

Implementation tasks:

1. Implement persistent Library storage.
   - Store `LibraryItem` records in Application Support.
   - Use schema versioning.
   - Preserve security-scoped bookmark data where needed.
   - Keep migration reversible in practice by not deleting old files.

2. Migrate existing data.
   - Import records from `recentFiles.json` into the new Library store.
   - Import existing bookmarks/favorites into `isFavorite` or a default Favorites collection.
   - Mark migrated items with sensible defaults.

3. Add import-folder support.
   - Recursively scan folders for `.swf` files.
   - Avoid duplicate entries by resolved URL or bookmark identity.
   - Handle inaccessible files without crashing.

4. Add stale/missing file handling.
   - If a bookmark cannot resolve or a file no longer exists, mark the item as unavailable.
   - Surface this state in Library UI using lightweight native UI.
   - Provide actions to locate the file again or remove it from Library.

5. Add sorting and filtering.
   - Sort by name, last opened, date added, and file size.
   - Filter by all, favorites, recent, missing, compatibility issues, animation, and interactive content where metadata exists.

6. Update Library UI.
   - Use `List` or `LazyVGrid` appropriately.
   - Keep the UI content-first and lightweight.
   - Avoid heavy cards and decorative backgrounds.

Acceptance criteria:

- Existing recent files appear in the new Library after migration.
- Existing favorites are preserved.
- Importing a folder adds SWF files without duplicates.
- Missing files are visible and recoverable/removable.
- Sorting and filtering work without affecting playback.
- The app builds with zero new warnings.

Suggested verification:

- Run `swift build`.
- Test with a folder containing nested SWF files.
- Test with a moved/deleted SWF file.
- Test migration using existing `recentFiles.json` and `bookmarks.json`.

## Stage 3 Prompt: Search Experience

You are making Ruffnova search behave like the primary command surface described in the UI docs.

Read and follow all required docs before editing.

Goal:

Search should operate across the full Library, not just recent file names, and should immediately drive the main content area.

Implementation tasks:

1. Add `SearchService` or `LibrarySearchViewModel` under the correct feature folder.
   - Search by name, path, tags, notes, favorite status, and compatibility status.
   - Keep the first implementation local and in-memory.

2. Update the sidebar search field.
   - Support keyboard focus.
   - Support `Command+F` on macOS.
   - Preserve clear-search behavior.

3. Update search results UI.
   - Show results from the full Library.
   - Group results only if it improves clarity.
   - Use lightweight rows or grid items consistent with Library.
   - Empty state should be short and useful, with actions such as clear search or import folder.

4. Keep search state close to Search/Library.
   - Avoid adding more search-specific logic to `AppState`.
   - Migrate gradually if full removal from `AppState` is too large.

Acceptance criteria:

- `Command+F` focuses search on macOS.
- Search finds items by name, path, tag, note, and compatibility state.
- Empty search state is localized and visually lightweight.
- Selecting a result opens the SWF.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Add test data with tags and notes.
- Verify search while Library, Recent, Favorites, and Player sections are selected.

## Stage 4 Prompt: Thumbnails And Metadata

You are adding visual recognition and useful file metadata to Ruffnova's Library.

Read and follow all required docs before editing.

Goal:

Users should be able to identify SWF files visually and by metadata instead of relying only on filenames.

Implementation tasks:

1. Add `ThumbnailService` under `Core/Thumbnail/` or `Features/Library/Services/` if it remains Library-specific.
   - Prefer a Core service if Player and Library both consume it.
   - Generate, cache, and retrieve thumbnails.

2. Implement thumbnail storage.
   - Store thumbnails in Application Support.
   - Store identifiers or cache paths in `LibraryItem`, not large duplicated blobs where avoidable.
   - Avoid unbounded cache growth.

3. Generate thumbnails from successful playback/rendering.
   - Capture a stable frame after load when possible.
   - If generation fails, record failure and avoid repeated expensive attempts.

4. Display metadata in Library.
   - Show file size, last opened, stage dimensions, frame rate, total frames, and last playback progress when available.
   - Keep row/cell text concise.

5. Unify metadata sources.
   - `SWFInfoPanel`, Library cells, and Diagnostics should use shared metadata models where possible.

Acceptance criteria:

- Library shows thumbnails for files that have generated thumbnails.
- Files without thumbnails show a lightweight native placeholder.
- Metadata appears without crowding the UI.
- Thumbnail generation failure does not block playback.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Open several SWF files and confirm thumbnails persist after relaunch.
- Test a file that fails to render and confirm the app remains responsive.

## Stage 5 Prompt: Player Game Mode

You are improving playback for interactive SWF content and games.

Read and follow all required docs before editing.

Goal:

Interactive content should feel like a focused game/player experience: automatic focus, minimal chrome, predictable fullscreen behavior, and non-intrusive controls.

Implementation tasks:

1. Add `PlayerMode`.
   - Include at least: `normal`, `cinema`, and `game`.
   - Store current mode in Player-owned state, not as unrelated booleans spread across Views.

2. Implement game mode behavior.
   - Automatically focus the stage when an interactive SWF opens.
   - Hide sidebar and toolbar while game mode is active.
   - Hide control overlays after mouse inactivity.
   - Show overlays again on pointer movement.
   - `Esc` exits maximized/game mode where appropriate.
   - Double-clicking the stage toggles stage maximization on macOS.

3. Split control overlays.
   - Separate animation controls, interactive controls, and fullscreen overlay controls.
   - Keep each View below the file-size guidance in `CODE_STYLE.md`.

4. Add per-file playback preferences.
   - Persist volume, muted state, quality, letterbox mode, looping, speed, last playback frame, and preferred player mode per Library item.
   - Global settings remain defaults for new files.

5. Centralize input coordination.
   - Add `PlayerInputCoordinator` or equivalent.
   - Avoid scattering keyboard/mouse handling across `ContentView` and player subviews.

Acceptance criteria:

- Interactive SWF files can enter game mode.
- Stage receives keyboard input reliably after opening.
- Double-click and Esc behavior works on macOS.
- Controls auto-hide and reappear predictably.
- Per-file playback preferences restore on reopen.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Test one animation SWF and one interactive SWF.
- Verify keyboard input still reaches SWF content in game mode.

## Stage 6 Prompt: Diagnostics And Compatibility Reports

You are replacing vague playback errors with structured diagnostics and user-readable compatibility reports.

Read and follow all required docs before editing.

Goal:

When a SWF fails, stalls, has blocked access, or triggers runtime issues, the user should understand what happened and be able to copy a useful report.

Implementation tasks:

1. Build the Diagnostics feature.
   - Add `Features/Diagnostics/Models/CompatibilityReport.swift`.
   - Add `Features/Diagnostics/Models/PlayerIssue.swift`.
   - Add `Features/Diagnostics/Services/DiagnosticsService.swift`.
   - Add `Features/Diagnostics/Views/DiagnosticsView.swift`.

2. Structure player errors.
   - Model at least: file inaccessible, file missing, file damaged, Ruffle load failure, unsupported API, network blocked, filesystem blocked, render initialization failure, script timeout, and unknown failure.

3. Replace generic error toast behavior gradually.
   - Keep a lightweight visible toast for quick feedback.
   - Add an action to open diagnostics details.

4. Generate compatibility reports.
   - Include file name, path, file size, app version if available, engine version if available, stage dimensions, frame rate, total frames, current frame, issue list, permission policy, and trace summary.

5. Add copy-report action.
   - Use native pasteboard APIs on macOS.
   - Localize visible labels.

6. Keep Trace Console as advanced tooling.
   - Do not show raw trace logs as the default user-facing error experience.

Acceptance criteria:

- User can open a diagnostics view from an error state.
- Compatibility report can be copied.
- Known failure categories display meaningful localized text.
- Trace Console remains accessible for advanced users.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Simulate missing file and load failure cases.
- Copy a report and verify its content is useful and not overly verbose.

## Stage 7 Prompt: Collections, Tags, And Notes

You are upgrading Favorites into a fuller organization system.

Read and follow all required docs before editing.

Goal:

Users should be able to organize large SWF collections using favorites, custom collections, tags, and notes.

Implementation tasks:

1. Add a `Collection` model under `Features/Library/Models/` or `Features/Collections/Models/`.
   - Include `id`, `name`, `itemIDs`, `createdAt`, `updatedAt`, and sort settings.

2. Preserve Favorites as a special collection.
   - Existing star/favorite behavior should keep working.
   - Migrate old bookmarks into favorite state if not already done.

3. Add tags and notes editing.
   - Keep editing UI native and minimal.
   - Use sheets, popovers, or inspector-style UI as appropriate.

4. Update sidebar navigation.
   - Show Collections lightly.
   - Avoid decorative sidebars or heavy custom selection backgrounds.

5. Integrate with Search.
   - Tags, notes, and collection names should be searchable.

Acceptance criteria:

- Users can create, rename, and delete collections.
- Users can add/remove Library items from collections.
- Favorites still work as before.
- Tags and notes persist and are searchable.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Create multiple collections and relaunch the app.
- Verify item membership persists.

## Stage 8 Prompt: Privacy And Permission Policies

You are improving how Ruffnova handles SWF network and filesystem access.

Read and follow all required docs before editing.

Goal:

Permission prompts should be contextual, understandable, and controllable per file while preserving global privacy defaults.

Implementation tasks:

1. Add `PermissionPolicyService` under `Core/Security/`.
   - Manage global defaults and per-file overrides.
   - Persist decisions safely.

2. Define permission scopes.
   - Network access.
   - Filesystem access.
   - Future scopes should be easy to add.

3. Define decisions.
   - Always ask.
   - Allow once.
   - Allow for this file.
   - Deny for this file.
   - Use global default.

4. Add contextual prompts.
   - Show prompts when SWF content requests network or filesystem access.
   - Keep text short and localized.
   - Provide clear allow/deny actions.

5. Update Settings.
   - Keep global privacy settings.
   - Add a way to review and clear per-file decisions.

6. Connect Diagnostics.
   - Compatibility reports should include relevant permission decisions when they affect playback.

Acceptance criteria:

- Global privacy defaults still work.
- Per-file permission overrides persist.
- User can clear per-file decisions.
- Blocked access creates a structured diagnostic issue.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Simulate allowed and blocked network/filesystem requests if bridge support exists.
- Verify Settings shows persisted decisions.

## Stage 9 Prompt: Menus, Shortcuts, And Platform Experience

You are making Ruffnova feel complete as a native macOS/iOS app.

Read and follow all required docs before editing.

Goal:

Users should be able to operate important workflows from menus, keyboard shortcuts, and platform-native surfaces without fighting SWF input.

Implementation tasks:

1. Expand macOS commands.
   - Add or verify: open, reload, close current file, add/remove favorite, show in Finder, show SWF info, show diagnostics, show trace console, screenshot, enter/exit game mode, focus search.

2. Centralize shortcut handling.
   - Avoid shortcut logic scattered across many views.
   - In game mode, preserve SWF keyboard input except for essential app/system commands.

3. Improve screenshot command.
   - Capture stage content if possible.
   - Save or copy using native macOS behavior.

4. Improve iOS behavior.
   - Prioritize landscape playback.
   - Respect safe areas for controls.
   - Support external keyboard where feasible.
   - Keep file import from Files/iCloud Drive smooth.

5. Verify accessibility.
   - Interactive controls must have labels, values, hints where useful, and keyboard focus.

Acceptance criteria:

- Important actions are available from macOS menus.
- `Command+F` focuses search.
- Game mode does not steal ordinary SWF input unnecessarily.
- iOS layout works in portrait and landscape.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Manually verify macOS menu commands.
- Test keyboard navigation and VoiceOver labels for new controls.

## Stage 10 Prompt: Settings Cleanup

You are aligning Settings with Ruffnova's real capabilities and modern Apple UI guidance.

Read and follow all required docs before editing.

Goal:

Settings should expose useful defaults without becoming a dumping ground for implementation details.

Implementation tasks:

1. Review rendering settings.
   - Hide unsupported graphics backends such as Vulkan on platforms where they cannot work.
   - If a backend is unavailable but relevant, show clear localized unavailable text.

2. Reorganize playback settings.
   - Defaults for autoplay, letterbox, quality, loop, speed, and default player mode.
   - Explain through concise labels, not long help text.

3. Reorganize privacy settings.
   - Global network access.
   - Global filesystem access.
   - Review/clear per-file decisions.

4. Reorganize advanced settings.
   - ActionScript settings.
   - Debug overlay.
   - Trace console.
   - Diagnostics logs.

5. Use native Settings controls.
   - Prefer `Form`, `Section`, `Toggle`, `Picker`, `Menu`, `Slider`, `Label`, and `DisclosureGroup`.
   - Avoid repeated card-like containers.

Acceptance criteria:

- Settings no longer shows unsupported options as if they work.
- Settings remain localized.
- Global defaults apply to new files.
- Per-file preferences override global defaults where appropriate.
- The app builds successfully.

Suggested verification:

- Run `swift build`.
- Verify settings in light mode, dark mode, high contrast, and reduce transparency.

## Stage 11 Prompt: Data Migration Hardening

You are hardening Ruffnova's persistence migration path.

Read and follow all required docs before editing.

Goal:

Users should keep their recent files, favorites, collections, tags, notes, thumbnails, playback preferences, and permission decisions across app updates.

Implementation tasks:

1. Add explicit schema versions for all new persistence stores.

2. Implement migration tests.
   - Recent files to Library.
   - Bookmarks to Favorites.
   - Legacy thumbnail blobs to thumbnail cache references if applicable.
   - Global preferences to per-file defaults where applicable.

3. Preserve old files.
   - Do not delete old persistence files during migration.
   - Mark migration complete with a version flag.

4. Log migration failures.
   - Use centralized logging.
   - Do not silently swallow data loss.

5. Provide recovery behavior.
   - If migration partially fails, keep the app usable.
   - Show a user-friendly diagnostics issue only when user action is needed.

Acceptance criteria:

- Migration can run repeatedly without duplicating data.
- Existing recent files and favorites survive migration.
- Partial failures do not crash the app.
- Migration failures are logged.
- The app builds successfully and migration tests pass.

Suggested verification:

- Run `swift build`.
- Run available tests.
- Test with copied legacy JSON files in Application Support.

## Stage 12 Prompt: Final Quality Pass

You are performing the final quality pass for the Ruffnova user-experience upgrade.

Read and follow all required docs before editing.

Goal:

Ensure the implementation is complete, maintainable, native-feeling, accessible, localized, and build-clean.

Implementation tasks:

1. Audit architecture.
   - Features own feature logic.
   - Core services do not depend on Features.
   - Shared contains only truly shared code.
   - Views do not perform file IO, persistence, zip extraction, or Ruffle bridge work directly.

2. Audit UI.
   - No fake glass, fake blur, decorative gradients, or heavy card wrappers.
   - Use semantic colors and native materials.
   - Verify minimum window size, fullscreen mode, sidebar collapse, and toolbar resizing.

3. Audit accessibility.
   - Labels, values, hints where appropriate.
   - Keyboard navigation.
   - VoiceOver.
   - Reduce Motion, Reduce Transparency, High Contrast.

4. Audit localization.
   - No hardcoded visible strings.
   - New labels, buttons, empty states, diagnostics messages, and settings strings are localized.

5. Audit code quality.
   - Remove dead code.
   - Remove unused imports.
   - Split files that exceed recommended size.
   - Avoid duplicate logic.

6. Run final verification.
   - Build successfully.
   - Run tests.
   - Manually test import, search, playback, game mode, diagnostics, settings, favorites, collections, and migration.

Acceptance criteria:

- `swift build` succeeds.
- Tests pass where available.
- No new compiler warnings.
- No known unlocalized user-facing strings in new code.
- Main user workflows work end to end.
- The app follows `docs/DESIGN_SPEC.md`, `docs/ARCHITECTURE.md`, `docs/UI_RULES.md`, and `docs/CODE_STYLE.md`.

## Recommended Execution Order

Execute stages in this order:

1. Stage 1: Architecture Foundation
2. Stage 2: Library Management
3. Stage 3: Search Experience
4. Stage 4: Thumbnails And Metadata
5. Stage 5: Player Game Mode
6. Stage 6: Diagnostics And Compatibility Reports
7. Stage 7: Collections, Tags, And Notes
8. Stage 8: Privacy And Permission Policies
9. Stage 9: Menus, Shortcuts, And Platform Experience
10. Stage 10: Settings Cleanup
11. Stage 11: Data Migration Hardening
12. Stage 12: Final Quality Pass

If a stage reveals missing engine or FFI support, implement the UI/service boundary first, add a structured TODO in the relevant service, and keep the app buildable. Do not fake unavailable engine behavior in the UI.
