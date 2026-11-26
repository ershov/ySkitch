# ySkitch — Requirements

Status: final v1.16 · 2026-11-26

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
| IMG-4 | Canvas = image rect (or crop rect, which may extend beyond the image) ∪ bounds (incl. outline, where drawn) of annotations that extend the canvas. An annotation extends the canvas once it is drawn or edited (moved, resized, restyled); cropping resets this for all existing annotations. Extends in any direction while drawing/dragging; area without image pixels is white. Shrinks only on mouse-up, never smaller than the image/crop rect. Annotation parts outside the canvas are not rendered | U | 1 |
| IMG-5 | Export and clipboard output preserve scale: pixel data at the output scale (IMG-7), point size set so pasted images appear at the correct size in other apps | U | 1 |
| IMG-6 | Rendering order, bottom to top: (1) base image, clipped to the crop, white elsewhere; (2) all pixelates in document order, each sampling the base image only; (3) all highlighter strokes as one shared layer at 40 % opacity; (4) all other annotations in document order; (5) clipped to the canvas. Hit testing and selection follow the same order (topmost first) | U | 1 |
| IMG-7 | Output scale @1x / @2x / @3x (status bar pop-up, Image menu); initially the image's scale. Output pixels per point: copy, save and drag render at it, the base image resampled at render time. Non-destructive: the original pixels stay, switching back restores full quality. Annotations are in points and keep size and position. Canvas and crop snap outward to the new pixel grid. One undo step "Change Scale". Menu items are disabled during a gesture, crop session or text editing; the pop-up is disabled during a crop session and commits an open text edit. The canvas shows the output: when the output scale is below the screen's backing scale (e.g. @1x on a Retina screen), the canvas draws the output's pixels scaled up at every zoom; otherwise it draws directly | U | 1 |

## 5. Functional requirements

### 5.1 Input

| ID | Req | Src | Stage |
|---|---|---|---|
| IN-1 | On launch, a new window is created. A new window (launch or `⌘N`) uses the clipboard image if one is present, otherwise a blank canvas | U | 1 |
| IN-2 | `⌘⇧N`: new blank canvas, 800×600 pt, white | U | 1 |
| IN-3 | Open image file (PNG, JPEG, HEIC, GIF first frame, TIFF, BMP, WebP) via `⌘O` | U | 1 |
| IN-4 | Open via drag-and-drop onto window / app icon / Dock | S | 1 |
| IN-5 | Open via "Open With…" and `open -a ySkitch file.png`; command line per §5.9 | S | 2 |
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
| WIN-5 | New window sized to fit image plus a 60 pt margin on each side (`WindowSizing.margin`), capped to screen; opens in Fit mode (VIEW-2), i.e. at 100 % when the image fits, else smaller | S | 1 |
| WIN-6 | Standard macOS app lifecycle: app keeps running with no windows; no special handling | U | 1 |

Window state is never written to disk, so unredacted originals of closed windows don't outlive the process.

### 5.4 Canvas and view

| ID | Req | Src | Stage |
|---|---|---|---|
| VIEW-1 | Trackpad: two-finger pinch zooms around the gesture point; two-finger swipe pans; smart-zoom (two-finger double-tap): not at 100 % → 100 % (Fit mode off); at 100 % → Fit mode on. Pinch turns Fit mode off | U | 1 |
| VIEW-2 | Keyboard/mouse zoom: `⌘+`/`⌘-`, `⌘`+scroll wheel (up zooms in, down zooms out, regardless of the natural-scrolling setting; like `⌃`-scroll in macOS Accessibility Zoom), Actual size (`⌘0`), Fit (`⌘9`), zoom slider (click the status-bar percentage: pop-up with a vertical logarithmic slider, 500 % at the top, 100 % in the middle, 20 % at the bottom, no snapping; zooms live around the visible center; double-click anywhere in the panel → 100 %; zoom outside 20–500 % pins the knob at the nearest end and stays until the slider is moved; the panel is placed like a pop-up menu, see §6.1); holding space pans with mouse movement, no click needed (space acts like a mouse button) | U | 1 |
| VIEW-2a | Fit is a persistent mode toggled by `⌘9` and the status-bar `Fit` button (two-state; its pressed state is the only indicator). On: zooms to fit immediately and keeps the canvas fitted and centered on window/viewport resize and on canvas size change (IMG-4, crop, IN-8, IMG-7, undo/redo); not live during a drag or crop session, re-fit on commit. Off (button/`⌘9` again): zoom stays. Any user zoom (pinch, `⌘+`/`⌘-`, `⌘`-scroll, zoom slider, Actual size, 1:1, smart zoom to 100 %) turns it off; scrolling/panning does not. Fit never exceeds 100 % and leaves a margin of `min(WindowSizing.margin, 10 % of the viewport's smaller side)` on each side. New windows start in Fit mode; reopened windows (WIN-4) restore the mode | U | 1 |
| VIEW-3 | Correct HiDPI rendering; at 100% one image pixel maps to one device pixel for images whose scale matches the screen | U | 1 |
| VIEW-4 | Manually extend canvas (add margin) | S | 3 |
| VIEW-5 | Rotate 90° / flip | S | 3 |

### 5.5 Annotation tools

All annotations are vector objects, editable until export (flattened only on output).

| ID | Tool | Details | Src | Stage |
|---|---|---|---|---|
| T-1 | Arrow | Skitch-style tapered arrow; head scales with thickness; short arrows narrow proportionally so they keep the arrow shape | U | 1 |
| T-2 | Text | Multiline; editable after creation; thickness slider sets font size. With the Text tool and no text being edited: a click on any annotation selects it (press-drag moves it, handles resize, `⌘`-drag copies, as in the Select tool); a double-click on text edits it (ED-7); a click on empty space clears the selection and starts new text | U | 1 |
| T-3 | Rectangle | Outline | U | 1 |
| T-3a | Fill for rectangle, rounded rectangle, ellipse (needs sketch update) | S | 2 |
| T-4 | Rounded rectangle | Radius scales with thickness | U | 1 |
| T-5 | Ellipse | Outline | U | 1 |
| T-6 | Line | Straight segment | U | 1 |
| T-7 | Freehand pen | Stroke smoothing. `⇧` straightens the stroke (KEY-1). A click without a drag on empty space draws a dot (ED-1) | U | 1 |
| T-8 | Highlighter | Semi-transparent (40 % opacity, normal blend), round tip. `⇧` straightens the stroke (KEY-1). All strokes share one layer (IMG-6): overlaps, within a stroke or between strokes, highlight once; where colors overlap, the later stroke's color shows. A click without a drag on empty space draws a dot (ED-1) | U | 1 |
| T-9 | Crop | Handles (`⌥` resizes around the center, `⇧` keeps the aspect ratio, per KEY-4/KEY-2); `⌥` while drawing a new crop rect draws it from the center; non-destructive (re-croppable); Enter applies, Esc cancels. The rect may extend beyond the image in any direction (white padding); the canvas grows while dragging to show it. Double-click proposes the current image (the canvas before the session). Status bar coordinates are relative to the current image (the canvas before the session). Discards image pixels outside the crop rect. Existing annotations stay as objects; parts outside the crop are hidden until the annotation is edited, which extends the canvas per IMG-4 | U | 1 |
| T-10 | Pixelate | Region; destructive in output; thickness slider sets block size. Redacts image pixels only: annotations are never pixelated and always render above (IMG-6) | U | 1 |
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
| ST-1 | **Double outline (key feature):** text is rendered with an inner white outline and an outer soft dark halo (omnidirectional shadow: zero offset, ~2 pt blur, ~50% black), so it is visible on any background. Arrows, lines, rectangles, rounded rectangles, ellipses and pen strokes are drawn plain (fill / stroke in their color); an internal switch (`OutlineStyle.outlinesShapes`, off) restores the outline on them, no user-visible option. Not applied to highlighter, pixelate, blur, redact, crop | U | 1 |
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
| ED-1 | Select tool; click/marquee select; `⇧`-click multi-select, `⇧`-marquee adds. A marquee selects annotations whose drawn geometry it touches (stroke incl. thickness; filled area of arrows, text boxes and pixelate), not their bounds. In every tool, a right-drag or `⌃`-drag draws a marquee that adds the touched annotations to the selection (`⌥`: removes them); not during a crop session or text editing; a right-click or `⌃`-click without a drag does nothing. In every drawing tool except Text and Crop, a click without a drag selects the topmost annotation under the cursor; on empty space it clears the selection and creates nothing; if nothing was selected, Pen and Highlighter instead draw a dot (a stroke of two coincident points, diameter = thickness; sub-threshold jitter is discarded); the tool stays active. A drag in the Arrow, Line, Rectangle, Rounded rectangle, Ellipse or Pixelate tool creates an annotation that becomes the selection (replacing the previous one); Pen, Highlighter and Text leave nothing selected after drawing. Selection indicator: lines, arrows and straight pen/highlighter strokes (exactly two distinct points) show a 1 px accent line start → end; freehand pen/highlighter strokes show their bounds rectangle plus a 1 px accent line along the stroke; other annotations show their bounds rectangle | S | 1 |
| ED-2 | Move, resize, endpoint drag (lines/arrows, straight pen/highlighter strokes). In the drawing tools of ED-1, a press on a handle of the selected annotation or on a selected annotation (topmost under the cursor) moves/resizes it as in the Select tool; a press elsewhere draws. A dot shows a single bottom-right handle; dragging it stretches the dot into a straight stroke from the dot to the cursor, after which it is a straight stroke with endpoint handles. `⌥` while resizing/dragging an endpoint: see KEY-4; `⌥` does not affect moves | S | 1 |
| ED-3 | Delete (`⌫`), duplicate (`⌘D`), copy/paste objects between windows (`⌘V` centers the pasted group on the cursor if it is over the canvas area of the window, else on the center of the visible canvas; clamped so the canvas does not grow, unless the group is larger than the canvas; within 10 pt of the original position or of an earlier paste of the same clipboard content it lands there and cascades by 10 pt while it would coincide with an existing annotation, which may extend the canvas; a new copy resets this); `⌘`-drag on an annotation (Select tool, or a selected annotation in a drawing tool) moves a copy of it (of the whole selection if it is selected) and selects the copy; `Esc` cancels; a `⌘`-click without a drag creates nothing; one undo step | S | 1 |
| ED-4 | Nudge with arrow keys (1 pt; `⇧` = 20 pt); consecutive nudges are one undo step | S | 1 |
| ED-5 | Z-order: bring to front / send to back | S | 2 |
| ED-6 | Unlimited undo/redo (`⌘Z` / `⌘⇧Z`) per document | S | 1 |
| ED-7 | Double-click text to edit (Select and Text tools). While editing, presses inside the text go to the text view (caret, drag-select, word/line select) without committing; presses outside commit; the edited text is drawn above all other annotations | S | 1 |

### 5.8 Modifiers and shortcuts

| ID | Req | Src | Stage |
|---|---|---|---|
| KEY-1 | `⇧` while drawing line/arrow: constrain to 45° steps. `⇧` while drawing pen/highlighter: replace the stroke with a straight segment from its start to the cursor, 45° steps while held; after release it stays straight and follows the cursor freely (pressing `⇧` again re-applies 45°) | U | 1 |
| KEY-2 | `⇧` while drawing rect/ellipse: square/circle; while resizing by a bounds handle: keep the aspect ratio (corner: uniform scale; edge: the other axis scales around the center line; no effect on zero-extent shapes; line/arrow/straight-stroke endpoints keep KEY-1); while moving or `⌘`-dragging a copy: constrain axis | S | 1 |
| KEY-3 | `⌥` while drawing arrow: reverse direction (head at start point) | U | 1 |
| KEY-4 | `⌥` while drawing rect/rounded rect/ellipse/pixelate or a new crop rect: draw from the center (the press point), combines with `⇧` for a centered square/circle. `⌥` while resizing: resize around the center (bounds handles: the opposite side mirrors the move; line/arrow/straight-stroke endpoints: the other endpoint mirrors around the midpoint, 45° with `⇧` measured around the midpoint; a dot stretches symmetrically). Modifiers toggle live mid-drag | S | 2 |
| KEY-5 | Single-key tool shortcuts (V select, T text, A arrow, L line, R rect, U rounded rect, O ellipse, P pen, H highlighter, X pixelate, C crop) | S | 1 |
| KEY-6 | Number keys `1`–`8` select palette color; `[` / `]` step the thickness slider down / up; `⇧[` / `⇧]` step the value by 0.5 pt | S | 1 |
| KEY-7 | `Esc` cancels current operation, otherwise deselects (every tool) | S | 1 |
| KEY-8 | Every function has a menu item showing its shortcut (menus below) | U | 1 |
| KEY-9 | Right-drag or `⌃`-drag in any tool: marquee adds to the selection; with `⌥` removes from it (ED-1) | U | 1 |

#### Menus

- **ySkitch:** About · Hide `⌘H` · Hide Others `⌥⌘H` · Show All · Quit `⌘Q`
- **File:** New `⌘N` · New Blank `⇧⌘N` · Open… `⌘O` · Reopen Closed Window `⇧⌘T` (disabled with empty history) · Save `⌘S` · Save As… `⇧⌘S` · Close `⌘W`
- **Edit:** Undo `⌘Z` · Redo `⇧⌘Z` · Cut `⌘X` · Copy `⌘C` · Copy Image `⇧⌘C` · Paste `⌘V` · Duplicate `⌘D` · Delete (`⌫` on the canvas) · Select All `⌘A` · Nudge ▸ Left `←` · Right `→` · Up `↑` · Down `↓` (`⇧` alternates: 20 pt; need a selection)
- **Tools** (single keys, no modifiers):
  - Tools in toolbar groups, checkmark on the active one: Select `V` · Text `T` · Arrow `A`, Line `L`, Rectangle `R`, Rounded Rectangle `U`, Ellipse `O` · Pen `P`, Highlighter `H` · Pixelate `X` · Crop `C`
  - Color ▸ Red `1` … Black `8` (§6.3), checkmark on the shown color; disabled when the tool or selection has no color
  - Thinner `[` · Thicker `]` · Slightly Thinner `⇧[` · Slightly Thicker `⇧]`; disabled without a thickness
  - Apply Crop `↩` · Cancel Crop `Esc`; enabled only during a crop session
- **Image:** Scale @1x `⌥⌘1` · Scale @2x `⌥⌘2` · Scale @3x `⌥⌘3` (IMG-7); checkmark on the current scale; disabled during a gesture, crop session or text editing
- **View:** Zoom In `⌘+` (also `⌘=`) · Zoom Out `⌘-` · Actual Size `⌘0` · Zoom to Fit `⌘9` · Enter Full Screen `⌃⌘F`
- **Window:** Minimize `⌘M` · Zoom · Bring All to Front

Single keys go to the focused view first: the canvas handles them, and while a text annotation is edited they are typed into it. Clicking a Tools item works like clicking the toolbar.

### 5.9 Command line

The app binary (`ySkitch.app/Contents/MacOS/ySkitch`, run directly or through a symlink in `PATH`) is a command-line launcher. Finder, Dock and `open` launches keep standard macOS behavior.

| ID | Req | Src | Stage |
|---|---|---|---|
| CLI-1 | Started from a shell (parent process is not launchd), the binary only hands the request to the app and exits; the app is not tied to the terminal. It finds the `.app` through its resolved executable path (symlinks followed) and reads version and bundle identifier from that bundle's `Info.plist` | U | 2 |
| CLI-2 | No arguments: start the app (IN-1 window), or bring a running one to the front without opening a window | U | 2 |
| CLI-3 | `FILE …`: one new window per file, in argument order; repeats open repeated windows. Relative paths resolve against the shell's working directory | U | 2 |
| CLI-4 | `--clipboard`: a new window from the clipboard image, in its place among the files; repeatable. No image on the clipboard: nothing opens | U | 2 |
| CLI-5 | `-`: one window from an image read from standard input, titled like a clipboard image. Given more than once, or with nothing piped in (terminal), is a usage error | U | 2 |
| CLI-6 | `--`: all following arguments are files | U | 2 |
| CLI-7 | `--quit`: quit the running app; nothing running is success | U | 2 |
| CLI-8 | `--help`: usage to stdout; `--version`: `VERSION+build` (VER-4 `full`) to stdout. Both exit 0 without starting the app | U | 2 |
| CLI-9 | Usage errors (unknown option, repeated `-`, `--quit`/`--version` combined with other arguments, `-` on a terminal): message and a `--help` hint to stderr, exit 2, the app is not touched | S | 2 |
| CLI-10 | File problems (missing, folder, unreadable, empty, not an image; same for standard input): the launcher prints each to stderr and exits 1, but still forwards everything. The app opens what it can and shows one alert per invocation listing all problems — a sheet on the newest window, app-modal only without windows | U | 2 |
| CLI-11 | Fresh launch with arguments opens only the requested windows; if none opened (no clipboard image, only bad files), the IN-1 window opens so the app never starts without a window | S | 2 |
| CLI-12 | Running app: the request goes as a distributed notification, re-posted until acknowledged (the app may still be launching); then the app is activated through LaunchServices. No acknowledgement within 10 s: "not responding" to stderr, exit 1 | S | 2 |

Exit codes: 0 success · 1 file problems or the app didn't respond · 2 usage error.

## 6. UI

- Left-side toolbar, Skitch-style, in two columns: tools · colors with the thickness slider below them. No column headings.
- Every toolbar item shows its keyboard key right next to it, bottom-aligned with the icon or swatch (e.g. a small `A` at the bottom right of the arrow icon). Icons only, no tool names.
- With an object selected, color/thickness controls reflect and edit it. With several selected, they show the last selected object (most recently added to the selection).
- Controls that do not apply to the current tool (colors, thickness slider) are dimmed and disabled, never hidden.
- Icons: SF Symbols or code-drawn; no external assets.
  - Arrow, Line, Rect, Rounded rect, Ellipse: code-drawn with a 3.4 pt stroke (twice the SF Symbol regular stroke); the rectangle has square corners.
  - Text: "Aa" in the text annotation font (bold system font).
  - Other tools: SF Symbols.
- Canvas surround is the system under-page background color (`CanvasStyle.surroundColor`; light grey in light mode, dark grey in dark mode, never pure white), so it follows light/dark mode. The canvas has a soft drop shadow (black 25 %, blur 6 pt, 1 pt down), constant on screen regardless of zoom.
- Design reference: `docs/toolbar-design.png` (light mode, 1× points).
- **No UI is implemented or changed without the user confirming the sketch first.**

### 6.1 Document window

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●                        Screenshot 2026-11-24 at 10.15                              │
├──────────────┬───────────────────────────────────────────────────────────────────────────┤
│ ➤V     ●1    │                                                                           │
│        ●2    │              ┌──────────────────────────────────────────────┐             │
│ AaT    ●3    │              │                                              │             │
│        ●4    │              │                                              │             │
│ ↗A     ●5    │              │                                              │             │
│ ╱L     ◉6    │              │                                              │             │
│ ▭R     ○7    │              │             image + annotations              │             │
│ ▢U     ●8    │              │                (white canvas)                │             │
│ ◯O           │              │                                              │             │
│        ███   │              │                                              │             │
│ ✎P     ███   │              │                                              │             │
│ ▬H      ┃    │              │                                              │             │
│         ┃    │              └──────────────────────────────────────────────┘             │
│ ▦X     ━●━   │                                                                           │
│         │    │               (canvas surround: CanvasStyle.surroundColor)                │
│ ⌗C      ╷    │                                                                           │
├──────────────┴───────────────────────────────────────────────────────────────────────────┤
│ 2880×1800 px · 1440×900 pt  @2x ⌄       [⠿ Drag]                    1:1  Fit   −  100%  + │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Tools column**, grouped with extra spacing between groups:
  1. Select (`V`)
  2. Text (`T`)
  3. Arrow (`A`), Line (`L`), Rect (`R`), Rounded rect (`U`), Ellipse (`O`)
  4. Pen (`P`), Marker/highlighter (`H`)
  5. Pixelate (`X`) — later also Blur, Redact
  6. Crop (`C`)

  Later tools join the nearest group: step markers, stamps, callouts → after Text; arrow variants → shapes group.
- **Color column**: 8 palette swatches, keys `1`–`8`, selected one ringed (`◉`); `+` (custom color) comes in Stage 2. Swatch: colored circle with a 4 pt white outline and a thin dark outer edge.
- **Thickness slider**: below the swatches after a spacer, centered in the whole color column; its bottom is level with the last tool row, the spacer absorbs the difference. No `[` / `]` labels. See §6.2.
- **Status bar**: left — image size (`2880×1800 px · 1440×900 pt`) or element info (below), then the output scale pop-up (IMG-7): borderless, label font, `@1x` / `@2x` / `@3x` with the current one checked; always visible, the label truncates before it; center — drag handle (OUT-4); while the thickness slider is dragged, left shows its value instead (§6.2); right, in order — `1:1` (actual size, `⌘0`), `Fit` (`⌘9`, two-state toggle), zoom `−` / percentage / `+`. The percentage is a borderless button (hover highlight, tooltip "Zoom — double-click the slider for 100 %"); click opens the zoom slider (VIEW-2): a borderless panel, child of the document window, ~200 pt tall, with `500%` / `100%` / `20%` labels and a tick at 100 %. It is positioned like a pop-up menu: the knob with its value label (live zoom) sits exactly over the status-bar percentage, the panel may extend below the window and shifts vertically to fit the screen otherwise (alignment is then lost). Interaction like a menu: click keeps it open for dragging the knob; press-drag-release on the percentage drags immediately and closes on release; closes on click outside, `Esc` or when the window loses focus.
  - **Element info** replaces the image size while an element is drawn, moved, resized, nudged or selected, and while a text is edited, a crop session is open or a selection marquee is dragged; it updates live. Priority: element being drawn (or crop rect / marquee), else edited text, else selection, else image size.
  - Fields are `·` separated integers; `px` = image pixels:
    - Arrow, Line, straight Pen/Highlighter stroke (exactly two distinct points; name stays Pen/Highlighter): `Arrow · (x1, y1) → (x2, y2) · L px · θ° · T pt` — start (arrow tail) → end (head), length, angle (0° = pointing right, counter-clockwise positive on screen, −179…180), stroke width.
    - Rectangle, Rounded Rectangle, Ellipse: `Rectangle · (x1, y1) → (x2, y2) · W×H px · T pt` — while drawing: corner opposite the cursor → cursor corner; otherwise top-left → bottom-right.
    - Pixelate: as Rectangle; last field = block size.
    - Pen, Highlighter (freehand strokes and dots): `Pen · (x1, y1) → (x2, y2) · W×H px · T pt` — bounding box of the stroke points.
    - Text: `Text · (x1, y1) → (x2, y2) · W×H px · 24 pt` — text box; last field = font size.
    - Crop session: `Crop · (x1, y1) → (x2, y2) · W×H px`.
    - Select marquee (also right-drag / `⌃`-drag marquee): `Select · (x1, y1) → (x2, y2) · W×H px`.
    - Several selected: `3 objects · (x1, y1) → (x2, y2) · W×H px` — union of their geometry boxes.
  - Coordinates: image pixels (points × scale, rounded) relative to the current canvas top-left, y down; negative beyond the top/left edge. Geometry is the model geometry (rect, endpoints, points), not render bounds. Sizes are in pt as on the thickness slider (`4 pt`, `4.5 pt`). Names are the tool names.
- Title: source file name, else `ySkitch <date> at <time>` (same as the default export file name, DEF-8).

**Dimensions** (points):

| Item | Size |
|---|---|
| Toolbar width | 140 (10 side padding, 10 top padding) |
| Tool / swatch row height | 36; group gap 14 |
| Tool button (highlight) width | 48 |
| Tool icon | 21 pt symbol in a 24 pt box; key label 12 pt monospaced, 1 pt after the icon |
| Column gap (tools → colors) | 18 |
| Color column width | 54 |
| Swatch | 27 circle in a 33 frame (selection ring at the frame edge) |
| Palette → slider spacer | derived: tool rows height − swatches − slider height (4 today), at least 4; below that the color column grows |
| Slider travel | 135 (sample centers, minimum to maximum), the same for every tool |
| Slider paddings | top 27, bottom 12: the largest half end-sample over all tools, at least 12 (§6.2); slider height = top + travel + bottom = 174 |
| Status bar | 40 high; 13 pt text; regular-size buttons; drag handle 110×26 |

### 6.2 Thickness slider

| Tool | Meaning | Range | Default |
|---|---|---|---|
| Arrow, Line, Rect, Rounded rect, Ellipse, Pen | Stroke width | 1–40 pt | 4 pt |
| Marker (highlighter) | Stroke width | 4–60 pt | 20 pt |
| Text | Font size | 10–120 pt | 24 pt |
| Pixelate | Block size | 2–40 pt | 10 pt |
| Blur (later) | Radius | 2–40 pt | 10 pt |

- While the slider is dragged (mouse-down to mouse-up, not `[` / `]`), the status bar's left label shows `<Tool> · <Meaning> <value> pt` (e.g. `Arrow · Width 12 pt`, `Text · Font size 36 pt`), updating live, for the shown style tool (the selection's tool when editing a selection); afterwards it returns to the normal content.
- Logarithmic mapping, so small sizes get finer control. Top = maximum, bottom = minimum.
- With several objects selected, the slider position applies per object: each gets the value at that position in its own tool's range (e.g. top of the range: arrow 40 pt, text 120 pt).
- `[` / `]` move the slider by 1/20 of its range (logarithmic steps); `⇧[` / `⇧]` change the value by 0.5 pt (the slider granularity), clamped to the tool's range. Both apply to the selection if any, else to the current tool; no slider-drag status label.
- Ranges and defaults are named constants in code.
- Travel is fixed for all tools, so the same y is the same position for every tool. The wedge spans the travel only; the paddings above and below stay empty except for the sample, but are part of the control: clicks and drags there clamp to the ends.
- Paddings are the largest half end-sample over all tools with a range (width clamped at the column width): top from the maxima, bottom from the minima; each at least 12 pt so clicks just beyond an end are easy to hit. Adding a tool may increase paddings, never changes travel.
- The track is a true size scale: at each slider position its drawn width equals the value at that position (clamped at the column width), so its outline is an exponential curve.
- Layers, bottom to top:
  1. Width curve fill (light grey).
  2. Indicator line at the current position across the full slider width; same stroke as the shape icons (3.4 pt), label color with a thin white halo.
  3. Sample at real size, clipped to the slider bounds, with a white ring and a thin dark outer edge (like the swatches):
     - stroke tools, Pen: circle, diameter = thickness, current color;
     - Marker: circle, diameter = thickness, current color at highlighter opacity;
     - Text: rounded square, side = font size, filled with the current color, a bold lowercase "a" (black or white for contrast) on it, centered on the indicator line;
     - Pixelate: square, side = block size, system foreground (label) color.
  4. Width curve outline.
- Big samples cover the indicator line; for small sizes the line shows the position.

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
| DEF-12 | Double outline | Text only (internal switch for shapes, off) | — |
| DEF-13 | Palette | Fixed, §6.3 | — |
| DEF-14 | Style edits of a selection (color, thickness; every input method) | Each edited annotation's resulting color (color-using tools only) and clamped thickness become its tool's default; move, resize, nudge, delete do not | Per tool |

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
