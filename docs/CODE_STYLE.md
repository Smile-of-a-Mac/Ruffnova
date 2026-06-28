# CODE_STYLE.md

# Ruffnova Code Style Guide

Version 1.0

---

# Purpose

This document defines the coding standards for Ruffnova.

Every contributor and every AI coding agent must follow these rules.

Consistency is more important than personal preference.

---

# General Principles

Prefer readability.

Prefer simplicity.

Prefer maintainability.

Prefer modern Swift.

Avoid clever code.

Code is read far more often than it is written.

---

# Swift Version

Use the latest stable Swift supported by the project.

Adopt modern language features.

Avoid obsolete syntax.

---

# Native First

Prefer SwiftUI.

Prefer Observation.

Prefer async/await.

Prefer structured concurrency.

Prefer native Apple APIs.

Avoid unnecessary AppKit.

Avoid third-party libraries when native APIs are sufficient.

---

# File Size

Recommended maximum sizes:

View

300 lines

ViewModel

300 lines

Service

500 lines

Extensions

150 lines

Split files before they become difficult to navigate.

---

# One Responsibility

Each file should have one clear purpose.

Avoid:

Multiple unrelated Views

Multiple Services

Utility dumping grounds

---

# Naming

Names should describe intent.

Good:

LibraryView

PlayerToolbar

ThumbnailGenerator

ImportService

Bad:

Helper

Utils

Common

Stuff

Manager

General

Misc

Data

New

Temp

---

# Comments

Write comments explaining:

Why

Not:

What

Remove commented-out code.

Remove TODOs before merge.

---

# State

Keep state local whenever possible.

Avoid unnecessary global state.

Avoid duplicated state.

State should have one owner.

---

# Dependency Injection

Prefer dependency injection.

Avoid hidden dependencies.

Avoid unnecessary singletons.

---

# Extensions

Prefer focused extensions.

Examples:

String+Localization.swift

View+Animations.swift

URL+Bookmarks.swift

Avoid giant Extensions.swift files.

---

# SwiftUI

Prefer composition over inheritance.

Break large Views into smaller components.

Avoid deeply nested view hierarchies.

Avoid AnyView unless required.

Avoid GeometryReader unless necessary.

Avoid PreferenceKey unless necessary.

---

# Concurrency

Prefer:

async/await

Task

TaskGroup

MainActor

Avoid:

Completion handlers

Nested callbacks

Detached tasks without justification

---

# Error Handling

Never ignore errors silently.

Use Result where appropriate.

Present meaningful user-facing messages.

Log internal failures.

---

# Logging

Use a centralized logging system.

Never leave print() statements in production.

Logs should be searchable.

---

# Constants

Avoid magic numbers.

Prefer named constants.

Group reusable values.

---

# Strings

Every user-facing string must be localized.

Never hardcode visible text.

---

# Performance

Avoid unnecessary allocations.

Avoid repeated work inside body.

Prefer lazy containers.

Profile before optimizing.

---

# Dead Code

Delete:

Unused files

Unused methods

Unused extensions

Unused properties

Unused imports

Commented-out implementations

---

# Deprecated APIs

Do not introduce deprecated APIs.

If a better API exists,

prefer migration.

---

# Compiler

Every commit must satisfy:

Zero errors

Zero warnings

Zero deprecated APIs

---

# Formatting

Use SwiftFormat.

Use SwiftLint.

Do not manually fight formatting.

Automate it.

---

# Pull Request Checklist

Before completing any feature:

✓ Builds successfully

✓ Zero warnings

✓ No dead code

✓ No deprecated APIs

✓ Localized

✓ Light Mode verified

✓ Dark Mode verified

✓ Accessibility verified

✓ Keyboard navigation verified

✓ No unnecessary custom UI components

---

# AI Agent Rules

Never generate code just because it compiles.

Generate code that another engineer can confidently maintain five years from now.

If two implementations are possible,

prefer the simpler one.

If a native Apple solution exists,

use it.

If existing code violates this document,

refactor it rather than extending it.
