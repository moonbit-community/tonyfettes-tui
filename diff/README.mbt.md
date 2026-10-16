# Diff viewer

`moonbit-community/tui/diff` displays read-only differences between two source
snapshots. It uses `moonbit-community/moondiff` for line alignment and keeps
both unified rows and aligned split rows until the snapshots change. Drawing
only highlights the visible source rows.

```mbt check
///|
test "draw an aligned source comparison" {
  let view = @diff.DiffView("first\nold 🌙\nlast", "first\nnew 中文\nlast")
  let frame = @tui.Frame(width=81, height=8)
  view.draw(
    frame,
    frame.area(),
    mode=Split,
    original_label="Before",
    modified_label="After",
  )
  assert_true(frame.to_text().contains("2 old 🌙"))
  assert_true(frame.to_text().contains("2 new 中文"))
}
```

`Mode::Unified` is the default. `Mode::Split` puts original and modified lines
side by side with source line numbers and blank cells for one-sided changes.
Both sides share one scroll position. Split mode falls back to unified below
forty columns. Lines clip horizontally rather than wrapping, so corresponding
source rows stay aligned. Pane bounds are clipped to the frame before layout,
scroll limits, and mouse hit testing are recorded.

The default context is three unchanged lines around each hunk. Pass `context`
to the constructor to change it; negative values are treated as zero. Identical
snapshots display `No changes.`. LF and CRLF retain their original line indices;
CRLF's carriage return is removed only from displayed text, not from comparison.
A change in line endings therefore remains a change. An entirely empty snapshot
has zero source lines, so whole-file additions and deletions use zero-length
hunk ranges for the empty side.

## Input and changing snapshots

Call `mouse` with the terminal's one-based screen coordinates after `draw` has
recorded the pane. It consumes vertical wheel events inside the body and scrolls
three rows per event. Events outside the body, clicks, and horizontal wheel
events remain available to the application.

Route keys to `navigate` while the diff has focus. It handles Up/Down,
PageUp/PageDown, and Home/End, and returns other keys unused. `scroll_by` supports
application-controlled scrolling. Scroll limits and page height come from the
last draw; `offset` exposes the first visible body row.

```mbt check
///|
test "browse a diff and replace its snapshots" {
  let view = @diff.DiffView("before", "after")
  let frame = @tui.Frame(width=50, height=3)
  view.draw(frame, frame.area())
  assert_true(view.navigate(@input.KeyEvent::new(Down)))
  assert_eq(view.offset(), 1)
  view.set_sources("same", "same")
  assert_eq(view.offset(), 0)
}
```

`set_sources` recomputes the cached diff and returns to the top when either
snapshot changes. Supplying the same pair preserves the cache and position.
Switching display mode preserves the displayed row offset and clamps it to the
new extent on the next draw.

## Styling

Pass a `Theme` to set unchanged text, added/removed rows, hunk headings, labels,
and the separator independently. The optional `highlight` callback receives one
source line without its diff prefix or line number, plus its base diff style.
Return styled spans with that base background to keep change coloring. The
callback is not invoked for labels, hunk headings, or offscreen rows.

The module compares supplied strings. File loading, repository baselines,
processes, diagnostics, and syntax tokenization belong to its caller.
