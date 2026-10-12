///|
/// A model of the terminal screen, just detailed enough to replay the commands
/// `diff` produces and compare the result with the frame it was asked to show.
priv struct Screen {
  grid : Frame
  mut row : Int32
  mut col : Int32
  mut pen : Style
  mut cursor_shown : Bool
}

///|
/// A screen whose content is unknown to the renderer: every cell holds junk.
fn Screen::Screen(width~ : Int32, height~ : Int32) -> Screen {
  let grid = Frame(width~, height~)
  for row in 0..<height {
    for col in 0..<width {
      grid.put(row, col, "?", Style(reverse=true), 1)
    }
  }
  { grid, row: 0, col: 0, pen: Style(), cursor_shown: true, }
}

///|
fn Screen::apply(self : Screen, commands : Array[@tty.Command]) -> Unit raise {
  for command in commands {
    match command {
      CursorPosition(row, col) => {
        self.row = row - 1
        self.col = col - 1
      }
      Print(text) => {
        let glyphs = []
        push_glyphs(glyphs, text, self.pen)
        self.col = self.grid.paint(
          self.row,
          self.col,
          glyphs,
          left=0,
          right=self.grid.width,
        )
      }
      EraseDisplay => self.grid.fill(self.grid.area(), style=self.pen)
      ResetStyle => self.pen = Style()
      SetForeground(fg) => self.pen = { ..self.pen, fg, }
      SetBackground(bg) => self.pen = { ..self.pen, bg, }
      SetBold => self.pen = { ..self.pen, bold: true, }
      SetItalic => self.pen = { ..self.pen, italic: true, }
      SetUnderline => self.pen = { ..self.pen, underline: true, }
      SetReverse => self.pen = { ..self.pen, reverse: true, }
      HideCursor => self.cursor_shown = false
      ShowCursor => self.cursor_shown = true
      command => fail("diff produced an unexpected command: \{Repr(command)}")
    }
  }
}

///|
/// Draw `next` on the screen through `diff` and check the screen then shows it.
fn Screen::draw(self : Screen, shown : Frame?, next : Frame) -> Unit raise {
  self.apply(diff(shown, next))
  if self.grid.width != next.width || self.grid.height != next.height {
    fail("the test resized the frame without resizing the screen")
  }
  assert_true(self.grid.cells == next.cells)
  assert_true(self.pen == Style())
  if next.cursor is Some(cursor) {
    assert_true(self.cursor_shown)
    @debug.assert_eq((self.row, self.col), (cursor.row, cursor.col))
  } else {
    assert_true(!self.cursor_shown)
  }
}

///|
test "first draw repaints everything" {
  let frame = Frame(width=6, height=2)
  frame.text(row=0, col=0, "ab")
  frame.text(row=1, col=2, "cd", style=Style(fg=Basic(Red), bold=true))
  debug_inspect(
    diff(None, frame),
    content=(
      #|[
      #|  HideCursor,
      #|  ResetStyle,
      #|  EraseDisplay,
      #|  CursorPosition(1, 1),
      #|  Print(<StringView: "ab">),
      #|  CursorPosition(2, 3),
      #|  ResetStyle,
      #|  SetForeground(Basic(Red)),
      #|  SetBold,
      #|  Print(<StringView: "cd">),
      #|  ResetStyle,
      #|]
    ),
  )
  Screen(width=6, height=2).draw(None, frame)
}

///|
test "identical frames need no commands" {
  let frame = Frame(width=6, height=2)
  frame.text(row=0, col=0, "ab")
  frame.set_cursor(frame.area(), row=0, col=2)
  let same = Frame(width=6, height=2)
  same.text(row=0, col=0, "ab")
  same.set_cursor(same.area(), row=0, col=2)
  debug_inspect(
    diff(Some(frame), same),
    content=(
      #|[]
    ),
  )
}

///|
test "only changed cells are repainted, as one run when adjacent" {
  let old = Frame(width=10, height=2)
  old.text(row=0, col=0, "count: 9")
  old.text(row=1, col=0, "ready")
  let next = Frame(width=10, height=2)
  next.text(row=0, col=0, "count: 10")
  next.text(row=1, col=0, "ready")
  debug_inspect(
    diff(Some(old), next),
    content=(
      #|[CursorPosition(1, 8), Print(<StringView: "10">)]
    ),
  )
}

///|
test "moving only the cursor does not repaint cells" {
  let old = Frame(width=6, height=1)
  old.text(row=0, col=0, "abc")
  old.set_cursor(old.area(), row=0, col=1)
  let next = Frame(width=6, height=1)
  next.text(row=0, col=0, "abc")
  next.set_cursor(next.area(), row=0, col=2)
  debug_inspect(
    diff(Some(old), next),
    content=(
      #|[CursorPosition(1, 3), ShowCursor]
    ),
  )
  let hidden = Frame(width=6, height=1)
  hidden.text(row=0, col=0, "abc")
  debug_inspect(
    diff(Some(next), hidden),
    content=(
      #|[HideCursor]
    ),
  )
}

///|
test "a frame of a different size repaints everything" {
  let old = Frame(width=6, height=1)
  old.text(row=0, col=0, "abc")
  let next = Frame(width=4, height=1)
  next.text(row=0, col=0, "abc")
  debug_inspect(
    diff(Some(old), next),
    content=(
      #|[
      #|  HideCursor,
      #|  ResetStyle,
      #|  EraseDisplay,
      #|  CursorPosition(1, 1),
      #|  Print(<StringView: "abc">),
      #|]
    ),
  )
}

///|
test "replaying diffs reproduces each frame, including wide graphemes" {
  let texts = [
    "hello", "你好世界", "a你b好c", " 你好", "héllo wörld", "", "ab", "世界你好ab",
    "x", "你",
  ]
  let styles = [
    Style(),
    Style(fg=Basic(Red)),
    Style(bg=Indexed(42), bold=true),
    Style(underline=true, italic=true),
    Style(reverse=true),
  ]
  let width = 9
  let height = 3
  let screen = Screen(width~, height~)
  let mut shown : Frame? = None
  // A small linear congruential generator keeps the frames varied but the
  // test deterministic.
  let mut seed = 12345
  for _ in 0..<300 {
    let frame = Frame(width~, height~)
    for _ in 0..<4 {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff
      let text = texts[seed / 7 % texts.length()]
      let style = styles[seed / 11 % styles.length()]
      let row = seed / 13 % height
      let col = seed / 17 % (width + 2) - 2
      frame.text(row~, col~, text, style~)
    }
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    if seed % 3 != 0 {
      frame.set_cursor(
        frame.area(),
        row=seed / 5 % height,
        col=seed / 7 % width,
      )
    }
    screen.draw(shown, frame)
    shown = Some(frame)
  }
}

///|
test "replaying a diff after the screen content became unknown" {
  let frame = Frame(width=5, height=2)
  frame.text(row=0, col=0, "你好")
  let screen = Screen(width=5, height=2)
  screen.draw(None, frame)
  // Something else scribbled on the screen, as after a resize.
  screen.grid.put(1, 1, "!", Style(), 1)
  screen.cursor_shown = true
  screen.draw(None, frame)
}
