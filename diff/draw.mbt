///|
fn styled_source(
  prefix : String,
  text : String,
  style : @tui.Style,
  highlight : ((String, @tui.Style) -> Array[@tui.Span])?,
) -> @tui.Line {
  let content = if highlight is Some(highlight) {
    @tui.Line(highlight(text, style))
  } else {
    @tui.Line::from_text(text, style~)
  }
  @tui.Line::from_text(prefix, style~).concat(content)
}

///|
fn row_area(area : @tui.Rect, row : Int32) -> @tui.Rect {
  @tui.Rect(row=area.row + row, col=area.col, width=area.width, height=1)
}

///|
fn draw_source(
  frame : @tui.Frame,
  area : @tui.Rect,
  line : SourceLine?,
  style : @tui.Style,
  highlight : ((String, @tui.Style) -> Array[@tui.Span])?,
) -> Unit {
  if line is Some(line) {
    frame.fill(area, style~)
    frame.line(
      area,
      styled_source("\{line.number} ", line.text, style, highlight),
    )
  }
}

///|
/// Paint the visible diff rows. Lines are clipped horizontally rather than
/// wrapped, preserving alignment. Split mode uses synchronized, aligned rows
/// and falls back to unified below forty columns. Changing format preserves
/// the displayed row offset, clamped to the new format's extent.
///
/// The optional highlighter receives the source text and its diff style;
/// return spans retaining that style's background to preserve change coloring.
pub fn DiffView::draw(
  self : DiffView,
  frame : @tui.Frame,
  area : @tui.Rect,
  mode~ : Mode = Unified,
  theme~ : Theme = Theme(),
  original_label~ : String = "Original",
  modified_label~ : String = "Modified",
  highlight? : (String, @tui.Style) -> Array[@tui.Span],
) -> Unit {
  let split = mode is Split && area.width >= 40
  let body = @tui.Rect(
    row=area.row + 1,
    col=area.col,
    width=area.width,
    height=(area.height - 1).max(0),
  )
  self.area = body
  self.height = body.height
  self.count = if split { self.split.length() } else { self.unified.length() }
  self.offset = self.offset.clamp(min=0, max=(self.count - self.height).max(0))
  guard area.height > 0 && area.width > 0 else { return }
  frame.fill(area, style=theme.text)
  if !split {
    frame.fill(row_area(area, 0), style=theme.label)
    frame.line(
      row_area(area, 0),
      @tui.Line::from_text(
        "\{original_label} → \{modified_label}",
        style=theme.label,
      ),
    )
    if self.unified.is_empty() {
      frame.line(body, @tui.Line::from_text("No changes.", style=theme.text))
    }
    for row in 0..<body.height {
      guard self.unified.get(self.offset + row) is Some(line) else { break }
      let style = match line.kind {
        Context => theme.text
        Added => theme.added
        Removed => theme.removed
        Hunk => theme.hunk
      }
      let target = row_area(body, row)
      frame.fill(target, style~)
      frame.line(
        target,
        if line.kind is Hunk {
          @tui.Line::from_text(line.text, style~)
        } else {
          styled_source(line.prefix, line.text, style, highlight)
        },
      )
    }
    return
  }
  let left_width = (area.width - 1) / 2
  let left = @tui.Rect(
    row=area.row,
    col=area.col,
    width=left_width,
    height=area.height,
  )
  let right = @tui.Rect(
    row=area.row,
    col=area.col + left_width + 1,
    width=area.width - left_width - 1,
    height=area.height,
  )
  frame.fill(row_area(left, 0), style=theme.label)
  frame.fill(row_area(right, 0), style=theme.label)
  frame.line(
    row_area(left, 0),
    @tui.Line::from_text(original_label, style=theme.label),
  )
  frame.line(
    row_area(right, 0),
    @tui.Line::from_text(modified_label, style=theme.label),
  )
  for row in 0..<area.height {
    frame.text(
      row=area.row + row,
      col=area.col + left_width,
      "│",
      style=theme.separator,
    )
  }
  if self.split.is_empty() {
    frame.line(body, @tui.Line::from_text("No changes.", style=theme.text))
  }
  for row in 0..<body.height {
    guard self.split.get(self.offset + row) is Some(line) else { break }
    match line {
      Header(text) => {
        let target = row_area(body, row)
        frame.fill(target, style=theme.hunk)
        frame.line(target, @tui.Line::from_text(text, style=theme.hunk))
      }
      Cells(old, new) => {
        draw_source(
          frame,
          row_area(left, row + 1),
          old,
          if old is Some({ changed: true, .. }) {
            theme.removed
          } else {
            theme.text
          },
          highlight,
        )
        draw_source(
          frame,
          row_area(right, row + 1),
          new,
          if new is Some({ changed: true, .. }) {
            theme.added
          } else {
            theme.text
          },
          highlight,
        )
      }
    }
  }
}
