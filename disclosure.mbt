///|
/// Expandable styled content with a single-row header. Payload semantics and
/// keyboard focus belong to the application; this value owns only expansion
/// and click matching.
struct Disclosure {
  mut expanded : Bool
  mut pressed : (Int32, Int32, Rect)?
}

///|
/// Start collapsed unless `expanded` is requested.
pub fn Disclosure::Disclosure(expanded~ : Bool = false) -> Disclosure {
  { expanded, pressed: None, }
}

///|
pub fn Disclosure::expanded(self : Disclosure) -> Bool {
  self.expanded
}

///|
/// Change expansion programmatically and cancel any pending click.
pub fn Disclosure::set_expanded(self : Disclosure, expanded : Bool) -> Unit {
  self.expanded = expanded
  self.pressed = None
}

///|
/// Build a single-row header, followed by wrapped, indented content when open.
/// Preserve the title and content styles. `selected` highlights the header;
/// it does not change application focus. A nonpositive width yields no lines.
pub fn Disclosure::lines(
  self : Disclosure,
  title : Line,
  content : ArrayView[Line],
  width~ : Int32,
  selected~ : Bool = false,
) -> Array[Line] {
  guard width > 0 else { return [] }
  let glyphs = Line::from_text(if self.expanded { "▾ " } else { "▸ " }).glyphs()
  glyphs.append(title.glyphs())
  let truncated = glyphs.fold(init=0, (width, glyph) => width + glyph.width) >
    width
  let limit = width - (if truncated { 1 } else { 0 })
  let header = []
  let mut used = 0
  for glyph in glyphs {
    if used + glyph.width > limit {
      break
    }
    header.push(glyph)
    used += glyph.width
  }
  if truncated {
    push_glyphs(header, "…", Style())
  }
  if selected {
    for index, glyph in header {
      header[index] = {
        ..glyph,
        style: { ..glyph.style, bold: true, reverse: true, },
      }
    }
  }
  let lines = [Line::from_glyphs(header)]
  if self.expanded {
    let indent = (width - 1).min(2)
    let prefix = Line::from_text(" ".repeat(indent)).glyphs()
    for line in content {
      for wrapped in line.wrap(width - indent) {
        let glyphs = prefix.copy()
        glyphs.append(wrapped.glyphs())
        lines.push(Line::from_glyphs(glyphs))
      }
    }
  }
  lines
}

///|
/// Handle a click on the first row of `header`, using 1-based mouse events.
/// Press and release must use the same cell and unchanged header rectangle.
/// Movement, dragging, and scrolling cancel the pending click. Return whether
/// the press or completed click was consumed; body text remains selectable.
pub fn Disclosure::mouse(
  self : Disclosure,
  event : @input.MouseEvent,
  header : Rect,
) -> Bool {
  let row = event.row - 1
  let col = event.col - 1
  let inside = header.height > 0 &&
    row == header.row &&
    col >= header.col &&
    col < header.col + header.width
  match event.kind {
    Press(Left) => {
      self.pressed = if inside { Some((row, col, header)) } else { None }
      inside
    }
    Release(Left) => {
      let pressed = self.pressed
      self.pressed = None
      if inside && pressed == Some((row, col, header)) {
        self.expanded = !self.expanded
        true
      } else {
        false
      }
    }
    _ => {
      self.pressed = None
      false
    }
  }
}

///|
/// Enter and Space toggle the selected header on press (not repeat/release).
/// Other keys and unselected headers are left to the application's navigation.
pub fn Disclosure::key(
  self : Disclosure,
  event : @input.KeyEvent,
  selected~ : Bool,
) -> Bool {
  if selected &&
    event.kind is Press &&
    event.code is (Enter | Char(' ')) &&
    event.modifiers == @input.KeyModifiers::new() {
    self.set_expanded(!self.expanded)
    true
  } else {
    false
  }
}
