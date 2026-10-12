///|
/// A place in a list of lines: a line and a glyph within it. `glyph` may equal
/// the line's glyph count, meaning just past its end.
priv struct Position {
  line : Int32
  glyph : Int32
}

///|
fn Position::before(self : Position, other : Position) -> Bool {
  self.line < other.line ||
  (self.line == other.line && self.glyph < other.glyph)
}

///|
/// A mouse selection over the lines of one area.
///
/// Keep one `Selection` in your state for the region whose text can be
/// selected, pass it to `Frame::lines` when drawing, and feed it mouse events
/// with `mouse`. The selection is made by dragging with the left button; it is
/// highlighted on the next draw, and `text` returns what it covers.
///
/// The selection is anchored to the lines, not to the screen, so it stays on
/// the same text while the area scrolls, and it can cover more than fits on
/// screen: dragging past the top or bottom edge scrolls the area.
struct Selection {
  // Where the button went down, and where the pointer is now.
  mut anchor : Position
  mut head : Position
  // The button is down after a press inside the area.
  mut dragging : Bool
  // There is a selection: the pointer moved while the button was down.
  mut selected : Bool
  // What the last draw showed, which is what mouse coordinates refer to.
  mut lines : ArrayView[Line]
  mut area : Rect
  mut first : Int32
  mut align : Align
  mut scroll : Scroll?
}

///|
/// Build an empty selection.
pub fn Selection::Selection() -> Selection {
  let origin = Position::{ line: 0, glyph: 0, }
  {
    anchor: origin,
    head: origin,
    dragging: false,
    selected: false,
    lines: [][:],
    area: Rect(row=0, col=0, width=0, height=0),
    first: 0,
    align: Left,
    scroll: None,
  }
}

///|
/// Remove the selection.
pub fn Selection::clear(self : Selection) -> Unit {
  self.dragging = false
  self.selected = false
}

///|
/// Remember what this draw shows. A selection made on other content is
/// dropped: after a change of width the lines have been wrapped differently,
/// and after lines were removed it may point past the end.
fn Selection::record(
  self : Selection,
  area : Rect,
  lines : ArrayView[Line],
  first~ : Int32,
  align~ : Align,
  scroll~ : Scroll?,
) -> Unit {
  let last = if self.anchor.before(self.head) { self.head } else { self.anchor }
  if area.width != self.area.width || last.line >= lines.length() {
    self.clear()
  }
  self.lines = lines
  self.area = area
  self.first = first
  self.align = align
  self.scroll = scroll
}

///|
/// The column where a line `width` columns wide starts in `area`.
fn line_start(area : Rect, width : Int32, align : Align) -> Int32 {
  let free = (area.width - width).max(0)
  match align {
    Left => area.col
    Center => area.col + free / 2
    Right => area.col + free
  }
}

///|
/// The position in `line` under frame column `col`. A column left of the line
/// is its first glyph; a column right of it is just past its end.
fn Selection::position_in(
  self : Selection,
  line : Int32,
  col : Int32,
) -> Position {
  let glyphs = self.lines[line].glyphs()
  let mut width = 0
  for glyph in glyphs {
    width += glyph.width
  }
  let mut right = line_start(self.area, width, self.align)
  for index, glyph in glyphs {
    right += glyph.width
    if col < right {
      return { line, glyph: index, }
    }
  }
  { line, glyph: glyphs.length(), }
}

///|
/// The position under the 0-based frame cell (`row`, `col`), or `None` when
/// there are no lines. A row below the last line is the end of the last line.
/// Rows above or below the area scroll it by one line when it can scroll.
fn Selection::position(self : Selection, row : Int32, col : Int32) -> Position? {
  if self.lines.length() == 0 {
    return None
  }
  let last = self.lines.length() - 1
  if row < self.area.row {
    if self.scroll is Some(scroll) {
      scroll.scroll_by(-1)
      self.first = scroll.offset()
    }
    return Some({ line: self.first.min(last), glyph: 0, })
  }
  if row >= self.area.row + self.area.height {
    if self.scroll is Some(scroll) {
      scroll.scroll_by(1)
      self.first = scroll.offset()
    }
    let line = (self.first + self.area.height - 1).clamp(min=0, max=last)
    return Some({ line, glyph: self.lines[line].glyphs().length(), })
  }
  let line = self.first + row - self.area.row
  if line > last {
    Some({ line: last, glyph: self.lines[last].glyphs().length(), })
  } else {
    Some(self.position_in(line, col))
  }
}

///|
/// Update the selection from a mouse event.
///
/// Pressing the left button inside the area starts a selection, dragging
/// extends it, and releasing ends it. A click without a drag, or a press
/// outside the area, removes the selection. Other buttons and the wheel are
/// ignored, so every mouse event can be passed here.
pub fn Selection::mouse(self : Selection, event : @input.MouseEvent) -> Unit {
  // Mouse events use 1-based terminal coordinates.
  let row = event.row - 1
  let col = event.col - 1
  match event.kind {
    Press(Left) => {
      self.clear()
      let inside = row >= self.area.row &&
        row < self.area.row + self.area.height &&
        col >= self.area.col &&
        col < self.area.col + self.area.width
      if inside && self.position(row, col) is Some(position) {
        self.anchor = position
        self.head = position
        self.dragging = true
      }
    }
    Drag(Left) =>
      if self.dragging && self.position(row, col) is Some(position) {
        self.head = position
        self.selected = true
      }
    Release(Left) => self.dragging = false
    _ => ()
  }
}

///|
/// The selected glyphs of line `line`, as a range `from..<to` of glyph
/// indices, or `None` when nothing on that line is selected. `count` is the
/// line's glyph count.
fn Selection::range_in(
  self : Selection,
  line : Int32,
  count : Int32,
) -> (Int32, Int32)? {
  if !self.selected {
    return None
  }
  let (start, end) = if self.head.before(self.anchor) {
    (self.head, self.anchor)
  } else {
    (self.anchor, self.head)
  }
  if line < start.line || line > end.line {
    return None
  }
  let from = if line == start.line { start.glyph } else { 0 }
  // The glyph under the far end is part of the selection.
  let to = if line == end.line { (end.glyph + 1).min(count) } else { count }
  if from < to {
    Some((from, to))
  } else {
    None
  }
}

///|
/// The selected text, or `None` when nothing is selected.
///
/// Lines are joined with newlines, except where `Line::wrap` broke one line
/// into several: those are joined the way they were before wrapping, so the
/// result is the original text rather than the text as it happened to wrap.
pub fn Selection::text(self : Selection) -> String? {
  if !self.selected {
    return None
  }
  let first = self.anchor.line.min(self.head.line)
  let last = self.anchor.line.max(self.head.line).min(self.lines.length() - 1)
  let text = StringBuilder()
  for index in first..<=last {
    let line = self.lines[index]
    let glyphs = line.glyphs()
    if self.range_in(index, glyphs.length()) is Some((from, to)) {
      for glyph in glyphs[from:to] {
        text.write_string(glyph.text)
      }
    }
    if index < last {
      text.write_string(line.soft_break.unwrap_or("\n"))
    }
  }
  if text.is_empty() {
    None
  } else {
    Some(text.to_string())
  }
}
