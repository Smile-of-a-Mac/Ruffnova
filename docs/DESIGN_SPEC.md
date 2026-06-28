Ruffnova Design Specification
macOS 26 Liquid Glass Edition
Version 1.0
Design Mission

Ruffnova is not a Flash player.

It is a modern macOS application that happens to play Flash content.

The design target is Apple's first-party applications shipping with macOS 26, not third-party SwiftUI applications.

Every interface should feel as though it was created by Apple's Human Interface Design team rather than by an independent developer.

If a screen could plausibly exist in macOS 14 or earlier, it is considered outdated and must be redesigned.

Design Philosophy

Every screen should follow five principles.

1. Content First

The application exists to display Flash content.

Chrome should visually disappear.

Navigation should feel lightweight.

Controls should never dominate the interface.

2. Floating Interface

Nothing should appear attached to the window.

Buttons float.

Toolbars float.

Search floats.

Badges float.

Panels float.

Everything sits above the content.

3. Glass Hierarchy

There is only one background.

The window itself.

Everything else is layered glass.

Hierarchy:

Window Glass

↓

Sidebar Glass

↓

Toolbar Glass

↓

Floating Controls

↓

Content

↓

Transient HUD

Never introduce additional opaque layers.

4. Lightness

Remove unnecessary borders.

Remove unnecessary separators.

Remove unnecessary shadows.

Remove unnecessary boxes.

Whitespace communicates hierarchy.

Not rectangles.

5. Native

If Apple provides a component,

use it.

If Apple provides an animation,

use it.

If Apple provides a material,

use it.

Never imitate Apple.

Use Apple.

Window

The window itself is glass.

Never paint a solid background.

Never paint a grey rectangle.

Never simulate transparency.

The desktop should subtly influence the window.

Sidebar

Sidebar is part of the window.

Not a floating card.

Not a dark panel.

Not a separate rectangle.

Sidebar should blend naturally into the window glass.

The distinction between Sidebar and Content comes from material hierarchy, not borders.

Avoid visible separators whenever possible.

Toolbar

Toolbar should not exist visually.

Toolbar only defines layout.

There is no toolbar background.

There is no toolbar border.

There is no toolbar shadow.

Only floating controls exist.

Search

Search is the primary control.

Search should be the visual anchor.

Search uses floating glass.

Search should expand smoothly.

Search should never feel embedded inside a toolbar.

Buttons

Toolbar buttons are floating circular glass objects.

Never capsules.

Never rounded rectangles.

Never filled icons.

Every button should appear suspended above the interface.

Hover increases brightness.

Pressed slightly compresses.

Materials should change naturally.

Settings

Settings should resemble modern Apple applications.

Do not resemble System Settings from macOS 11–15.

Avoid heavy cards.

Avoid decorative containers.

Avoid repeated rounded rectangles.

Use whitespace instead of boxes.

Settings consist of:

Sections

Rows

Native controls

Subtle hierarchy

Nothing else.

Lists

Lists are lightweight.

Rows breathe.

Selection is understated.

Scrolling should feel effortless.

No excessive backgrounds.

Materials

Only use system materials.

Never simulate glass using colors.

Never create fake blur.

Never paint transparent grey.

Never approximate Apple's materials.

Use framework materials directly.

Color

Use semantic colors.

Never define arbitrary greys.

Never define arbitrary whites.

Never define arbitrary blacks.

Accent color comes from the system.

The interface automatically adapts to:

Light Mode

Dark Mode

High Contrast

Reduce Transparency

Typography

Only Apple's typography.

No custom font hierarchy.

Prefer:

Large Title

Title

Headline

Body

Callout

Caption

Spacing creates emphasis.

Not font weight.

Icons

Use SF Symbols.

Never decorate icons.

Avoid icon backgrounds.

Only create icon containers when necessary.

Toolbar icons remain simple.

Animation

Every animation should feel physical.

Never use exaggerated movement.

Animations communicate hierarchy.

Not decoration.

Prefer:

spring

smooth

interactiveSpring

contentTransition

symbolEffect

phaseAnimator

Hover should be subtle.

Interaction

Every control must provide:

Hover feedback

Focus feedback

Keyboard navigation

Accessibility

VoiceOver

Pointer interaction

No interaction should rely only on color.

Layout

Adopt an 8-point grid.

Large margins.

Generous spacing.

Avoid dense layouts.

Content should breathe.

Component Rules

Before creating a custom component ask:

Does SwiftUI already provide this?

If yes,

use SwiftUI.

Custom components exist only when no native solution exists.

Architecture Rules

Views contain presentation only.

Business logic belongs elsewhere.

Large views are decomposed.

Features are isolated.

Shared code remains shared.

Never build giant view files.

Quality Standard

The goal is not:

"Looks good."

The goal is:

"If this screenshot appeared on developer.apple.com, nobody would question that it was built by Apple."

Implementation Workflow (Mandatory)

For every screen:

Ignore the existing implementation.
Analyze the purpose of the screen.
Imagine how Apple's Human Interface team would design it today.
Design the interface from first principles.
Only then write SwiftUI.

Never translate old layouts into new APIs.

Redesign first.

Implement second.

Absolute Rules

Never preserve outdated layouts.

Never preserve outdated hierarchy.

Never preserve outdated spacing.

Never preserve outdated controls.

Never preserve outdated visual language.

If an interface resembles Big Sur, Monterey, Ventura, Sonoma or Sequoia,

it has failed the redesign.

Target only the visual language introduced with macOS 26.

Final Objective

The finished application should not look like:

a SwiftUI sample project
an Electron application
a cross-platform application
an AI-generated interface
a Big Sur-era macOS app

It should instead feel indistinguishable from Finder, Photos, Preview, Journal, or another first-party Apple application designed for macOS 26.