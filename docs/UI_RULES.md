# UI_RULES.md

# Ruffnova UI Rules

Version 1.0

---

# Purpose

This document defines every UI rule used throughout Ruffnova.

Its purpose is to ensure visual consistency across the entire application.

Every new screen, component, and interaction must follow these rules.

If an implementation conflicts with this document,

this document takes precedence.

---

# Design Target

Target:

macOS 26

Latest SwiftUI

Latest Human Interface Guidelines

Latest system materials

Latest native controls

Do not imitate previous macOS releases.

---

# Design Philosophy

UI should disappear.

Content should dominate.

Glass creates hierarchy.

Whitespace creates structure.

Animation creates meaning.

Never decorate for decoration's sake.

---

# Window

The window itself is the primary visual container.

Do not paint custom backgrounds.

Do not simulate transparency.

Use native materials.

---

# Toolbar

Toolbar has no visible background.

Toolbar defines layout only.

Toolbar items float above content.

Buttons are circular.

Search is centered.

No toolbar borders.

No toolbar separators.

---

# Sidebar

Use NavigationSplitView whenever possible.

Sidebar should blend into the window.

Avoid visible dividers.

Avoid decorative gradients.

Avoid card-like sidebars.

Selection should be subtle.

---

# Search

Search is the primary command surface.

Rules:

Centered whenever possible

Floating glass

Expands on focus

Supports keyboard focus

Supports Command+F

Never embedded inside a heavy toolbar.

---

# Buttons

Prefer native Button.

Toolbar buttons:

Circle

36–40 pt

Glass material

Native hover

Native focus

Native animations

Avoid custom button backgrounds unless native APIs cannot achieve the desired appearance.

---

# Cards

Cards should be rare.

Never wrap every setting inside a card.

Prefer spacing over containers.

Only create cards for truly independent content groups.

---

# Settings

Use:

Form

Section

Toggle

Picker

Menu

Slider

Label

DisclosureGroup

Avoid excessive decoration.

Rows should breathe.

Hierarchy comes from spacing.

Not boxes.

---

# Lists

Prefer List over ScrollView when appropriate.

Rows should be lightweight.

Avoid unnecessary row backgrounds.

Avoid custom separators.

Selection should rely on system behavior.

---

# Typography

Use Apple's typography.

Preferred hierarchy:

largeTitle

title

headline

body

callout

subheadline

footnote

caption

caption2

Do not invent typography systems.

---

# Colors

Use semantic colors.

Examples:

.primary

.secondary

.tertiary

.tint

.accentColor

.separator

.quaternary

Never hardcode RGB values unless required for branding.

---

# Materials

Only use native materials.

Never fake blur.

Never fake glass.

Never fake translucency.

Always prefer system materials.

---

# SF Symbols

Use SF Symbols.

Maintain consistent symbol weight.

Avoid mixing outlined and filled variants unless intentional.

---

# Layout

Adopt an 8-point spacing system.

Common spacing:

4

8

12

16

20

24

32

40

Avoid arbitrary spacing values.

---

# Corner Radius

Prefer continuous corners.

Recommended values:

8

12

16

20

Avoid inconsistent radii.

---

# Animation

Preferred animations:

smooth

spring

interactiveSpring

contentTransition

symbolEffect

phaseAnimator

Hover animations should be subtle.

Never over-animate.

---

# Hover

Every interactive element should respond to hover.

Hover changes:

Brightness

Scale

Material intensity

Shadow

Never rely only on color.

---

# Accessibility

Every interactive control must include:

Accessibility label

Keyboard focus

VoiceOver support

Reduce Motion support

Reduce Transparency support

High Contrast compatibility

---

# Dark Mode

Every screen must be verified in:

Light Mode

Dark Mode

Reduce Transparency

High Contrast

---

# Responsive Layout

Support:

Minimum window size

Large window size

Full-screen mode

Sidebar collapse

Toolbar resizing

Dynamic Type where applicable

---

# Component Policy

Before creating a new UI component ask:

Does SwiftUI already provide one?

If yes,

use SwiftUI.

If no,

create the smallest possible reusable abstraction.

Never recreate native controls.

---

# Final Principle

Users should notice the content,

not the interface.

If the UI attracts more attention than the content,

it should be simplified.
