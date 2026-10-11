///|
/// One screen cell.
///
/// `width` is the number of columns the grapheme occupies. A grapheme wider
/// than one column is stored in its leftmost cell; the columns it covers to the
/// right hold continuation cells with `width == 0` and empty text.
priv struct Cell {
  text : String
  style : Style
  width : Int
} derive(Eq)

///|
let blank : Cell = { text: " ", style: Style(), width: 1, }

///|
/// A cursor position inside a frame, 0-based.
priv struct Cursor {
  row : Int
  col : Int
} derive(Eq)

///|
/// One full picture of the screen: a grid of styled cells plus an optional
/// cursor.
///
/// A frame starts blank with the cursor hidden. Paint the whole picture into
/// it, then hand it to `Terminal::draw`; there is no need to track what the
/// previous frame looked like.
///
/// Lay a frame out by splitting `area()` into smaller areas and painting into
/// those. Rows and columns are 0-based, and painting outside the frame is
/// clipped.
struct Frame {
  width : Int
  height : Int
  cells : Array[Cell]
  mut cursor : Cursor?
}

///|
/// Build a blank frame of `width` columns by `height` rows.
pub fn Frame::Frame(width~ : Int, height~ : Int) -> Frame {
  let width = width.max(0)
  let height = height.max(0)
  { width, height, cells: Array::make(width * height, blank), cursor: None, }
}

///|
/// The frame's width in columns.
pub fn Frame::width(self : Frame) -> Int {
  self.width
}

///|
/// The frame's height in rows.
pub fn Frame::height(self : Frame) -> Int {
  self.height
}

///|
fn Frame::cell(self : Frame, row : Int, col : Int) -> Cell {
  self.cells[row * self.width + col]
}

///|
/// Blank the cell at (`row`, `col`). If it is part of a wide grapheme, blank
/// the whole grapheme so no half of it is left behind.
fn Frame::clear_cell(self : Frame, row : Int, col : Int) -> Unit {
  let base = row * self.width
  let mut lead = col
  while lead > 0 && self.cells[base + lead].width == 0 {
    lead -= 1
  }
  let end = (lead + self.cells[base + lead].width.max(1)).min(self.width)
  for c in lead..<end {
    self.cells[base + c] = blank
  }
}

///|
/// Store a grapheme of `width` columns at (`row`, `col`). The caller checks
/// that all `width` columns are inside the frame.
fn Frame::put(
  self : Frame,
  row : Int,
  col : Int,
  text : String,
  style : Style,
  width : Int,
) -> Unit {
  for c in col..<(col + width) {
    self.clear_cell(row, c)
  }
  let index = row * self.width + col
  self.cells[index] = { text, style, width, }
  for offset in 1..<width {
    self.cells[index + offset] = { text: "", style, width: 0, }
  }
}

///|
/// Paint `glyphs` on `row` from column `col`, touching only the columns in
/// `left..<right`, and return the column after the last glyph painted.
///
/// Painting stops at the first glyph that would cross `right`, so nothing is
/// ever shifted into the place of a glyph that was cut off. The caller checks
/// that `row` and the clip columns are inside the frame.
fn Frame::paint(
  self : Frame,
  row : Int,
  col : Int,
  glyphs : Array[Glyph],
  left~ : Int,
  right~ : Int,
) -> Int {
  let mut col = col
  for glyph in glyphs {
    if col + glyph.width > right {
      break
    }
    if col >= left {
      self.put(row, col, glyph.text, glyph.style, glyph.width)
    }
    col += glyph.width
  }
  col
}

///|
/// The area covering the whole frame.
pub fn Frame::area(self : Frame) -> Rect {
  Rect(row=0, col=0, width=self.width, height=self.height)
}

///|
/// Paint `text` at an exact cell: on `row`, starting at column `col`.
///
/// This is the lowest-level way to put text in a frame. Prefer `line`, which
/// places text in an area and handles alignment and clipping to that area.
/// Painting stops at the frame's right edge; a row outside the frame paints
/// nothing.
pub fn Frame::text(
  self : Frame,
  row~ : Int,
  col~ : Int,
  text : StringView,
  style? : Style = Style(),
) -> Unit {
  if row < 0 || row >= self.height {
    return
  }
  let glyphs = []
  push_glyphs(glyphs, text, style)
  ignore(self.paint(row, col, glyphs, left=0, right=self.width))
}

///|
/// Where a line sits when it is narrower than its area.
pub(all) enum Align {
  Left
  Center
  Right
} derive(Eq, Debug)

///|
pub extend Align with Eq::{equal, not_equal}

///|
pub extend Align with @debug.Debug::{to_repr}

///|
/// Paint `line` on the first row of `area`.
///
/// The line is clipped to the area: a line wider than the area is cut at the
/// area's right edge, and nothing is painted outside it. `align` places a line
/// narrower than the area.
pub fn Frame::line(
  self : Frame,
  area : Rect,
  line : Line,
  align? : Align = Left,
) -> Unit {
  let visible = area.intersect(self.area())
  if visible.width == 0 || visible.height == 0 || visible.row != area.row {
    return
  }
  let free = (area.width - line.width()).max(0)
  let col = match align {
    Left => area.col
    Center => area.col + free / 2
    Right => area.col + free
  }
  ignore(
    self.paint(
      area.row,
      col,
      line.glyphs(),
      left=visible.col,
      right=visible.col + visible.width,
    ),
  )
}

///|
/// Paint `lines` down the rows of `area`, one line per row, starting at the
/// top. Lines that do not fit in the area's height are not painted.
pub fn Frame::lines(
  self : Frame,
  area : Rect,
  lines : ArrayView[Line],
  align? : Align = Left,
) -> Unit {
  for index in 0..<lines.length().min(area.height) {
    self.line(
      Rect(row=area.row + index, col=area.col, width=area.width, height=1),
      lines[index],
      align~,
    )
  }
}

///|
/// Fill `area` with blank cells in `style`, replacing what was there. The part
/// of the area outside the frame is ignored.
pub fn Frame::fill(self : Frame, area : Rect, style? : Style = Style()) -> Unit {
  let area = area.intersect(self.area())
  for row in area.row..<(area.row + area.height) {
    for col in area.col..<(area.col + area.width) {
      self.put(row, col, " ", style, 1)
    }
  }
}

///|
/// Show the terminal cursor in `area`, `row` rows down and `col` columns right
/// of its top-left corner. The position is kept inside the area and inside the
/// frame. A frame that never calls this leaves the cursor hidden.
pub fn Frame::set_cursor(
  self : Frame,
  area : Rect,
  row? : Int = 0,
  col? : Int = 0,
) -> Unit {
  let area = area.intersect(self.area())
  if area.width == 0 || area.height == 0 {
    return
  }
  self.cursor = Some({
    row: area.row + row.clamp(min=0, max=area.height - 1),
    col: area.col + col.clamp(min=0, max=area.width - 1),
  })
}

///|
/// The frame's text without styles: rows joined by newlines, trailing blanks
/// of each row dropped. Meant for snapshot tests of view functions.
pub fn Frame::to_text(self : Frame) -> String {
  let text = StringBuilder()
  for row in 0..<self.height {
    if row > 0 {
      text.write_char('\n')
    }
    let mut end = 0
    for col in 0..<self.width {
      let cell = self.cell(row, col)
      if cell.width > 0 && cell.text != " " {
        end = col + cell.width
      }
    }
    for col in 0..<end {
      text.write_string(self.cell(row, col).text)
    }
  }
  text.to_string()
}

///|
/// A copy of the top-left part of the frame that fits in `width` by `height`.
/// A wide grapheme cut by the right edge is replaced with blanks.
fn Frame::clipped(self : Frame, width~ : Int, height~ : Int) -> Frame {
  let frame = Frame(width=self.width.min(width), height=self.height.min(height))
  for row in 0..<frame.height {
    for col in 0..<frame.width {
      let cell = self.cell(row, col)
      if cell.width > 0 && col + cell.width <= frame.width {
        frame.put(row, col, cell.text, cell.style, cell.width)
      }
    }
  }
  if self.cursor is Some(cursor) {
    frame.set_cursor(frame.area(), row=cursor.row, col=cursor.col)
  }
  frame
}
