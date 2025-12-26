---
name: branding
description: iOS app branding and design system guidelines. Use when creating UI components, implementing views, styling elements, adding animations/haptics, or making any visual design decisions. Covers colors, typography, iconography, glassmorphic effects, and iOS 17+ HIG compliance.
---

# App Branding & Design System

This skill provides comprehensive design guidelines for the iOS voice keyboard app. All UI work must follow these specifications to ensure visual consistency and iOS 17+ Human Interface Guidelines compliance.

## Core Design Philosophy

- **Dark mode first** - Design all colors with dark backdrop first, then derive light mode
- **Glassmorphic/Liquid Glass aesthetic** - Translucent panels that feel suspended in space
- **Layered depth** - Use blur, shadows, and parallax for spatial hierarchy
- **Deference to content** - Minimal chrome, let content shine
- **Native iOS feel** - Use system fonts, SF Symbols, and standard patterns

---

## Color Palette

### Base Colors

| Element | Dark Mode | Light Mode |
|---------|-----------|------------|
| Primary Background | `#1C1C1E` (near-black) | `#F2F2F7` (off-white) |
| Elevated Surface | `#2C2C2E` (dark gray) | Slightly tinted white |
| True Black (OLED) | `#000000` | N/A |

### Accent Color

Choose ONE vibrant accent for interactive highlights:
- **Recommended**: Bright indigo blue or neon teal
- Must pass accessibility contrast on dark backgrounds
- Slightly reduce brightness in dark mode to avoid being too intense
- Use for: primary buttons, active waveforms, logo, interactive elements

### Text Colors

| Type | Dark Mode | Light Mode |
|------|-----------|------------|
| Primary Text | `#FFFFFF` (white) | System label (auto) |
| Secondary Text | Light gray (~90% white) | System secondary label |
| Disabled | System Gray 5/6 | System Gray 5/6 |

### Semantic Colors

- **Error/Stop**: System Red (use for recording indicator, errors)
- **Success/Confirm**: System Green
- Use sparingly for status indication

### Translucent Panels

- Background: 40-50% opacity black with blur
- Use `UIBlurEffect` with system materials (`.systemThinMaterialDark`)
- Creates frosted glass look where background subtly shows through

---

## Typography

### Font Family

**San Francisco (SF Pro)** - System font only, no custom fonts.

- SF Pro Display: Headlines >20pt (auto-selected)
- SF Pro Text: Body and smaller text
- SF Mono: Only if monospace needed (code display)

### Dynamic Type (Required)

All text MUST use Dynamic Type styles for accessibility:

```swift
// Always use text styles, never fixed sizes
Text("Hello")
    .font(.body)  // Correct

Text("Hello")
    .font(.system(size: 17))  // Wrong - doesn't scale
```

### Type Scale

| Style | Usage | Approx Size | Weight |
|-------|-------|-------------|--------|
| Large Title | Onboarding, major headers | 34pt | Bold |
| Title 2 | Section headers | 22pt | Semibold |
| Headline | Subsection headers | 17pt | Semibold |
| Body | Main content, transcriptions | 17pt | Regular |
| Callout | Button labels, helper text | 16pt | Regular/Semibold |
| Footnote | Timestamps, hints | 13pt | Regular |

### Typography Rules

- No decorative fonts
- No italics unless absolutely necessary
- Adequate line height (~1.3x) for readability
- Light gray text on dark backgrounds (not pure white for long text)

---

## Iconography (SF Symbols)

### General Rules

- **Use SF Symbols 5** for all icons
- Icons align automatically with text baseline
- Match icon weight to adjacent text weight
- Prefer outlined (regular) symbols on dark backgrounds
- Use filled icons for primary actions (mic.circle.fill)

### Icon Weights

| Context | Weight |
|---------|--------|
| With body text | Regular |
| Standalone large | Medium or Bold |
| Toolbar | Regular |
| Primary action | Medium filled |

### Key Icons

| Action | SF Symbol |
|--------|-----------|
| Record | `mic.fill` or `mic.circle.fill` |
| Stop | `stop.circle` or `stop.fill` |
| Waveform | `waveform` |
| Settings | `gearshape` |
| Close | `xmark` |
| Globe/Keyboard | `globe` |
| Translate | `globe` or `textformat` |

### Custom Icons

If SF Symbols lacks needed icon:
- Match SF Symbol style (simple geometry, 2px strokes @3x)
- Same corner radii as similar Apple symbols
- Export as template images
- Keep custom usage minimal

---

## Visual Effects

### Corner Radii

| Element | Radius |
|---------|--------|
| Small (buttons, keys) | 6-8pt |
| Medium (cards, panels) | 12pt |
| Large (modals) | 16-20pt |

Use continuous corner smoothing (iOS default) for smooth curves.

### Shadows

| Element | Shadow Settings |
|---------|-----------------|
| Cards/Overlays | Color: black 30%, blur: 15-20, y-offset: 5 |
| Popovers | Color: black 20%, blur: 15, y-offset: 5 |
| Buttons | Generally no shadow (flat) |

Shadow usage:
- Base layer: no shadow
- Content cards: small shadow
- Modals/popovers: larger shadow

### Blur & Materials

```swift
// For translucent overlays
UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))

// SwiftUI
.background(.ultraThinMaterial)
```

Material selection:
- Heavy overlays: thicker blur, less transparency
- Subtle overlays: lighter blur, more context visible
- Performance: avoid stacking multiple blur effects

### Vibrancy

Use `UIVibrancy` for:
- Decorative text/icons on blurred backgrounds
- Less crucial content that should blend with panel
- NOT for important readable text (use full-contrast instead)

---

## Component Styling

### Compact Recording Card

**Appearance:**
- Floats above keyboard
- Translucent glass panel (`systemThinMaterialDark`, 20-30% opacity fill)
- Corner radius: 12pt
- Soft drop shadow (radius 20, opacity 0.3, offset 0,5)

**Content:**
- Centered waveform visualization (accent color, animated)
- Status text: SF Pro Medium 15pt, white
- Timer display
- Stop/cancel button (top-right): SF Symbol in accent or white

**States:**
1. Listening: Live waveform, "Listening..."
2. Processing: Spinner, "Transcribing..."
3. Formatting: Spinner, "Formatting..."
4. Idle: Static mic icon, "Tap to speak"

### Keyboard Extension

**Background:**
- Dark semi-translucent (~90% opacity)
- Slight blur of app content beneath
- Or solid `#1C1C1E` at 95% if translucency problematic

**Keys:**
- Rounded rectangles, 6-8pt radius
- Background: `#1C1C1E`, Keys: `#2C2C2E`
- Tap targets: minimum 44x44pt
- Labels: SF Pro, uppercase default

**Mic Key:**
- Prominent placement
- Uses accent color when active
- Pulsing ring/glow during recording

**Suggestion Bar (if present):**
- Translucent strip above keys
- Hairline top border (ultra-thin white)
- Suggestion chips with slight background

### Dropdown Menus / Popovers

**Appearance:**
- Floating glass card with blur background
- Corner radius: 12pt
- Arrow pointer (anchor) with same material
- Drop shadow (blur 15, opacity 20%)

**Content:**
- Row height: minimum 44pt
- Text: SF Pro 17pt (Body)
- Optional leading icon (SF Symbol, 20pt)
- Highlight state: reduced blur, more solid background

**Animation:**
- Spring fade-in from anchor point
- Scale from 0.8 to 1.0 with spring easing

### Power Mode Workspace

**Layout:**
- Full screen, dark background (`#1C1C1E`)
- Large title header if appropriate
- Safe-area aligned
- Scrollable content areas

**Panels:**
- Reuse translucent card style for sub-sections
- Consider solid darker panels for layered content
- Tool palette bar at bottom (translucent, distinct shade)

**Typography:**
- Body text 17pt for transcripts
- Line height 1.3x
- Light gray text (~90% white) for long content

---

## Motion & Animation

### Spring Animations (Preferred)

```swift
// SwiftUI
.animation(.spring(dampingFraction: 0.7), value: state)

// UIKit
UIView.animate(withDuration: 0.3, delay: 0,
               usingSpringWithDamping: 0.7,
               initialSpringVelocity: 0, ...)
```

**Parameters:**
- Damping: 0.7-0.8 (slight overshoot)
- Scale overshoot: 5-10% maximum
- Duration: 0.2-0.5s (keep snappy)

### Transition Types

| Transition | Usage |
|------------|-------|
| Spring up/down | Card appear/dismiss |
| Crossfade (0.2s) | State changes without spatial relation |
| Morph | Icon function changes (mic → stop) |
| Spatial zoom | Mode transitions (keyboard → Power Mode) |

### SF Symbol Animations

Use SF Symbols 5 animatable features:
- Variable color for state changes
- "Magic Replace" for smooth icon morphing
- Keep morph animations ~0.3s with spring

### Spatial Continuity

When transitioning between views:
- Maintain visual context (blur background, keep elements visible)
- Use parallax (background moves slower than foreground)
- Elements should feel like they rearrange in 3D space

---

## Haptic Feedback

### Feedback Types

| Interaction | Haptic | Generator |
|-------------|--------|-----------|
| Key press | Light impact | `UIImpactFeedbackGenerator(.light)` |
| Start recording | Medium impact | `UIImpactFeedbackGenerator(.medium)` |
| Stop recording | Medium impact | `UIImpactFeedbackGenerator(.medium)` |
| Task complete | Success notification | `UINotificationFeedbackGenerator(.success)` |
| Mode switch | Selection changed | `UISelectionFeedbackGenerator` |
| Error | Warning/Error notification | `UINotificationFeedbackGenerator(.warning)` |

### Haptic Rules

- Light and quick - never disruptive
- Pair with visual animation for multi-sensory feedback
- No long vibrations for simple taps
- Don't chain multiple haptics rapidly
- Consistent: same haptic for same category of events

---

## Accessibility Requirements

### Touch Targets
- Minimum 44x44pt for all interactive elements

### Dynamic Type
- ALL text must use text styles
- Layouts must accommodate XXL and Accessibility sizes
- Test with largest Dynamic Type setting

### Contrast
- Text must pass WCAG contrast requirements
- Test accent colors on dark backgrounds
- Avoid pure white on pure black (use off-colors)

### VoiceOver
- All controls need accessibility labels
- Icons need descriptive labels
- State changes announced appropriately

---

## iOS 17+ HIG Compliance Checklist

- [ ] Dark mode uses base vs elevated colors for depth
- [ ] All text uses Dynamic Type styles
- [ ] Touch targets >= 44pt
- [ ] SF Symbols used for all icons
- [ ] Translucent materials for overlays
- [ ] Spring animations for physical feel
- [ ] Haptics paired with interactions
- [ ] Shadows create depth hierarchy
- [ ] Continuous corner smoothing
- [ ] System colors for semantic states
- [ ] Spatial transitions maintain context

---

## Quick Reference

### Colors
```swift
// Backgrounds
Color(uiColor: UIColor.systemBackground)  // Auto dark/light
Color(hex: "#1C1C1E")  // Dark base
Color(hex: "#2C2C2E")  // Dark elevated

// Materials
.ultraThinMaterial
.thinMaterial
.regularMaterial
```

### Typography
```swift
.font(.largeTitle)   // 34pt bold
.font(.title2)       // 22pt semibold
.font(.headline)     // 17pt semibold
.font(.body)         // 17pt regular
.font(.callout)      // 16pt regular
.font(.footnote)     // 13pt regular
```

### Common SF Symbols
```
mic.fill, mic.circle.fill
stop.fill, stop.circle
waveform, waveform.circle
xmark, xmark.circle
globe
gearshape, gearshape.fill
chevron.down
checkmark.circle.fill
exclamationmark.triangle
```
