///|
/// Encode a key using the child's cursor, keypad and keyboard protocol modes.
pub fn Screen::key(self : Screen, event : @input.KeyEvent) -> Bytes {
  let key = @vt_input.KeyEvent::new()
  key.set_key(key_code(event.code))
  key.set_mods(key_modifiers(event.modifiers))
  key.set_action(
    match event.kind {
      Press => @vt_input.Press
      Repeat => @vt_input.Repeat
      Release => @vt_input.Release
    },
  )
  let text = event.text.unwrap_or_else(() => {
    match event.code {
      Char(c) => c.to_string()
      _ => ""
    }
  })
  key.set_utf8(@utf8.encode(text))
  if event.base_code.unwrap_or(event.code) is @input.Char(c) {
    key.set_unshifted_codepoint(c.to_uint())
  }
  self.terminal.sync_key_encoder(self.keyboard)
  self.keyboard.encode(key)
}

///|
/// Encode a paste according to bracketed-paste mode. Ghostty sanitizes embedded
/// terminal control characters and normalizes newlines for ordinary shells.
pub fn Screen::paste(self : Screen, text : StringView) -> Bytes {
  @paste.PasteOptions::new(self.terminal.mode_get(BracketedPaste)).encode(
    @utf8.encode(text),
  )
}

///|
/// Encode focus reporting when the child has requested it.
pub fn Screen::focus(self : Screen, focused : Bool) -> Bytes {
  if !self.terminal.mode_get(FocusEvent) {
    b""
  } else if focused {
    @focus.FocusEvent::Gained.encode()
  } else {
    @focus.FocusEvent::Lost.encode()
  }
}

///|
/// Encode a mouse event whose row and column are zero-based relative to the
/// terminal pane. Subtract the tty event's one-based origin before translating.
/// Wheel scrolling moves through local scrollback when mouse reporting is off.
pub fn Screen::mouse(self : Screen, event : @input.MouseEvent) -> Bytes {
  if !self.terminal.mouse_tracking() {
    if event.kind is @input.Scroll(direction) {
      if self.terminal.active_screen() is Alternate &&
        self.terminal.mode_get(MouseAlternateScroll) {
        let key : @input.KeyCode = match direction {
          Up => @input.Up
          Down => @input.Down
          Left => @input.Left
          Right => @input.Right
        }
        let sequence = self.key(@input.KeyEvent::new(key))
        return [..sequence, ..sequence, ..sequence]
      }
      match direction {
        Up => self.scroll(-3)
        Down => self.scroll(3)
        _ => ()
      }
    }
    return b""
  }
  let mouse = @vt_input.MouseInputEvent::new()
  mouse.set_position(
    @vt_input.MousePosition::new(
      Float::from_int(event.col),
      Float::from_int(event.row),
    ),
  )
  mouse.set_mods(key_modifiers(event.modifiers))
  match event.kind {
    Press(button) => {
      mouse.set_action(@vt_input.Press)
      mouse.set_button(mouse_button(button))
      self.mouse_encoder.set_any_button_pressed(true)
    }
    Release(button) => {
      mouse.set_action(@vt_input.Release)
      mouse.set_button(mouse_button(button))
      self.mouse_encoder.set_any_button_pressed(false)
    }
    Drag(button) => {
      mouse.set_action(@vt_input.Motion)
      mouse.set_button(mouse_button(button))
    }
    Move => mouse.set_action(@vt_input.Motion)
    Scroll(direction) => {
      mouse.set_action(@vt_input.Press)
      mouse.set_button(
        match direction {
          Up => @vt_input.Four
          Down => @vt_input.Five
          Left => @vt_input.Six
          Right => @vt_input.Seven
        },
      )
    }
  }
  self.terminal.sync_mouse_encoder(self.mouse_encoder)
  self.mouse_encoder.encode(mouse)
}

///|
fn mouse_button(button : @input.MouseButton) -> @vt_input.MouseButton {
  match button {
    Left => @vt_input.Left
    Middle => @vt_input.Middle
    Right => @vt_input.Right
  }
}

///|
fn key_modifiers(modifiers : @input.KeyModifiers) -> @vt_input.KeyMods {
  @vt_input.KeyMods::new()
  .with_shift(modifiers.shift())
  .with_alt(modifiers.alt())
  .with_ctrl(modifiers.ctrl())
  .with_super_(modifiers.super_() || modifiers.meta())
}

///|
fn key_code(code : @input.KeyCode) -> @vt_input.Key {
  match code {
    Char(' ') => Space
    Char('a' | 'A') => KeyA
    Char('b' | 'B') => KeyB
    Char('c' | 'C') => KeyC
    Char('d' | 'D') => KeyD
    Char('e' | 'E') => KeyE
    Char('f' | 'F') => KeyF
    Char('g' | 'G') => KeyG
    Char('h' | 'H') => KeyH
    Char('i' | 'I') => KeyI
    Char('j' | 'J') => KeyJ
    Char('k' | 'K') => KeyK
    Char('l' | 'L') => KeyL
    Char('m' | 'M') => KeyM
    Char('n' | 'N') => KeyN
    Char('o' | 'O') => KeyO
    Char('p' | 'P') => KeyP
    Char('q' | 'Q') => KeyQ
    Char('r' | 'R') => KeyR
    Char('s' | 'S') => KeyS
    Char('t' | 'T') => KeyT
    Char('u' | 'U') => KeyU
    Char('v' | 'V') => KeyV
    Char('w' | 'W') => KeyW
    Char('x' | 'X') => KeyX
    Char('y' | 'Y') => KeyY
    Char('z' | 'Z') => KeyZ
    Char('0' | ')') => Digit0
    Char('1' | '!') => Digit1
    Char('2' | '@') => Digit2
    Char('3' | '#') => Digit3
    Char('4' | '$') => Digit4
    Char('5' | '%') => Digit5
    Char('6' | '^') => Digit6
    Char('7' | '&') => Digit7
    Char('8' | '*') => Digit8
    Char('9' | '(') => Digit9
    Char('`' | '~') => Backquote
    Char('\\' | '|') => Backslash
    Char('[' | '{') => BracketLeft
    Char(']' | '}') => BracketRight
    Char(',' | '<') => Comma
    Char('=' | '+') => Equal
    Char('-' | '_') => Minus
    Char('.' | '>') => Period
    Char('\'' | '"') => Quote
    Char(';' | ':') => Semicolon
    Char('/' | '?') => Slash
    Enter => Enter
    Tab => Tab
    Backspace => Backspace
    Delete => Delete
    Escape => Escape
    Up => ArrowUp
    Down => ArrowDown
    Left => ArrowLeft
    Right => ArrowRight
    Home => Home
    End => End
    PageUp => PageUp
    PageDown => PageDown
    Insert => Insert
    F1 => F1
    F2 => F2
    F3 => F3
    F4 => F4
    F5 => F5
    F6 => F6
    F7 => F7
    F8 => F8
    F9 => F9
    F10 => F10
    F11 => F11
    F12 => F12
    F13 => F13
    F14 => F14
    F15 => F15
    F16 => F16
    F17 => F17
    F18 => F18
    F19 => F19
    F20 => F20
    F21 => F21
    F22 => F22
    F23 => F23
    F24 => F24
    F25 => F25
    CapsLock => CapsLock
    ScrollLock => ScrollLock
    NumLock => NumLock
    PrintScreen => PrintScreen
    Pause => Pause
    Menu => ContextMenu
    KeypadBegin => NumpadBegin
    Keypad0 => Numpad0
    Keypad1 => Numpad1
    Keypad2 => Numpad2
    Keypad3 => Numpad3
    Keypad4 => Numpad4
    Keypad5 => Numpad5
    Keypad6 => Numpad6
    Keypad7 => Numpad7
    Keypad8 => Numpad8
    Keypad9 => Numpad9
    KeypadDecimal => NumpadDecimal
    KeypadDivide => NumpadDivide
    KeypadMultiply => NumpadMultiply
    KeypadMinus => NumpadSubtract
    KeypadPlus => NumpadAdd
    KeypadEnter => NumpadEnter
    KeypadEqual => NumpadEqual
    KeypadSeparator => NumpadSeparator
    _ => Unidentified
  }
}
