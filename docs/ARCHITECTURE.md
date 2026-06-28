# ARCHITECTURE.md

# Ruffnova Architecture Specification

Version 1.0

---

# Purpose

This document defines the software architecture of Ruffnova.

It exists to ensure long-term maintainability, scalability, and consistency across the entire codebase.

Every implementation, whether written by a human developer or an AI coding agent, must follow this specification.

If existing code conflicts with this document, this document takes precedence.

---

# Architecture Principles

Ruffnova is a modern macOS application.

Its architecture must prioritize:

* Simplicity
* Feature isolation
* Native Apple technologies
* Long-term maintainability
* Clear ownership
* Testability
* Predictable dependency flow

Avoid architecture designed around files or UI widgets.

Instead, organize around features.

---

# Project Structure

The repository must follow a Feature-First architecture.

```
Ruffnova/

├── App/
│
├── Core/
│
├── Features/
│
├── Shared/
│
├── Resources/
│
├── SupportingFiles/
│
└── Tests/
```

---

# App

Contains application entry points only.

Examples:

* RuffnovaApp.swift
* AppDelegate.swift
* Commands
* Window definitions
* Dependency injection
* Environment registration

No business logic belongs here.

---

# Core

Contains infrastructure that powers the application.

Examples:

```
Core/

Ruffle/

Persistence/

Localization/

Preferences/

Logging/

Security/

Playback/

FileSystem/
```

Core code should never depend on Features.

Core provides services.

Features consume them.

---

# Features

Every user-facing capability belongs to a feature.

Example:

```
Features/

Library/

Player/

Search/

Settings/

Import/

Recent/

About/
```

Each feature owns its UI and business logic.

Each feature should remain as independent as possible.

---

# Feature Structure

Each feature should follow a consistent layout.

Example:

```
Library/

Views/

ViewModels/

Models/

Components/

Services/

Utilities/
```

Rules:

Views contain presentation.

ViewModels contain presentation logic.

Models represent data.

Services perform work.

Components are reusable only inside the feature.

Utilities should remain minimal.

---

# Shared

Shared contains reusable code used by multiple features.

Example:

```
Shared/

Components/

Extensions/

Utilities/

Models/

Styles/

Animations/

Icons/

Protocols/
```

Never place feature-specific code here.

If only one feature uses something,

it belongs inside that feature.

---

# Resources

Contains:

Assets

Localization

Fonts (if absolutely necessary)

JSON

Templates

Configuration files

Never place Swift code here.

---

# SupportingFiles

Contains:

Info.plist

Entitlements

Launch configuration

Build scripts

Project configuration

---

# Tests

Mirror the production structure.

```
Tests/

LibraryTests/

PlayerTests/

SearchTests/

SettingsTests/
```

Never create a generic Tests folder containing unrelated files.

---

# Dependency Rules

Dependency direction is strictly enforced.

```
App

↓

Features

↓

Core

↓

Shared
```

Shared never imports Features.

Core never imports Features.

Features should avoid importing each other.

Communication between features should happen through Core or shared protocols.

---

# View Rules

Views are responsible only for presentation.

Views must never:

perform file IO

perform networking

parse JSON

write UserDefaults

communicate with Ruffle directly

contain complex business logic

Views should remain lightweight.

---

# ViewModel Rules

ViewModels coordinate UI behavior.

Responsibilities include:

state

user interaction

presentation logic

navigation decisions

ViewModels should avoid platform-specific rendering code.

---

# Service Rules

Services perform work.

Examples:

LibraryService

PlayerService

SearchService

ImportService

ThumbnailService

SettingsService

LocalizationService

Services should be injectable.

Avoid global singleton services unless there is a strong justification.

---

# State Management

Prefer Apple's modern Observation system.

Avoid unnecessary ObservableObject usage where newer APIs are available.

Minimize global state.

State should remain close to the feature that owns it.

---

# UI Components

Before creating a custom component ask:

Does SwiftUI already provide this?

If yes,

use SwiftUI.

Custom components exist only when native controls cannot satisfy the requirement.

Do not recreate Apple's controls.

---

# File Organization

Avoid large source files.

Recommended limits:

View

< 300 lines

ViewModel

< 300 lines

Service

< 500 lines

Extensions

Single responsibility only.

Split files before they become difficult to navigate.

---

# Naming

Names must describe responsibility.

Good:

LibraryView

PlayerToolbar

SearchField

ImportService

ThumbnailGenerator

Avoid:

Helper

Utils

Manager

Common

Stuff

Misc

General

Data

New

Temp

---

# Extensions

Extensions should be narrowly scoped.

Avoid massive Extensions.swift files.

Prefer:

```
String+Localization.swift

Color+Semantic.swift

View+GlassEffects.swift

URL+Bookmark.swift
```

---

# SwiftUI Guidelines

Prefer modern SwiftUI APIs.

Avoid deprecated APIs.

Do not preserve compatibility with obsolete implementations.

If Apple introduces a better API,

prefer migration over maintaining legacy code.

---

# Performance

Avoid unnecessary view invalidation.

Avoid nested GeometryReaders.

Avoid excessive AnyView.

Avoid unnecessary type erasure.

Avoid duplicated state.

Prefer lazy containers where appropriate.

---

# Error Handling

Never silently ignore errors.

Recover when possible.

Log meaningful failures.

Present user-friendly errors.

Never crash intentionally in production code.

---

# Concurrency

Prefer structured concurrency.

Use:

async/await

Task

MainActor

Avoid callback chains.

Avoid detached tasks unless absolutely necessary.

---

# Logging

Centralize logging.

Avoid random print() statements.

Use a consistent logging abstraction.

Debug logging should be removable.

---

# Localization

Every user-facing string must be localized.

Never hardcode visible text inside Swift files.

---

# Accessibility

Every interactive element must support:

VoiceOver

Keyboard navigation

Accessibility labels

Accessibility values

Accessibility hints where appropriate

---

# Code Review Checklist

Every pull request or AI-generated change must satisfy:

✓ Builds successfully

✓ Zero compiler warnings

✓ No deprecated APIs

✓ No dead code

✓ No duplicated logic

✓ No unnecessary custom controls

✓ Uses semantic colors

✓ Uses native SwiftUI controls where possible

✓ Supports Light and Dark Mode

✓ Supports Reduce Transparency

✓ Supports keyboard navigation

✓ Supports accessibility

---

# AI Agent Rules

Before making any code changes:

Read:

* DESIGN_SPEC.md
* ARCHITECTURE.md
* UI_RULES.md
* CODE_STYLE.md

Do not modify code until these documents are understood.

Do not preserve existing architecture simply because it already works.

Redesign when necessary.

Refactor rather than patch.

Complete one feature at a time.

Build after every feature.

Never leave the project in a partially migrated state.

---

# Final Goal

The repository should resemble a professionally maintained Apple-platform application.

Every folder should have a clear responsibility.

Every dependency should have a clear direction.

Every feature should be understandable in isolation.

The architecture should remain stable as Ruffnova continues to grow.
