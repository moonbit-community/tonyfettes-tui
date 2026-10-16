///|
/// Paint wrapped, styled content in a rounded popup anchored to a screen cell.
/// Prefer below the anchor, otherwise above; the anchor itself stays visible.
/// The popup is clipped to `bounds` and the frame. Returns its actual area, or
/// `None` when the anchor is outside the bounds or a border cannot fit.
///
/// Default content colors inherit `style`; explicit line colors are preserved.
/// Keep `scroll` in application state and move it when a wheel event lands in
/// the returned area. Repaint the underlying view before drawing the popup.
pub fn popup(
  frame : Frame,
  lines : ArrayView[Line],
  bounds~ : Rect,
  anchor~ : Cursor,
  scroll? : Scroll,
  style~ : Style = Style(),
  border_style~ : Style = style,
  max_width~ : Int32 = 72,
  max_height~ : Int32 = 12,
) -> Rect? {
  let bounds = bounds.intersect(frame.area())
  let width = bounds.width.min(max_width)
  guard !lines.is_empty() &&
    width >= 5 &&
    max_height >= 3 &&
    anchor.row >= bounds.row &&
    anchor.row < bounds.row + bounds.height &&
    anchor.col >= bounds.col &&
    anchor.col < bounds.col + bounds.width else {
    return None
  }
  let wrapped = lines
    .iter()
    .flat_map(line => line.wrap(width - 4).iter())
    .collect()
  let width = (wrapped.fold(init=1, (width, line) => width.max(line.width())) +
  4).min(width)
  let height = (wrapped.length() + 2).min(max_height)
  let above = anchor.row - bounds.row
  let below = bounds.row + bounds.height - anchor.row - 1
  let down = below >= height || below >= above
  let height = height.min(if down { below } else { above })
  guard height >= 3 else { return None }
  let area = Rect(
    row=if down { anchor.row + 1 } else { anchor.row - height },
    col=anchor.col.clamp(min=bounds.col, max=bounds.col + bounds.width - width),
    width~,
    height~,
  )
  frame.fill(area, style~)
  frame.text(
    row=area.row,
    col=area.col,
    "╭" + "─".repeat(area.width - 2) + "╮",
    style=border_style,
  )
  frame.text(
    row=area.row + area.height - 1,
    col=area.col,
    "╰" + "─".repeat(area.width - 2) + "╯",
    style=border_style,
  )
  for row in (area.row + 1)..<(area.row + area.height - 1) {
    frame.text(row~, col=area.col, "│", style=border_style)
    frame.text(row~, col=area.col + area.width - 1, "│", style=border_style)
  }
  let content = wrapped.map(line => {
    let glyphs = line
      .glyphs()
      .map(glyph => {
        let colors = glyph.style
        {
          ..glyph,
          style: {
            ..colors,
            fg: if colors.fg is Default {
              style.fg
            } else {
              colors.fg
            },
            bg: if colors.bg is Default {
              style.bg
            } else {
              colors.bg
            },
          },
        }
      })
    Line::from_glyphs(glyphs)
  })
  frame.lines(
    Rect(
      row=area.row + 1,
      col=area.col + 2,
      width=area.width - 4,
      height=area.height - 2,
    ),
    content,
    scroll?,
  )
  Some(area)
}
