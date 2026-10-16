///|
priv struct MouseState {
  mut buttons : Int32
}

///|
fn MouseState::MouseState() -> MouseState {
  { buttons: 0, }
}

///|
fn button_bit(button : @input.MouseButton) -> Int32 {
  match button {
    Left => 1
    Middle => 2
    Right => 4
  }
}

///|
// Ghostty can retain a stale right-button state across a context menu and
// report ordinary motion as SGR 34 (Drag(Right)). Only accept a drag for a
// button pressed during this terminal session; an unmatched drag is motion.
// https://github.com/ghostty-org/ghostty/discussions/12078
fn MouseState::event(self : MouseState, event : @tty.Event) -> @tty.Event {
  match event {
    Input(Mouse(mouse)) =>
      match mouse.kind {
        Press(button) => self.buttons = self.buttons | button_bit(button)
        Release(button) =>
          self.buttons = self.buttons & button_bit(button).lnot()
        Move => self.buttons = 0
        Drag(button) if (self.buttons & button_bit(button)) == 0 =>
          return Input(
            Mouse(
              @input.MouseEvent::new(
                Move,
                mouse.row,
                mouse.col,
                modifiers=mouse.modifiers,
              ),
            ),
          )
        _ => ()
      }
    Input(FocusOut) | Resize(_) => self.buttons = 0
    _ => ()
  }
  event
}
