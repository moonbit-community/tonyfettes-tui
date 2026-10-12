///|
/// Accumulates the terminal commands that repaint changed cells, tracking where
/// the terminal cursor is and which style is active so it only moves or
/// restyles when needed.
priv struct Painter {
  commands : Array[@tty.Command]
  run : StringBuilder
  mut pen : Style
  mut row : Int32
  mut col : Int32
}

///|
fn Painter::Painter() -> Painter {
  { commands: [], run: StringBuilder(), pen: Style(), row: -1, col: -1, }
}

///|
/// Emit the text collected so far as one `Print`.
fn Painter::flush(self : Painter) -> Unit {
  if !self.run.is_empty() {
    self.commands.push(Print(self.run.to_string()))
    self.run.reset()
  }
}

///|
fn Painter::set_style(self : Painter, style : Style) -> Unit {
  if style == self.pen {
    return
  }
  self.flush()
  // Reset first so attributes of the previous style cannot leak into this one.
  self.commands.push(ResetStyle)
  if style.fg != Default {
    self.commands.push(SetForeground(style.fg))
  }
  if style.bg != Default {
    self.commands.push(SetBackground(style.bg))
  }
  if style.bold {
    self.commands.push(SetBold)
  }
  if style.italic {
    self.commands.push(SetItalic)
  }
  if style.underline {
    self.commands.push(SetUnderline)
  }
  if style.reverse {
    self.commands.push(SetReverse)
  }
  self.pen = style
}

///|
/// Paint `cell` at the 0-based (`row`, `col`).
fn Painter::paint(
  self : Painter,
  row : Int32,
  col : Int32,
  cell : Cell,
) -> Unit {
  if self.row != row || self.col != col {
    self.flush()
    self.commands.push(CursorPosition(row + 1, col + 1))
  }
  self.set_style(cell.style)
  self.run.write_string(cell.text)
  self.row = row
  self.col = col + cell.width
}

///|
/// Finish painting and return the commands. The terminal is left in the
/// default style.
fn Painter::finish(self : Painter) -> Array[@tty.Command] {
  self.set_style(Style())
  self.flush()
  self.commands
}

///|
/// The terminal commands that turn a screen showing `shown` into one showing
/// `next`. `shown` is `None` when the screen content is unknown, which repaints
/// everything; so does a change of frame size.
///
/// The commands assume the terminal is in the default style and leave it there.
/// An empty result means the two frames look the same.
fn diff(shown : Frame?, next : Frame) -> Array[@tty.Command] {
  let old : Frame? = if shown is Some(frame) &&
    frame.width == next.width &&
    frame.height == next.height {
    shown
  } else {
    None
  }
  let painter = Painter()
  for row in 0..<next.height {
    for col in 0..<next.width {
      let cell = next.cell(row, col)
      // A continuation cell is painted by the wide grapheme to its left.
      if cell.width == 0 {
        continue
      }
      let unchanged = if old is Some(old) {
        old.cell(row, col) == cell
      } else {
        cell == blank
      }
      if !unchanged {
        painter.paint(row, col, cell)
      }
    }
  }
  let cells = painter.finish()
  let commands : Array[@tty.Command] = []
  let cursor_was_shown = old is Some(old) && old.cursor is Some(_)
  if old is None {
    commands.push(HideCursor)
    commands.push(ResetStyle)
    commands.push(EraseDisplay)
  } else if !cells.is_empty() && cursor_was_shown {
    // Keep the cursor from visibly jumping around while cells are repainted.
    commands.push(HideCursor)
  }
  commands.append(cells)
  let cursor_unchanged = old is Some(old) && old.cursor == next.cursor
  if next.cursor is Some(cursor) {
    // Painting cells moves the terminal cursor, so it has to be put back even
    // when the frame's cursor did not move.
    if !cells.is_empty() || !cursor_unchanged {
      commands.push(CursorPosition(cursor.row + 1, cursor.col + 1))
      commands.push(ShowCursor)
    }
  } else if cells.is_empty() && cursor_was_shown {
    commands.push(HideCursor)
  }
  commands
}
