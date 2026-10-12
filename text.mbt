///|
/// One displayable grapheme with its width in columns and its style.
priv struct Glyph {
  text : String
  width : Int32
  style : Style
}

///|
/// Whether a grapheme contains a C0 or C1 control character. Such text must
/// never reach the terminal as cell content: it would be interpreted as a
/// control sequence instead of being displayed.
fn is_control(grapheme : StringView) -> Bool {
  for c in grapheme {
    let code = c.to_int()
    if code < 0x20 || (code >= 0x7f && code < 0xa0) {
      return true
    }
  }
  false
}

///|
/// Append the displayable graphemes of `text` to `glyphs`. Control characters,
/// including tab and newline, and zero-width graphemes are left out, so
/// measuring and painting always agree on what a text occupies.
fn push_glyphs(glyphs : Array[Glyph], text : StringView, style : Style) -> Unit {
  let display = @displaytext.DisplayText(text.to_owned())
  let mut position = display.start()
  while display.next(position) is Some(next) {
    let grapheme = display.view(position, next)
    let width = display.display_position(next).column() -
      display.display_position(position).column()
    position = next
    if width > 0 && !is_control(grapheme) {
      glyphs.push({ text: grapheme.to_owned(), width, style, })
    }
  }
}

///|
/// A run of text in one style.
pub struct Span {
  text : String
  style : Style
} derive(Eq, Debug)

///|
/// Build a span. Without `style` the text is unstyled.
pub fn Span::Span(text : StringView, style~ : Style = Style()) -> Span {
  { text: text.to_owned(), style, }
}

///|
pub extend Span with Eq::{equal, not_equal}

///|
pub extend Span with @debug.Debug::{to_repr}

///|
/// One row of text: spans laid out left to right.
///
/// A line knows how wide it is and how to wrap itself, so placing text never
/// needs hand-computed columns. Control characters in the spans, including tab
/// and newline, are not displayed and take no width: split text into lines and
/// expand tabs before building a `Line`.
struct Line {
  spans : Array[Span]
} derive(Eq, Debug)

///|
/// Build a line from spans, in left-to-right order.
pub fn Line::Line(spans : Array[Span]) -> Line {
  { spans: spans.copy(), }
}

///|
/// A line holding one span of `text`.
pub fn Line::from_text(text : StringView, style~ : Style = Style()) -> Line {
  { spans: [Span(text, style~)], }
}

///|
pub extend Line with Eq::{equal, not_equal}

///|
pub extend Line with @debug.Debug::{to_repr}

///|
fn Line::glyphs(self : Line) -> Array[Glyph] {
  let glyphs = []
  for span in self.spans {
    push_glyphs(glyphs, span.text, span.style)
  }
  glyphs
}

///|
/// Rebuild a line from glyphs, merging neighbours that share a style.
fn Line::from_glyphs(glyphs : ArrayView[Glyph]) -> Line {
  let spans : Array[Span] = []
  let run = StringBuilder()
  let mut style = Style()
  for glyph in glyphs {
    if glyph.style != style && !run.is_empty() {
      spans.push({ text: run.to_string(), style, })
      run.reset()
    }
    style = glyph.style
    run.write_string(glyph.text)
  }
  if !run.is_empty() {
    spans.push({ text: run.to_string(), style, })
  }
  { spans, }
}

///|
/// The line's width in display columns. Wide graphemes such as CJK characters
/// count as two.
pub fn Line::width(self : Line) -> Int32 {
  let mut width = 0
  for glyph in self.glyphs() {
    width += glyph.width
  }
  width
}

///|
/// The line's text without styles, as it would be displayed.
pub fn Line::to_text(self : Line) -> String {
  let text = StringBuilder()
  for glyph in self.glyphs() {
    text.write_string(glyph.text)
  }
  text.to_string()
}

///|
/// Break the line into lines no wider than `width` columns, keeping styles.
///
/// A break is made at the last space that fits, and that space is dropped; a
/// word longer than `width`, or text without spaces such as CJK, is broken
/// wherever it reaches the edge. An empty line wraps to one empty line, so
/// blank lines keep their row. A `width` below one gives no lines.
pub fn Line::wrap(self : Line, width : Int32) -> Array[Line] {
  if width < 1 {
    return []
  }
  let glyphs = self.glyphs()
  let lines = []
  // The current line is `glyphs[start:end]`, `used` columns wide. `space` is
  // the index of its last space, or -1.
  let mut start = 0
  let mut used = 0
  let mut space = -1
  let mut end = 0
  while end < glyphs.length() {
    let glyph = glyphs[end]
    if glyph.width > width {
      // Cannot fit on any line; leave it out rather than loop forever.
      glyphs.remove(end) |> ignore
      continue
    }
    if used + glyph.width <= width {
      if glyph.text == " " {
        space = end
      }
      used += glyph.width
      end += 1
      continue
    }
    // `glyph` does not fit: close the current line.
    let break_at = if glyph.text == " " {
      end
    } else if space >= start {
      space
    } else {
      -1
    }
    if break_at >= 0 {
      lines.push(Line::from_glyphs(glyphs[start:break_at]))
      start = break_at + 1
    } else {
      lines.push(Line::from_glyphs(glyphs[start:end]))
      start = end
    }
    end = start
    used = 0
    space = -1
  }
  lines.push(Line::from_glyphs(glyphs[start:end]))
  lines
}
