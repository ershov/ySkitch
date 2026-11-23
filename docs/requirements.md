# ySkitch — Requirements

Status: final v1.4 · 2026-11-24

## 1. Purpose

A fast, lightweight macOS image annotation app modeled on the Skitch workflow: grab an image (clipboard or file), annotate it, send it back to the clipboard or save as PNG. No background agent, no cloud, no accounts.

Legend: **[U]** stated by the user · **[S]** suggested and accepted.
Stage: **1** MVP · **2** next · **3** later. All listed functional requirements are planned; stage sets order.

## 2. Scope

In scope: single-image annotation editor, multiple document windows, clipboard/file I/O.

Out of scope (for now): screen capture, global hotkeys, menu-bar/background process, cloud sync/sharing, accounts, telemetry, user-facing editable document format, Settings UI, sandboxing.

## 3. Core workflow

1. Source: new window picks up the clipboard image, or open a file.
2. Annotate.
3. Output: copy to clipboard, or save as PNG.

## 4. Image model

| ID | Req | Src | Stage |
|---|---|---|---|
| IMG-1 | Retina-aware: a document has pixel size + scale factor (1×, 2×, …). Scale is taken from the source (clipboard `NSImage` rep size vs pixel size, PNG `pHYs`/DPI; macOS screenshots carry 144 DPI = 2×). Falls back to 1× when unknown | U | 1 |
| IMG-2 | Annotation geometry, thickness and font sizes are in points; rendered at the document's scale so a 2× screenshot gets crisp 2× strokes | U | 1 |
| IMG-3 | Always opaque, white background. Transparent/semi-transparent source pixels are composited onto white on import. Output never contains transparent pixels | U | 1 |
| IMG-4 | Canvas = image rect (or crop rect) ∪ bounds (incl. outline) of annotations that extend the canvas. An annotation extends the canvas once it is drawn or edited (moved, resized, restyled); cropping resets this for all existing annotations. Extends in any direction while drawing/dragging; area without image pixels is white. Shrinks only on mouse-up, never smaller than the image/crop rect. Annotation parts outside the canvas are not rendered | U | 1 |
| IMG-5 | Export and clipboard output preserve scale: pixel data at native resolution, point size set so pasted images appear at the correct size in other apps | U | 1 |

## 5. Functional requirements

### 5.1 Input

| ID | Req | Src | Stage |
|---|---|---|---|
| IN-1 | On launch, a new window is created. A new window (launch or `⌘N`) uses the clipboard image if one is present, otherwise a blank canvas | U | 1 |
| IN-2 | `⌘⇧N`: new blank canvas, 1024×768 pt, white | U | 1 |
| IN-3 | Open image file (PNG, JPEG, HEIC, GIF first frame, TIFF, BMP, WebP) via `⌘O` | U | 1 |
| IN-4 | Open via drag-and-drop onto window / app icon / Dock | S | 1 |
| IN-5 | Open via "Open With…" and CLI (`open -a ySkitch file.png`) | S | 2 |
| IN-6 | Paste an image into an existing document as a movable image object | S | 2 |
| IN-7 | Recent files menu | S | 2 |
| IN-8 | `⌘V` with an image on the clipboard replaces the window's content: the image becomes the new base image and all annotations are cleared; undoable. When the clipboard holds copied ySkitch annotations, `⌘V` pastes those instead (ED-3) | U | 1 |

### 5.2 Output

| ID | Req | Src | Stage |
|---|---|---|---|
| OUT-1 | Copy flattened result to clipboard (`⌘⇧C`, or `⌘C` with no selection) | U | 1 |
| OUT-2 | Save as PNG (`⌘S` / `⌘⇧S`); PNG is the default format | U | 1 |
| OUT-3 | Export JPEG; quality chosen in the save panel | S | 2 |
| OUT-4 | Drag result out of the window (drag handle) into other apps (Slack, mail, Finder) | S | 1 |
| OUT-5 | Export scale: original pixels (default) / 1×; chosen in the save panel | S | 2 |
| OUT-6 | Strip metadata (EXIF/GPS) on export, always | S | 1 |
| OUT-7 | macOS Share menu | S | 3 |

No editable native format: output is always a flat regular image.

### 5.3 Documents and windows

| ID | Req | Src | Stage |
|---|---|---|---|
| WIN-1 | Multiple independent document windows, each with own image, annotations, undo history | U | 1 |
| WIN-2 | Standard window management: Window menu, `` ⌘` `` cycling, `⌘W` close | S | 1 |
| WIN-3 | No "unsaved changes" prompt. On close, window state (image + annotation objects + view + undo history) is kept **in memory only** | U | 1 |
| WIN-4 | `⌘⇧T` reopens the most recently closed window (LIFO stack; repeatable). Capacity is the named constant `ClosedWindowHistory.capacity = 20`; oldest entries are dropped beyond it. History is lost when the app quits | U | 1 |
| WIN-5 | New window sized to fit image (capped to screen) | S | 1 |
| WIN-6 | Standard macOS app lifecycle: app keeps running with no windows; no special handling | U | 1 |

Window state is never written to disk, so unredacted originals of closed windows don't outlive the process.

### 5.4 Canvas and view

| ID | Req | Src | Stage |
|---|---|---|---|
| VIEW-1 | Trackpad: two-finger pinch zooms around the gesture point; two-finger swipe pans; smart-zoom (two-finger double-tap) toggles Fit/100% | U | 1 |
| VIEW-2 | Keyboard/mouse zoom: `⌘+`/`⌘-`, `⌘`+scroll wheel, Fit (`⌘9`), Actual size (`⌘0`); space+drag pans | S | 1 |
| VIEW-3 | Correct HiDPI rendering; at 100% one image pixel maps to one device pixel for images whose scale matches the screen | U | 1 |
| VIEW-4 | Manually extend canvas (add margin) | S | 3 |
| VIEW-5 | Rotate 90° / flip | S | 3 |

### 5.5 Annotation tools

All annotations are vector objects, editable until export (flattened only on output).

| ID | Tool | Details | Src | Stage |
|---|---|---|---|---|
| T-1 | Arrow | Skitch-style tapered arrow; head scales with thickness | U | 1 |
| T-2 | Text | Multiline; editable after creation; thickness slider sets font size | U | 1 |
| T-3 | Rectangle | Outline | U | 1 |
| T-3a | Fill for rectangle, rounded rectangle, ellipse (needs sketch update) | S | 2 |
| T-4 | Rounded rectangle | Radius scales with thickness | U | 1 |
| T-5 | Ellipse | Outline | U | 1 |
| T-6 | Line | Straight segment | U | 1 |
| T-7 | Freehand pen | Stroke smoothing | U | 1 |
| T-8 | Highlighter | Semi-transparent multiply blend, round tip (as in Skitch); no darkening on self-overlap within one stroke | U | 1 |
| T-9 | Crop | Handles; non-destructive (re-croppable); Enter applies, Esc cancels. Discards image pixels outside the crop rect. Existing annotations stay as objects; parts outside the crop are hidden until the annotation is edited, which extends the canvas per IMG-4 | U | 1 |
| T-10 | Pixelate | Region; destructive in output; thickness slider sets block size | U | 1 |
| T-11 | Blur | Alternative to pixelate; thickness slider sets radius | S | 2 |
| T-12 | Redact box | Solid opaque fill | S | 2 |
| T-13 | Numbered step markers | Auto-incrementing circled numbers | S | 2 |
| T-14 | Stamps | ✓, ✗, ?, !, etc. | S | 3 |
| T-15 | Callout / speech bubble | Box with pointer + text | S | 3 |
| T-16 | Spotlight | Dim everything outside a region | S | 3 |
| T-17 | Magnifier | Zoomed inset of a region | S | 3 |
| T-18 | Arrow variants | Double-headed, plain-line, curved | S | 3 |

### 5.6 Styling

| ID | Req | Src | Stage |
|---|---|---|---|
| ST-1 | **Double outline (key feature):** every drawn object (arrows, shapes, lines, pen, text, markers, stamps, callouts) is rendered with an inner white outline and an outer soft dark halo (omnidirectional shadow: zero offset, ~2 pt blur, ~50% black), so it is visible on any background. Not applied to highlighter, pixelate, blur, redact, crop | U | 1 |
| ST-2 | Fixed Skitch palette (§6.3), always visible, one click | U | 1 |
| ST-3 | Custom color picker (system color panel) | S | 2 |
| ST-3a | Remember recent custom colors | U | 3 |
| ST-4 | Eyedropper (pick color from image) | S | 3 |
| ST-5 | Thickness: vertical slider, continuous, per-tool range (§6.2) | U | 1 |
| ST-6 | Style applies to selected object(s) if any, else to the next drawn object | S | 1 |
| ST-7 | Each tool remembers its own color and thickness (see §7) | U | 1 |

### 5.7 Object editing

| ID | Req | Src | Stage |
|---|---|---|---|
| ED-1 | Select tool; click/marquee select; `⇧`-click multi-select | S | 1 |
| ED-2 | Move, resize, endpoint drag (lines/arrows) | S | 1 |
| ED-3 | Delete (`⌫`), duplicate (`⌘D`), copy/paste objects between windows | S | 1 |
| ED-4 | Nudge with arrow keys (1 pt; `⇧` = 10 pt) | S | 2 |
| ED-5 | Z-order: bring to front / send to back | S | 2 |
| ED-6 | Unlimited undo/redo (`⌘Z` / `⌘⇧Z`) per document | S | 1 |
| ED-7 | Double-click text to edit | S | 1 |

### 5.8 Modifiers and shortcuts

| ID | Req | Src | Stage |
|---|---|---|---|
| KEY-1 | `⇧` while drawing line/arrow: constrain to 45° steps | U | 1 |
| KEY-2 | `⇧` while drawing rect/ellipse: square/circle; while moving: constrain axis | S | 1 |
| KEY-3 | `⌥` while drawing arrow: reverse direction (head at start point) | U | 1 |
| KEY-4 | `⌥` while drawing rect/ellipse: draw from center | S | 2 |
| KEY-5 | Single-key tool shortcuts (V select, T text, A arrow, L line, R rect, U rounded rect, O ellipse, P pen, H highlighter, X pixelate, C crop) | S | 1 |
| KEY-6 | Number keys `1`–`8` select palette color; `[` / `]` step the thickness slider down / up | S | 1 |
| KEY-7 | `Esc` cancels current operation / deselects | S | 1 |

## 6. UI

- Left-side toolbar, Skitch-style, in two columns: tools · colors with the thickness slider below them. No column headings.
- Every toolbar item shows its keyboard key next to it (e.g. small `A` beside the arrow icon). Icons only, no tool names.
- With an object selected, color/thickness controls reflect and edit it.
- Icons: SF Symbols or code-drawn; no external assets.
- Canvas surround color is an internal constant `CanvasStyle.surroundColor` (neutral grey).
- **No UI is implemented or changed without the user confirming the sketch first.**

### 6.1 Document window

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●                        Screenshot 2026-11-24 at 10.15                             │
├───────────────┬─────────────────────────────────────────────────────────────────────────┤
│ V ➤    1 ●    │                                                                         │
│        2 ●    │              ┌──────────────────────────────────────────────┐           │
│ T Aa   3 ●    │              │                                              │           │
│        4 ●    │              │                                              │           │
│ A ↗    5 ●    │              │                                              │           │
│ L ╱    6 ◉    │              │                                              │           │
│ R ▭    7 ○    │              │             image + annotations              │           │
│ U ▢    8 ●    │              │                (white canvas)                │           │
│ O ◯      [    │              │                                              │           │
│          ╷    │              │                                              │           │
│ P ✎      │    │              │                                              │           │
│ H ▬      ┃    │              │                                              │           │
│          ●    │              └──────────────────────────────────────────────┘           │
│ X ▦      ┃    │                                                                         │
│          █    │               (canvas surround: CanvasStyle.surroundColor)              │
│ C ⌗      ]    │                                                                         │
├───────────────┴─────────────────────────────────────────────────────────────────────────┤
│ 2880×1800 px · 1440×900 pt · @2x       [⠿ Drag]                   1:1  Fit   −  100%  + │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Tools column**, grouped with extra spacing between groups:
  1. Select (`V`)
  2. Text (`T`)
  3. Arrow (`A`), Line (`L`), Rect (`R`), Rounded rect (`U`), Ellipse (`O`)
  4. Pen (`P`), Marker/highlighter (`H`)
  5. Pixelate (`X`) — later also Blur, Redact
  6. Crop (`C`)

  Later tools join the nearest group: step markers, stamps, callouts → after Text; arrow variants → shapes group.
- **Color column**: 8 palette swatches, keys `1`–`8`, selected one ringed (`◉`); `+` (custom color) comes in Stage 2.
- **Thickness slider**: directly below the swatches in the same column, horizontally centered under them; it extends down so the color column ends level with the last tool row. The track is a wedge — thin at the `[` end (top, thinner) and thick at the `]` end (bottom, thicker). The thumb doubles as the size preview: a dot of the current thickness in the current color (clamped to the column width); for Text it shows "Aa", for Pixelate a small mosaic.
- **Status bar**: left — image size (px, pt, scale); center — drag handle (OUT-4); right, in order — `1:1` (actual size, `⌘0`), `Fit` (`⌘9`), zoom `−` / percentage / `+`.
- Title: source file name, else `ySkitch <date> at <time>` (same as the default export file name, DEF-8).

### 6.2 Thickness slider

| Tool | Meaning | Range | Default |
|---|---|---|---|
| Arrow, Line, Rect, Rounded rect, Ellipse, Pen | Stroke width | 1–40 pt | 4 pt |
| Marker (highlighter) | Stroke width | 4–60 pt | 20 pt |
| Text | Font size | 10–120 pt | 24 pt |
| Pixelate | Block size | 2–40 pt | 10 pt |
| Blur (later) | Radius | 2–40 pt | 10 pt |

- Logarithmic mapping, so small sizes get finer control.
- `[` / `]` move the slider by 1/20 of its range (logarithmic steps).
- Ranges and defaults are named constants in code.

### 6.3 Palette

Sampled from Skitch (sRGB). Key order matches Skitch's top-to-bottom order.

| Key | Color | Hex |
|---|---|---|
| `1` | Red | `#FF2500` |
| `2` | Orange | `#FF941A` |
| `3` | Yellow | `#FEF500` |
| `4` | Green | `#00E700` |
| `5` | Blue | `#198EFE` |
| `6` | Pink (default for all tools) | `#FF2E6C` |
| `7` | White | `#FFFFFF` |
| `8` | Black | `#000000` |

## 7. Defaults and remembered state

No Settings UI. Everything uses a sensible default and remembers the last value used. Remembered values persist across launches in `UserDefaults`; window history does not (WIN-3).

| ID | Item | Default | Remembered |
|---|---|---|---|
| DEF-1 | Per-tool color | Pink `#FF2E6C` for all tools | Per tool |
| DEF-2 | Per-tool thickness | Per §6.2 | Per tool |
| DEF-3 | Active tool for new windows | Arrow | Last used |
| DEF-4 | Export format | PNG | Last used |
| DEF-5 | JPEG quality | 85% | Last used |
| DEF-6 | Export scale | Original pixels | Last used |
| DEF-7 | Save folder | Desktop | Last used |
| DEF-8 | File name | Window title (§6.1) | — |
| DEF-9 | New window uses clipboard image | Always (IN-1) | — |
| DEF-10 | Text font | System font, bold | — |
| DEF-11 | Highlighter opacity | 40% | — |
| DEF-12 | Double outline | Always on | — |
| DEF-13 | Palette | Fixed, §6.3 | — |

## 8. Non-functional requirements

| ID | Req | Stage |
|---|---|---|
| NF-1 | macOS only; minimum macOS 26. Apple Silicon native | 1 |
| NF-2 | Swift 6 (strict concurrency), AppKit for windows/canvas; SwiftUI allowed for the toolbar. Swift Package Manager, no Xcode project. No third-party dependencies | 1 |
| NF-3 | Responsive in everyday use. No hard performance targets; optimize when real use shows a problem | 1 |
| NF-5 | Fully offline; no network access; no telemetry | 1 |
| NF-6 | Exported pixelated/redacted regions contain no recoverable original data | 1 |
| NF-7 | Preserve source color profile (sRGB / Display P3) on output | 2 |
| NF-8 | Light/dark mode UI (canvas background stays white) | 2 |
| NF-9 | Accessibility: VoiceOver labels on toolbar, keyboard-only operation | 2 |
| NF-10 | Distribution: build from source or direct download (ad-hoc signed). Not sandboxed yet; avoid APIs that would block future sandboxing (use `NSOpenPanel`/`NSSavePanel`, app-container paths) | 1 |
| NF-11 | Versioning per §9 | 1 |

## 9. Versioning

| ID | Req |
|---|---|
| VER-1 | Semantic version `MAJOR.MINOR.PATCH` stored in the repo-root `VERSION` file: a single line, nothing else |
| VER-2 | Build number = number of commits reachable from `HEAD` (`git rev-list --count HEAD`); derived, never stored in source, so it can't drift |
| VER-3 | Each release is an annotated git tag `v<VERSION>` (e.g. `v0.1.2`) on the commit that sets `VERSION` |
| VER-4 | `./version.sh` prints machine-readable values: `version`, `build`, `tag`, `full` (`0.1.2+42`), `json` |
| VER-5 | `build.sh` writes version and build into the app bundle (`CFBundleShortVersionString`, `CFBundleVersion`); the app reads them from `Bundle.main` (About panel, future update checks) |
| VER-6 | Builds outside a git checkout get build number `0` |

## 10. Future

- Built-in region/window/screen capture with global hotkey.
- Menu-bar mode.
- Sandboxing, notarization, universal (x86_64) build.
- Annotation templates/presets.
- Customizable shortcuts and palette (would need a Settings UI).
- Window controls in the title bar instead of the status bar.
- Update checks using VER-4/VER-5.
- PDF page import.
