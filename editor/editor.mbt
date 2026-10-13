///|
/// A multi-line text editor: the text being edited and the cursor in it.
///
/// Keep one `Editor` in your state per input box. Draw it with `draw`, pass
/// it key events with `key`, and read the result with `text`. Long lines wrap to the width of the area it is drawn in, and when
/// there are more rows than the area is tall it scrolls to keep the cursor in
/// view.
///
/// The editor does not decide what Enter means: `key` leaves a plain Enter
/// unhandled so the application can submit, and inserts a line break on
/// Shift+Enter, Alt+Enter, or Ctrl+J.
struct Editor {
  // The text as graphemes. A line break is a glyph with the text "\n" and no
  // width.
  mut glyphs : Array[Glyph]
  // The cursor sits before `glyphs[cursor]`; `glyphs.length()` is the end.
  mut cursor : Int32
  // The column vertical movement tries to stay in, kept across consecutive
  // up/down moves so passing through a short row does not lose it.
  mut goal : Int32?
  // The width of the area the editor was last drawn in, or 0 before the first
  // draw. Vertical movement needs it to know where rows wrap.
  mut width : Int32
  // The first visible row, when there are more rows than the area is tall.
  mut top : Int32
}

///|
/// One grapheme of the text and its width in columns.
priv struct Glyph {
  text : String
  width : Int32
}

///|
let newline : Glyph = { text: "\n", width: 0, }

///|
/// The graphemes of `text` as the editor stores them. Line breaks are kept,
/// tabs become four spaces, and anything the frame would not display, such as
/// other control characters, is dropped.
fn edit_glyphs(text : StringView) -> Array[Glyph] {
  let text = text
    .to_owned()
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
    .replace_all(old="\t", new="    ")
  let glyphs = []
  let mut first = true
  for part in text.split("\n") {
    if !first {
      glyphs.push(newline)
    }
    first = false
    let display = @displaytext.DisplayText(part.to_owned())
    let mut position = display.start()
    while display.next(position) is Some(next) {
      let grapheme = display.view(position, next).to_owned()
      position = next
      // Measuring through `Line` keeps the editor's idea of a glyph's width,
      // and of what is displayable at all, the same as the frame's.
      let width = @tui.Line::from_text(grapheme).width()
      if width > 0 {
        glyphs.push({ text: grapheme, width, })
      }
    }
  }
  glyphs
}

///|
/// Build an editor holding `text`, with the cursor at the end.
pub fn Editor::Editor(text~ : StringView = "") -> Editor {
  let glyphs = edit_glyphs(text)
  { glyphs, cursor: glyphs.length(), goal: None, width: 0, top: 0, }
}

///|
/// The text being edited. Lines are separated by "\n".
pub fn Editor::text(self : Editor) -> String {
  let text = StringBuilder()
  for glyph in self.glyphs {
    text.write_string(glyph.text)
  }
  text.to_string()
}

///|
/// Whether there is no text.
pub fn Editor::is_empty(self : Editor) -> Bool {
  self.glyphs.is_empty()
}

///|
/// Replace the text and put the cursor at the end.
pub fn Editor::set_text(self : Editor, text : StringView) -> Unit {
  self.glyphs = edit_glyphs(text)
  self.cursor = self.glyphs.length()
  self.goal = None
  self.top = 0
}

///|
/// Remove all text.
pub fn Editor::clear(self : Editor) -> Unit {
  self.set_text("")
}

///|
/// Insert `text` at the cursor, as typing or pasting it would. It may contain
/// line breaks.
pub fn Editor::insert(self : Editor, text : StringView) -> Unit {
  let inserted = edit_glyphs(text)
  self.glyphs = [
    ..self.glyphs[:self.cursor],
    ..inserted,
    ..self.glyphs[self.cursor:],
  ]
  self.cursor += inserted.length()
  self.goal = None
}

///|
/// Remove the glyphs in `from..<to` and leave the cursor where they were.
fn Editor::remove(self : Editor, from : Int32, to : Int32) -> Unit {
  self.glyphs = [..self.glyphs[:from], ..self.glyphs[to:]]
  self.cursor = from
  self.goal = None
}

///|
/// The index where the cursor's line starts: just after the previous line
/// break, or the start of the text.
fn Editor::line_start(self : Editor) -> Int32 {
  let mut index = self.cursor
  while index > 0 && self.glyphs[index - 1].text != "\n" {
    index -= 1
  }
  index
}

///|
/// The index where the cursor's line ends: at the next line break, or the end
/// of the text.
fn Editor::line_end(self : Editor) -> Int32 {
  let mut index = self.cursor
  while index < self.glyphs.length() && self.glyphs[index].text != "\n" {
    index += 1
  }
  index
}

///|
/// Whether a grapheme is part of a word: a letter, a digit, an underscore, or
/// anything outside ASCII, which covers CJK text.
fn is_word(grapheme : StringView) -> Bool {
  for c in grapheme {
    let code = c.to_int()
    if code >= 0x80 ||
      c == '_' ||
      (c >= '0' && c <= '9') ||
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') {
      return true
    }
  }
  false
}

///|
/// The index of the start of the word before the cursor.
fn Editor::word_start(self : Editor) -> Int32 {
  let mut index = self.cursor
  while index > 0 && !is_word(self.glyphs[index - 1].text) {
    index -= 1
  }
  while index > 0 && is_word(self.glyphs[index - 1].text) {
    index -= 1
  }
  index
}

///|
/// The index of the end of the word after the cursor.
fn Editor::word_end(self : Editor) -> Int32 {
  let length = self.glyphs.length()
  let mut index = self.cursor
  while index < length && !is_word(self.glyphs[index].text) {
    index += 1
  }
  while index < length && is_word(self.glyphs[index].text) {
    index += 1
  }
  index
}

///|
fn Editor::move_to(self : Editor, index : Int32) -> Unit {
  self.cursor = index.clamp(min=0, max=self.glyphs.length())
  self.goal = None
}

///|
/// Move the cursor one grapheme left.
pub fn Editor::move_left(self : Editor) -> Unit {
  self.move_to(self.cursor - 1)
}

///|
/// Move the cursor one grapheme right.
pub fn Editor::move_right(self : Editor) -> Unit {
  self.move_to(self.cursor + 1)
}

///|
/// Move the cursor to the start of the word before it.
pub fn Editor::move_word_left(self : Editor) -> Unit {
  self.move_to(self.word_start())
}

///|
/// Move the cursor to the end of the word after it.
pub fn Editor::move_word_right(self : Editor) -> Unit {
  self.move_to(self.word_end())
}

///|
/// Move the cursor to the start of its line. A line here is the text between
/// line breaks, however many rows it wraps to.
pub fn Editor::move_home(self : Editor) -> Unit {
  self.move_to(self.line_start())
}

///|
/// Move the cursor to the end of its line.
pub fn Editor::move_end(self : Editor) -> Unit {
  self.move_to(self.line_end())
}

///|
/// Move the cursor to the very start of the text.
pub fn Editor::move_to_start(self : Editor) -> Unit {
  self.move_to(0)
}

///|
/// Move the cursor to the very end of the text.
pub fn Editor::move_to_end(self : Editor) -> Unit {
  self.move_to(self.glyphs.length())
}

///|
/// Delete the grapheme before the cursor.
pub fn Editor::delete_before(self : Editor) -> Unit {
  if self.cursor > 0 {
    self.remove(self.cursor - 1, self.cursor)
  }
}

///|
/// Delete the grapheme after the cursor.
pub fn Editor::delete_after(self : Editor) -> Unit {
  if self.cursor < self.glyphs.length() {
    self.remove(self.cursor, self.cursor + 1)
  }
}

///|
/// Delete from the start of the word before the cursor up to the cursor.
pub fn Editor::delete_word_before(self : Editor) -> Unit {
  self.remove(self.word_start(), self.cursor)
}

///|
/// Delete from the start of the line up to the cursor.
pub fn Editor::kill_before(self : Editor) -> Unit {
  self.remove(self.line_start(), self.cursor)
}

///|
/// Delete from the cursor to the end of the line. At the end of a line it
/// deletes the line break instead, joining the next line onto this one.
pub fn Editor::kill_after(self : Editor) -> Unit {
  let end = self.line_end()
  if end == self.cursor {
    self.delete_after()
  } else {
    self.remove(self.cursor, end)
  }
}

///|
/// The rows the text occupies at `width` columns, each a range `start..<end`
/// of glyph indices. A row ends at a line break, which belongs to neither row,
/// or where the next glyph would not fit. There is always at least one row.
///
/// Rows hold one column less than `width`, so the cursor always has a cell to
/// sit in after the last glyph of a full row. A `width` below one means
/// unknown: nothing wraps.
fn Editor::rows(self : Editor, width : Int32) -> Array[(Int32, Int32)] {
  let limit = (width - 1).max(1)
  let rows = []
  let mut start = 0
  let mut used = 0
  for index, glyph in self.glyphs {
    if glyph.text == "\n" {
      rows.push((start, index))
      start = index + 1
      used = 0
      continue
    }
    if width > 0 && used + glyph.width > limit && index > start {
      rows.push((start, index))
      start = index
      used = 0
    }
    used += glyph.width
  }
  rows.push((start, self.glyphs.length()))
  rows
}

///|
/// The row holding the cursor. Where a line wraps, the same index is the end
/// of one row and the start of the next; the cursor is shown on the next.
fn Editor::cursor_row(self : Editor, rows : Array[(Int32, Int32)]) -> Int32 {
  let mut row = 0
  for index, range in rows {
    if range.0 <= self.cursor {
      row = index
    }
  }
  row
}

///|
/// The display column of glyph index `index` within the row starting at
/// `start`.
fn Editor::column(self : Editor, start : Int32, index : Int32) -> Int32 {
  let mut column = 0
  for glyph in self.glyphs[start:index] {
    column += glyph.width
  }
  column
}

///|
/// Move the cursor `delta` rows down (negative for up), staying as close as it
/// can to the column it started from. Returns whether it moved; it does not
/// when that would leave the text.
fn Editor::move_rows(self : Editor, delta : Int32) -> Bool {
  let rows = self.rows(self.width)
  let row = self.cursor_row(rows)
  let target = row + delta
  if target < 0 || target >= rows.length() {
    return false
  }
  let goal = self.goal.unwrap_or(self.column(rows[row].0, self.cursor))
  let (start, end) = rows[target]
  let mut index = start
  let mut column = 0
  while index < end && column + self.glyphs[index].width <= goal {
    column += self.glyphs[index].width
    index += 1
  }
  // The end of a wrapped row is also the start of the next one, where the
  // cursor would be shown. Stop one glyph short to stay on the target row.
  let wraps = target + 1 < rows.length() && rows[target + 1].0 == end
  if wraps && index == end && end > start {
    index = end - 1
  }
  self.cursor = index
  self.goal = Some(goal)
  true
}

///|
/// Move the cursor up one row. Returns `false` when it is already on the first
/// row, which an application can use to recall history instead.
pub fn Editor::move_up(self : Editor) -> Bool {
  self.move_rows(-1)
}

///|
/// Move the cursor down one row. Returns `false` when it is already on the
/// last row.
pub fn Editor::move_down(self : Editor) -> Bool {
  self.move_rows(1)
}

///|
/// How many rows the text takes when drawn `width` columns wide, at most
/// `max`. Use it to size the editor's area before splitting the layout.
pub fn Editor::height(self : Editor, width~ : Int32, max? : Int32) -> Int32 {
  let rows = self.rows(width).length()
  if max is Some(max) {
    rows.min(max.max(1))
  } else {
    rows
  }
}

///|
/// Apply a key press to the editor and report whether it was used.
///
/// The keys are the usual ones for a terminal input:
///
/// - Text is inserted. Shift+Enter, Alt+Enter, and Ctrl+J insert a line break.
/// - Left/Right or Ctrl+B/Ctrl+F move by one; Alt or Ctrl with Left/Right, or
///   Alt+B/Alt+F, move by a word.
/// - Home/End or Ctrl+A/Ctrl+E move to the start or end of the line;
///   Ctrl+Home/Ctrl+End move to the start or end of the text.
/// - Up/Down or Ctrl+P/Ctrl+N move between rows.
/// - Backspace or Ctrl+H, and Delete or Ctrl+D, delete one grapheme.
/// - Ctrl+W or Alt+Backspace deletes the word before the cursor; Ctrl+U and
///   Ctrl+K delete to the start or end of the line.
///
/// A key is reported unused, with nothing changed, when the editor has no
/// meaning for it or cannot act on it: a plain Enter, Up on the first row,
/// Down on the last, and deleting where there is nothing to delete. That
/// leaves the application free to submit, recall history, or quit.
pub fn Editor::key(self : Editor, key : @input.KeyEvent) -> Bool {
  if key.kind is Release {
    return false
  }
  let ctrl = key.modifiers.ctrl()
  let alt = key.modifiers.alt()
  let length = self.glyphs.length()
  match key.code {
    Enter if key.modifiers.shift() || alt => self.insert("\n")
    Enter => return false
    Char('j') if ctrl => self.insert("\n")
    Left if ctrl || alt => self.move_word_left()
    Right if ctrl || alt => self.move_word_right()
    Char('b') if alt => self.move_word_left()
    Char('f') if alt => self.move_word_right()
    Left => self.move_left()
    Right => self.move_right()
    Char('b') if ctrl => self.move_left()
    Char('f') if ctrl => self.move_right()
    Home if ctrl => self.move_to_start()
    End if ctrl => self.move_to_end()
    Home => self.move_home()
    End => self.move_end()
    Char('a') if ctrl => self.move_home()
    Char('e') if ctrl => self.move_end()
    Up => return self.move_up()
    Down => return self.move_down()
    Char('p') if ctrl => return self.move_up()
    Char('n') if ctrl => return self.move_down()
    Backspace if alt => self.delete_word_before()
    Char('w') if ctrl => self.delete_word_before()
    Backspace => {
      if self.cursor == 0 {
        return false
      }
      self.delete_before()
    }
    Char('h') if ctrl => {
      if self.cursor == 0 {
        return false
      }
      self.delete_before()
    }
    Delete => {
      if self.cursor == length {
        return false
      }
      self.delete_after()
    }
    Char('d') if ctrl => {
      if self.cursor == length {
        return false
      }
      self.delete_after()
    }
    Char('u') if ctrl => self.kill_before()
    Char('k') if ctrl => self.kill_after()
    _ => {
      // Ctrl and Alt chords that reach here are not text.
      guard !ctrl && !alt && key.text is Some(text) else { return false }
      self.insert(text)
    }
  }
  true
}

///|
/// What an area `height` rows tall shows of the editor: the text of each
/// visible row and where the cursor is among them.
priv struct View {
  rows : Array[String]
  cursor_row : Int32
  cursor_col : Int32
}

///|
/// Lay the text out at the recorded width for an area `height` rows tall,
/// scrolling just far enough to keep the cursor's row in it.
fn Editor::view(self : Editor, height~ : Int32) -> View {
  let rows = self.rows(self.width)
  let row = self.cursor_row(rows)
  let top = self.top.clamp(min=(row - height + 1).max(0), max=row)
  // Do not leave blank rows at the bottom when the text got shorter.
  self.top = top.clamp(min=0, max=(rows.length() - height).max(0))
  let visible = []
  for index in self.top..<(self.top + height).min(rows.length()) {
    let (start, end) = rows[index]
    let text = StringBuilder()
    for glyph in self.glyphs[start:end] {
      text.write_string(glyph.text)
    }
    visible.push(text.to_string())
  }
  {
    rows: visible,
    cursor_row: row - self.top,
    cursor_col: self.column(rows[row].0, self.cursor),
  }
}

///|
/// Draw the editor in `area` of `frame`: its text, wrapped to the area's
/// width, and the cursor.
///
/// When the text has more rows than the area is tall, the rows around the
/// cursor are shown. Drawing records the area's width in the editor, which is
/// what up and down movement uses to find the rows. Pass `focused=false` to
/// draw the text without placing the cursor.
pub fn Editor::draw(
  self : Editor,
  frame : @tui.Frame,
  area : @tui.Rect,
  style~ : @tui.Style = Style(),
  focused~ : Bool = true,
) -> Unit {
  self.width = area.width
  if area.width == 0 || area.height == 0 {
    return
  }
  let view = self.view(height=area.height)
  frame.lines(area, view.rows.map(text => @tui.Line::from_text(text, style~)))
  if focused {
    frame.set_cursor(area, row=view.cursor_row, col=view.cursor_col)
  }
}
