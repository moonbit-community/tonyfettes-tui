///|
/// A multi-line text editor: the text being edited and the cursor in it.
///
/// Keep one `Editor` in your state per input box. Draw it with `draw`, pass
/// it key events with `key`, and read the result with `text`. Long lines wrap
/// to the width of the area it is drawn in, and when there are more rows than
/// the area is tall it scrolls to keep the cursor in view.
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
  // Where the text was last drawn, which is what mouse coordinates refer to.
  mut area : @tui.Rect
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
/// `text` as the editor keeps it: line breaks are "\n", tabs become four
/// spaces, and other control characters are removed, since they could not be
/// shown as text.
fn clean(text : StringView) -> String {
  let text = text
    .to_owned()
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
    .replace_all(old="\t", new="    ")
  let cleaned = StringBuilder()
  for c in text {
    let code = c.to_int()
    if c == '\n' || !(code < 0x20 || (code >= 0x7f && code < 0xa0)) {
      cleaned.write_char(c)
    }
  }
  cleaned.to_string()
}

///|
/// Cut cleaned text into glyphs. Every character ends up in some glyph, so
/// the glyphs always add up to the text.
fn glyphs_of(text : String) -> Array[Glyph] {
  let glyphs = []
  for index, part in text.split("\n") {
    if index > 0 {
      glyphs.push(newline)
    }
    let display = @displaytext.DisplayText(part.to_owned())
    let mut position = display.start()
    while display.next(position) is Some(next) {
      let grapheme = display.view(position, next).to_owned()
      position = next
      // Measuring through `Line` keeps the editor's idea of a glyph's width
      // the same as the frame's.
      glyphs.push({
        text: grapheme,
        width: @tui.Line::from_text(grapheme).width(),
      })
    }
  }
  glyphs
}

///|
/// Build an editor holding `text`, with the cursor at the end.
pub fn Editor::Editor(text~ : StringView = "") -> Editor {
  let glyphs = glyphs_of(clean(text))
  {
    glyphs,
    cursor: glyphs.length(),
    goal: None,
    width: 0,
    top: 0,
    area: Rect(row=0, col=0, width=0, height=0),
  }
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
  self.glyphs = glyphs_of(clean(text))
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
/// How many glyphs on each side of an edit are cut again with it, to begin
/// with. See `Editor::splice`.
const Context : Int32 = 8

///|
/// Replace the glyphs in `from..<to` with `text`, which is already clean, and
/// put the cursor after it.
///
/// What counts as one glyph depends on its neighbours: a combining mark joins
/// the letter before it, and some letters join into a ligature. So the text
/// around the change is cut into glyphs again, and the cursor is placed by
/// counting characters rather than glyphs. If that count falls inside a glyph
/// that formed across the edit, the cursor goes before that glyph.
///
/// Cutting a whole line again would make every keystroke cost as much as the
/// line is long. Instead a window of a few glyphs on each side of the change
/// is cut again. The result is used when it leaves the glyphs at both edges of
/// the window as they were, which means the change did not reach that far;
/// otherwise the window is widened, up to the whole line.
fn Editor::splice(
  self : Editor,
  from : Int32,
  to : Int32,
  text : String,
) -> Unit {
  let mut line_start = from
  while line_start > 0 && self.glyphs[line_start - 1].text != "\n" {
    line_start -= 1
  }
  let mut line_end = to
  while line_end < self.glyphs.length() && self.glyphs[line_end].text != "\n" {
    line_end += 1
  }
  let mut context = Context
  for ;; {
    let start = (from - context).max(line_start)
    let end = (to + context).min(line_end)
    let changed = StringBuilder()
    for glyph in self.glyphs[start:from] {
      changed.write_string(glyph.text)
    }
    changed.write_string(text)
    let target = changed.to_string().length()
    for glyph in self.glyphs[to:end] {
      changed.write_string(glyph.text)
    }
    let glyphs = glyphs_of(changed.to_string())
    // An edge is settled when it is the edge of the line, or when the glyph
    // next to it came out the same as before.
    let left_settled = start == line_start ||
      (glyphs is [first, ..] && first.text == self.glyphs[start].text)
    let right_settled = end == line_end ||
      (glyphs is [.., last] && last.text == self.glyphs[end - 1].text)
    if !left_settled || !right_settled {
      context = context * 4
      continue
    }
    let mut index = 0
    let mut length = 0
    while index < glyphs.length() &&
          length + glyphs[index].text.length() <= target {
      length += glyphs[index].text.length()
      index += 1
    }
    self.glyphs = [..self.glyphs[:start], ..glyphs, ..self.glyphs[end:]]
    self.cursor = start + index
    self.goal = None
    break
  }
}

///|
/// Insert `text` at the cursor, as typing or pasting it would. It may contain
/// line breaks.
pub fn Editor::insert(self : Editor, text : StringView) -> Unit {
  self.splice(self.cursor, self.cursor, clean(text))
}

///|
/// Remove the glyphs in `from..<to` and leave the cursor where they were.
fn Editor::remove(self : Editor, from : Int32, to : Int32) -> Unit {
  self.splice(from, to, "")
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
/// One row of the laid-out text: the glyphs `start..<end`. `line` is the
/// 0-based line of the text it belongs to, and `first` whether it is that
/// line's first row rather than a continuation after a wrap.
priv struct Row {
  start : Int32
  end : Int32
  line : Int32
  first : Bool
}

///|
/// The rows the text occupies at `width` columns. A row ends at a line break,
/// which belongs to neither row, or where the next glyph would not fit. There
/// is always at least one row.
///
/// Rows hold one column less than `width`, so the cursor always has a cell to
/// sit in after the last glyph of a full row. A `width` below one means
/// unknown: nothing wraps.
fn Editor::rows(self : Editor, width : Int32) -> Array[Row] {
  let limit = (width - 1).max(1)
  let rows = []
  let mut start = 0
  let mut used = 0
  let mut line = 0
  let mut first = true
  for index, glyph in self.glyphs {
    if glyph.text == "\n" {
      rows.push(Row::{ start, end: index, line, first, })
      start = index + 1
      used = 0
      line += 1
      first = true
      continue
    }
    if width > 0 && used + glyph.width > limit && index > start {
      rows.push(Row::{ start, end: index, line, first, })
      start = index
      used = 0
      first = false
    }
    used += glyph.width
  }
  rows.push(Row::{ start, end: self.glyphs.length(), line, first, })
  rows
}

///|
/// The row holding the cursor. Where a line wraps, the same index is the end
/// of one row and the start of the next; the cursor is shown on the next.
fn Editor::cursor_row(self : Editor, rows : Array[Row]) -> Int32 {
  let mut row = 0
  for index, candidate in rows {
    if candidate.start <= self.cursor {
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
/// The glyph index in row `target` that is closest to display column
/// `column` without passing it.
fn Editor::index_at(
  self : Editor,
  rows : Array[Row],
  target : Int32,
  column : Int32,
) -> Int32 {
  let row = rows[target]
  let mut index = row.start
  let mut used = 0
  while index < row.end && used + self.glyphs[index].width <= column {
    used += self.glyphs[index].width
    index += 1
  }
  // The end of a wrapped row is also the start of the next one, where the
  // cursor would be shown. Stop one glyph short to stay on the target row.
  let wraps = target + 1 < rows.length() && rows[target + 1].start == row.end
  if wraps && index == row.end && row.end > row.start {
    row.end - 1
  } else {
    index
  }
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
  let goal = self.goal.unwrap_or(self.column(rows[row].start, self.cursor))
  self.cursor = self.index_at(rows, target, goal)
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
/// Where the cursor is in the text: its 0-based line, and its 0-based column
/// within that line counted in display columns. Lines here are the ones
/// separated by line breaks, however they wrap.
pub fn Editor::position(self : Editor) -> (Int32, Int32) {
  let mut line = 0
  for glyph in self.glyphs[:self.cursor] {
    if glyph.text == "\n" {
      line += 1
    }
  }
  (line, self.column(self.line_start(), self.cursor))
}

///|
/// Apply a mouse event to the editor and report whether it was used.
///
/// Pressing the left button on the text, where it was last drawn, moves the
/// cursor there. A press below the last row goes to the last row.
pub fn Editor::mouse(self : Editor, event : @input.MouseEvent) -> Bool {
  guard event.kind is Press(Left) else { return false }
  // Mouse events use 1-based terminal coordinates.
  let row = event.row - 1 - self.area.row
  let col = event.col - 1 - self.area.col
  guard row >= 0 && row < self.area.height && col >= 0 && col < self.area.width else {
    return false
  }
  let rows = self.rows(self.width)
  let target = (self.top + row).min(rows.length() - 1)
  self.cursor = self.index_at(rows, target, col)
  self.goal = None
  true
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
/// `over` laid on top of `base`: its colors where it sets them, and its
/// attributes in addition to the ones `base` has.
fn merge(base : @tui.Style, over : @tui.Style) -> @tui.Style {
  Style(
    fg=if over.fg == Default { base.fg } else { over.fg },
    bg=if over.bg == Default { base.bg } else { over.bg },
    bold=base.bold || over.bold,
    italic=base.italic || over.italic,
    underline=base.underline || over.underline,
    reverse=base.reverse || over.reverse,
  )
}

///|
/// The style `highlight` gives each glyph of the line that row `index`
/// belongs to, together with the glyph index where that line starts.
///
/// `highlight` sees the line's text and returns it cut into styled spans. The
/// spans are matched to glyphs by length, so they should add up to the same
/// text; glyphs past the end of the spans get no style.
fn Editor::line_styles(
  self : Editor,
  rows : Array[Row],
  index : Int32,
  highlight : (String) -> Array[@tui.Span],
) -> (Int32, Array[@tui.Style]) {
  let mut first = index
  while !rows[first].first {
    first -= 1
  }
  let mut last = index
  while last + 1 < rows.length() && !rows[last + 1].first {
    last += 1
  }
  let start = rows[first].start
  let end = rows[last].end
  let text = StringBuilder()
  for glyph in self.glyphs[start:end] {
    text.write_string(glyph.text)
  }
  let spans = highlight(text.to_string())
  let styles = []
  // `span` is the span the next glyph falls in; `left` is how much of that
  // span's text is still ahead of the glyph.
  let mut span = 0
  let mut left = if spans.length() > 0 { spans[0].text.length() } else { 0 }
  for glyph in self.glyphs[start:end] {
    while left <= 0 && span + 1 < spans.length() {
      span += 1
      left += spans[span].text.length()
    }
    styles.push(if left > 0 { spans[span].style } else { Style() })
    left -= glyph.text.length()
  }
  (start, styles)
}

///|
/// How many decimal digits `n` has.
fn digits(n : Int32) -> Int32 {
  let mut count = 1
  let mut rest = n / 10
  while rest > 0 {
    count += 1
    rest = rest / 10
  }
  count
}

///|
/// What a window onto the editor shows, as plain data: for an application that
/// draws the text itself instead of calling `draw`.
pub struct Layout {
  /// The text of each visible row, top to bottom.
  rows : Array[String]
  /// Where the cursor is among `rows`.
  cursor : @tui.Cursor
  /// The index of the first visible row among all the rows of the text.
  top : Int32
  /// How many rows the whole text takes.
  total : Int32
} derive(Debug)

///|
/// Bring the cursor's row into a window `height` rows tall by scrolling just
/// far enough, without leaving blank rows at the bottom when the text got
/// shorter. Returns the cursor's row among `rows`.
fn Editor::scroll_to_cursor(
  self : Editor,
  rows : Array[Row],
  height : Int32,
) -> Int32 {
  let cursor_row = self.cursor_row(rows)
  let top = self.top.clamp(min=(cursor_row - height + 1).max(0), max=cursor_row)
  self.top = top.clamp(min=0, max=(rows.length() - height).max(0))
  cursor_row
}

///|
/// Lay the text out `width` columns wide and return what a window `height`
/// rows tall shows of it.
///
/// This is `draw` without the drawing. Like `draw`, it scrolls to keep the
/// cursor in the window and records the width for up and down movement, so
/// call it with the size the text is really shown at. A `height` below one is
/// treated as one.
pub fn Editor::layout(self : Editor, width~ : Int32, height~ : Int32) -> Layout {
  let height = height.max(1)
  self.width = width
  let rows = self.rows(width)
  let cursor_row = self.scroll_to_cursor(rows, height)
  let visible = []
  for index in self.top..<(self.top + height).min(rows.length()) {
    let text = StringBuilder()
    for glyph in self.glyphs[rows[index].start:rows[index].end] {
      text.write_string(glyph.text)
    }
    visible.push(text.to_string())
  }
  {
    rows: visible,
    cursor: Cursor(
      row=cursor_row - self.top,
      col=self.column(rows[cursor_row].start, self.cursor),
    ),
    top: self.top,
    total: rows.length(),
  }
}

///|
/// Draw the editor in `area` of `frame`: its text, wrapped to the area's
/// width, and the cursor.
///
/// When the text has more rows than the area is tall, the rows around the
/// cursor are shown. Drawing records where the text is, which is what up and
/// down movement and `mouse` use.
///
/// - `style` is the style of the text and of the area behind it.
/// - `focused=false` draws the text without placing the cursor.
/// - `highlight` colors the text. It is called with the text of a line and
///   returns that same text cut into styled spans; it is called again for
///   every visible line on every draw, so it should be cheap. Its styles are
///   laid over `style`.
/// - `line_numbers` shows a column of line numbers in that style on the left.
///   Rows that continue a wrapped line have no number.
/// - `current_line` is laid over `style` on the rows of the line the cursor
///   is on, typically to give them a different background.
pub fn Editor::draw(
  self : Editor,
  frame : @tui.Frame,
  area : @tui.Rect,
  style~ : @tui.Style = Style(),
  focused~ : Bool = true,
  highlight? : (String) -> Array[@tui.Span],
  line_numbers? : @tui.Style,
  current_line? : @tui.Style,
) -> Unit {
  // The last row's line is the last line, so it gives the widest number.
  let unwrapped = self.rows(0)
  let gutter = if line_numbers is Some(_) {
    digits(unwrapped[unwrapped.length() - 1].line + 1) + 2
  } else {
    0
  }
  guard @tui.Layout::horizontal([Length(gutter), Fill(1)]).split(area)
    is [numbers, text] else {
    return
  }
  self.width = text.width
  self.area = text
  if text.width == 0 || text.height == 0 {
    return
  }
  frame.fill(text, style~)
  if line_numbers is Some(number_style) {
    frame.fill(numbers, style=number_style)
  }
  let rows = self.rows(text.width)
  let cursor_row = self.scroll_to_cursor(rows, text.height)
  let cursor_line = rows[cursor_row].line
  // The styles of the line being drawn, from `highlight`: one per glyph,
  // starting at glyph `styled_from`. A wrapped line spans several rows, so
  // they are kept from one row to the next.
  let mut styled_line = -1
  let mut styled_from = 0
  let mut styles : Array[@tui.Style] = []
  for index in self.top..<(self.top + text.height).min(rows.length()) {
    let row = rows[index]
    let screen_row = text.row + index - self.top
    let row_area = @tui.Rect(
      row=screen_row,
      col=text.col,
      width=text.width,
      height=1,
    )
    let base = if current_line is Some(current) && row.line == cursor_line {
      let base = merge(style, current)
      frame.fill(row_area, style=base)
      base
    } else {
      style
    }
    if line_numbers is Some(number_style) && row.first {
      // One blank column separates the numbers from the text.
      frame.line(
        @tui.Rect(
          row=screen_row,
          col=numbers.col,
          width=numbers.width - 1,
          height=1,
        ),
        @tui.Line::from_text("\{row.line + 1}", style=number_style),
        align=Right,
      )
    }
    if highlight is Some(highlight) && row.line != styled_line {
      let (from, line_styles) = self.line_styles(rows, index, highlight)
      styled_line = row.line
      styled_from = from
      styles = line_styles
    }
    // Paint the row as runs of glyphs that share a style.
    let spans : Array[@tui.Span] = []
    let run = StringBuilder()
    let mut run_style = base
    for at in row.start..<row.end {
      let glyph_style = if highlight is Some(_) {
        merge(base, styles[at - styled_from])
      } else {
        base
      }
      if glyph_style != run_style && !run.is_empty() {
        spans.push(Span(run.to_string(), style=run_style))
        run.reset()
      }
      run_style = glyph_style
      run.write_string(self.glyphs[at].text)
    }
    if !run.is_empty() {
      spans.push(Span(run.to_string(), style=run_style))
    }
    frame.line(row_area, Line(spans))
  }
  if focused {
    frame.set_cursor(
      text,
      row=cursor_row - self.top,
      col=self.column(rows[cursor_row].start, self.cursor),
    )
  }
}
