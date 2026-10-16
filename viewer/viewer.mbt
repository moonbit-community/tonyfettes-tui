///|
/// Read-only source browsing. The shared text layout supplies wrapping, source
/// coordinates and drawing; its editing input handler is never connected.
/// There are no insert, delete, paste, undo or save operations on this type.
struct Viewer {
  layout : @editor.Editor
  mut height : Int32
}

///|
pub fn Viewer::Viewer(source~ : String = "") -> Viewer {
  let layout = @editor.Editor(text=source, preserve_text=true)
  layout.move_to_start()
  { layout, height: 1, }
}

///|
/// Replace the source snapshot (for example after a disk change), preserving
/// the caret's source position. This does not represent an editing operation.
pub fn Viewer::set_source(self : Viewer, source : String) -> Unit {
  let (line, character) = self.layout.source_position()
  self.layout.set_text(source)
  self.layout.goto_source(line~, character~)
}

///|
pub fn Viewer::source(self : Viewer) -> String {
  self.layout.text()
}

///|
pub fn Viewer::source_position(self : Viewer) -> (Int32, Int32) {
  self.layout.source_position()
}

///|
pub fn Viewer::goto_source(
  self : Viewer,
  line~ : Int32,
  character~ : Int32,
) -> Unit {
  self.layout.goto_source(line~, character~)
}

///|
pub fn Viewer::source_at(
  self : Viewer,
  row~ : Int32,
  col~ : Int32,
) -> (Int32, Int32)? {
  self.layout.source_at(row~, col~)
}

///|
/// Move the browsing caret or viewport. Text input and editing shortcuts are
/// not navigation actions and are returned unused, without modifying source.
pub fn Viewer::navigate(self : Viewer, key : @input.KeyEvent) -> Bool {
  if key.kind is Release {
    return false
  }
  let ctrl = key.modifiers.ctrl()
  let alt = key.modifiers.alt()
  match key.code {
    Left if ctrl || alt => self.layout.move_word_left()
    Right if ctrl || alt => self.layout.move_word_right()
    Left => self.layout.move_left()
    Right => self.layout.move_right()
    Home if ctrl => self.layout.move_to_start()
    End if ctrl => self.layout.move_to_end()
    Home => self.layout.move_home()
    End => self.layout.move_end()
    Up => ignore(self.layout.move_up())
    Down => ignore(self.layout.move_down())
    PageUp | PageDown =>
      for _ in 0..<(self.height - 1).max(1) {
        if key.code is PageUp {
          ignore(self.layout.move_up())
        } else {
          ignore(self.layout.move_down())
        }
      }
    Char('a') if ctrl => self.layout.move_home()
    Char('e') if ctrl => self.layout.move_end()
    Char('b') if alt => self.layout.move_word_left()
    Char('f') if alt => self.layout.move_word_right()
    Char('b') if ctrl => self.layout.move_left()
    Char('f') if ctrl => self.layout.move_right()
    Char('p') if ctrl => ignore(self.layout.move_up())
    Char('n') if ctrl => ignore(self.layout.move_down())
    _ => return false
  }
  true
}

///|
/// Click to position the caret; use the wheel to browse independently of it.
pub fn Viewer::mouse(self : Viewer, event : @input.MouseEvent) -> Bool {
  self.layout.mouse(event)
}

///|
pub fn Viewer::draw(
  self : Viewer,
  frame : @tui.Frame,
  area : @tui.Rect,
  focused~ : Bool = false,
  highlight? : (String) -> Array[@tui.Span],
  line_numbers? : @tui.Style,
  current_line? : @tui.Style,
  line_style? : (Int32) -> @tui.Style,
) -> Unit {
  self.height = area.height
  self.layout.draw(
    frame,
    area,
    focused~,
    highlight?,
    line_numbers?,
    current_line?,
    line_style?,
  )
}
