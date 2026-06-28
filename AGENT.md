# Constitutional Rules

Priority Order:

1. User Instructions
2. AGENTS.md
3. DESIGN_SPEC.md
4. ARCHITECTURE.md
5. UI_RULES.md
6. CODE_STYLE.md
7. Existing Code

If the existing implementation conflicts with the project specifications,
the specifications always take precedence.

# AGENTS.md

# Ruffnova AI Agent Operating Manual

Version 1.0

---

# Mission

You are contributing to **Ruffnova**, a native macOS Flash Player powered by the Ruffle engine.

Your objective is **not** to simply generate code.

Your objective is to improve Ruffnova while preserving its architecture, design language, maintainability, and long-term quality.

Every change should move the project closer to production-quality software.

---

# Source of Truth

Before modifying any code, read the following project specifications **in order**.

1. DESIGN_SPEC.md
2. ARCHITECTURE.md
3. UI_RULES.md
4. CODE_STYLE.md

These documents define the project.

They always override existing implementations.

If existing code conflicts with them,

the specifications win.

Never preserve outdated implementations simply because they currently work.

---

# Working Principles

Always think before coding.

Understand the feature.

Understand the architecture.

Understand the user experience.

Then implement.

Never begin by writing code.

---

# Development Workflow

For every task:

1. Understand the request.

2. Read the relevant project specifications.

3. Locate the affected feature.

4. Understand existing architecture.

5. Propose the simplest solution.

6. Implement.

7. Build.

8. Fix warnings.

9. Verify behavior.

10. Stop.

Never continue refactoring unrelated code.

---

# Scope Control

Modify only the requested feature.

Do not perform repository-wide refactors unless explicitly requested.

Avoid unrelated formatting changes.

Avoid opportunistic rewrites.

Avoid changing files that are unrelated to the task.

Every commit should have one clear purpose.

---

# UI Development Rules

Always follow:

DESIGN_SPEC.md

UI_RULES.md

Do not invent your own design language.

Do not recreate Apple's controls.

Prefer native SwiftUI components.

Prefer modern Apple APIs.

Prefer semantic colors.

Prefer system materials.

If a custom component exists only because of historical reasons,

replace it with a native implementation when appropriate.

---

# Architecture Rules

Always follow:

ARCHITECTURE.md

Feature-first organization.

Single responsibility.

Clear dependency direction.

No giant view files.

No dumping utilities into Shared unless genuinely reusable.

Business logic must not live inside Views.

---

# Code Style Rules

Always follow:

CODE_STYLE.md

Readable code is preferred over clever code.

Small functions.

Small files.

Explicit names.

No dead code.

No deprecated APIs.

No duplicated logic.

---

# Modern Apple APIs

Always prefer the latest stable Apple SDK.

Do not intentionally write legacy SwiftUI.

Do not optimize for historical macOS releases.

When multiple APIs exist,

choose the newest stable implementation.

---

# Native First

Before writing custom code, ask:

Does SwiftUI already provide this?

Does Foundation already provide this?

Does AppKit already provide this?

If yes,

use Apple's implementation.

Avoid reinventing native controls.

---

# Before Creating a New File

Ask:

Does a similar component already exist?

Can this be reused?

Can this feature be decomposed instead?

Avoid duplicate implementations.

---

# Before Creating a New Component

Ask:

Is this reusable?

Will another feature use it?

If not,

keep it inside the current feature.

Do not pollute Shared.

---

# Before Refactoring

Confirm:

The current implementation actually has a problem.

Refactoring without measurable improvement is discouraged.

Do not rewrite simply because another style is possible.

---

# Build Quality

Before completing any task:

The project must build successfully.

No new compiler warnings.

No deprecated APIs.

No obvious runtime regressions.

No unfinished TODOs.

No commented-out code.

No debugging code.

---

# Performance

Avoid:

Deep view hierarchies.

Excessive AnyView.

Repeated GeometryReader.

Large body computations.

Duplicated state.

Prefer lightweight SwiftUI views.

---

# Accessibility

Every interactive control should support:

VoiceOver

Keyboard navigation

Focus

Reduce Motion

Reduce Transparency

High Contrast

Semantic labels

---

# Localization

Never hardcode user-facing strings.

Use the project's localization system.

Maintain localization consistency.

---

# Logging

Never leave print() statements.

Use the project's logging infrastructure.

Debug output should be removable.

---

# Error Handling

Never silently ignore errors.

Present meaningful user-facing errors.

Log technical details when appropriate.

Recover whenever possible.

---

# Code Review Checklist

Before considering a task complete:

✓ Builds successfully

✓ No compiler warnings

✓ No deprecated APIs

✓ No dead code

✓ No duplicated code

✓ Uses semantic colors

✓ Uses native controls where appropriate

✓ Supports Light Mode

✓ Supports Dark Mode

✓ Supports accessibility

✓ Supports keyboard navigation

✓ Matches DESIGN_SPEC.md

✓ Matches ARCHITECTURE.md

✓ Matches UI_RULES.md

✓ Matches CODE_STYLE.md

---

# Forbidden Behaviors

Do not:

Generate placeholder implementations.

Leave TODO comments.

Comment out broken code.

Use deprecated APIs.

Introduce unnecessary custom controls.

Reorganize unrelated modules.

Change project architecture without instruction.

Rewrite working features unnecessarily.

Ignore compiler warnings.

Ignore accessibility.

Ignore localization.

---

# Completion Criteria

A task is complete only when:

The requested feature is implemented.

The project builds successfully.

The implementation follows every project specification.

The code is maintainable.

The result is indistinguishable from production-quality software.

---

# Final Objective

Ruffnova should feel like a modern, first-party macOS application.

Every contribution should improve:

Architecture

Design

Performance

Readability

Maintainability

Consistency

Long-term quality

When in doubt, prefer simplicity, native Apple technologies, and the project's written specifications over personal preference.
