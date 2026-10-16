///|
test "screen preserves split UTF-8, styled cells and combining marks" {
  let screen = @terminal.Screen(cols=12, rows=3)
  defer screen.close()
  screen.feed(b"\x1b[1;31mA\x1b[0m\xe4\xbd")
  screen.feed(b"\xa0e\xcc\x81\r\nnext")
  let frame = @tui.Frame(width=16, height=5)
  screen.draw(frame, @tui.Rect(row=1, col=2, width=12, height=3))
  assert_true(frame.to_text().contains("A你e\u0301"))
  assert_true(frame.to_text().contains("next"))
  assert_true(frame.style_at(row=1, col=2).bold)
  assert_true(
    frame.style_at(row=1, col=2).fg != frame.style_at(row=1, col=3).fg,
  )
  assert_eq(frame.cursor(), Some(@tui.Cursor(row=2, col=6)))
}

///|
test "screen handles alternate-screen lifecycle and cursor visibility" {
  let screen = @terminal.Screen(cols=10, rows=2)
  defer screen.close()
  screen.feed(b"primary\x1b[?1049h\x1b[Halternate\x1b[?25l")
  let alternate = @tui.Frame(width=10, height=2)
  screen.draw(alternate, alternate.area())
  assert_true(alternate.to_text().contains("alternate"))
  assert_eq(alternate.cursor(), None)
  screen.feed(b"\x1b[?1049l\x1b[?25h")
  let primary = @tui.Frame(width=10, height=2)
  screen.draw(primary, primary.area())
  assert_true(primary.to_text().contains("primary"))
  assert_eq(primary.cursor(), Some(@tui.Cursor(row=0, col=7)))
  let unfocused = @tui.Frame(width=10, height=2)
  screen.draw(unfocused, unfocused.area(), focused=false)
  assert_eq(unfocused.cursor(), None)
}

///|
test "screen answers terminal queries and exposes the process title" {
  let screen = @terminal.Screen(cols=20, rows=4)
  defer screen.close()
  assert_eq(screen.title(), None)
  screen.feed(b"\x1b]0;terminal title\x07\x1b[2;4H\x1b[6n")
  assert_eq(screen.title(), Some("terminal title"))
  assert_eq(screen.take_reply(), b"\x1b[2;4R")
  assert_eq(screen.take_reply(), b"")
  screen.resize(cols=30, rows=5)
  assert_eq(screen.cols(), 30)
  assert_eq(screen.rows(), 5)
  screen.feed(b"\x1b[18t")
  assert_eq(screen.take_reply(), b"\x1b[8;5;30t")
  screen.resize(cols=0, rows=0)
  assert_eq(screen.cols(), 1)
  assert_eq(screen.rows(), 1)
}

///|
test "screen input follows application cursor, paste and focus modes" {
  let screen = @terminal.Screen(cols=10, rows=2)
  defer screen.close()
  let up = @input.KeyEvent::new(Up)
  assert_eq(screen.key(up), b"\x1b[A")
  assert_eq(
    screen.key(
      @input.KeyEvent::new(
        Char('c'),
        modifiers=@input.KeyModifiers::new(ctrl=true),
      ),
    ),
    b"\x03",
  )
  assert_eq(screen.key(@input.KeyEvent::new(Char('你'))), @utf8.encode("你"))
  assert_eq(screen.key(@input.KeyEvent::new(Char('a'), kind=Release)), b"")
  assert_eq(screen.paste("hello\nworld"), b"hello\rworld")
  assert_eq(screen.focus(true), b"")
  screen.feed(b"\x1b[?1h\x1b[?2004h\x1b[?1004h")
  assert_eq(screen.key(up), b"\x1bOA")
  assert_eq(screen.paste("hello\nworld"), b"\x1b[200~hello\nworld\x1b[201~")
  assert_eq(screen.focus(true), b"\x1b[I")
  assert_eq(screen.focus(false), b"\x1b[O")
}

///|
test "screen mouse input uses child reporting modes" {
  let screen = @terminal.Screen(cols=10, rows=4)
  defer screen.close()
  let press = @input.MouseEvent::new(Press(Left), 1, 2)
  assert_eq(screen.mouse(press), b"")
  screen.feed(b"\x1b[?1000h\x1b[?1006h")
  assert_eq(screen.mouse(press), b"\x1b[<0;3;2M")
  assert_eq(
    screen.mouse(@input.MouseEvent::new(Release(Left), 1, 2)),
    b"\x1b[<0;3;2m",
  )
  assert_eq(
    screen.mouse(@input.MouseEvent::new(Scroll(Up), 1, 2)),
    b"\x1b[<64;3;2M",
  )
}

///|
test "screen scrollback can return to live output" {
  let screen = @terminal.Screen(cols=10, rows=2)
  defer screen.close()
  screen.feed(b"first\r\nsecond\r\nthird\r\nfourth")
  screen.scroll(-10)
  let old = @tui.Frame(width=10, height=2)
  screen.draw(old, old.area())
  assert_true(old.to_text().contains("first"))
  screen.scroll_to_bottom()
  let live = @tui.Frame(width=10, height=2)
  screen.draw(live, live.area())
  assert_true(live.to_text().contains("fourth"))
}

///|
#cfg(not(platform="windows"))
async test "real PTY output and resized shell render through Ghostty" {
  @async.with_timeout(5000, () => {
    @async.with_task_group() <| group => {
      let pty = @pty.spawn(
        group,
        "/bin/sh",
        ["-c", "read line; stty size; printf '\\033[32m%s\\033[0m' \"$line\""],
        rows=4,
        cols=20,
      )
      pty.resize(rows=5, cols=30)
      let screen = @terminal.Screen(cols=30, rows=5)
      defer screen.close()
      pty.write(screen.paste("PTY ready\n"))
      let output = pty.read_all().text()
      assert_eq(pty.wait(), 0)
      screen.feed(@utf8.encode(output))
      let frame = @tui.Frame(width=30, height=5)
      screen.draw(frame, frame.area())
      assert_true(frame.to_text().contains("5 30"))
      assert_true(frame.to_text().contains("PTY ready"))
    }
  })
}

///|
test "alternate-screen wheel scrolling becomes application cursor input" {
  let screen = @terminal.Screen(cols=10, rows=4)
  defer screen.close()
  screen.feed(b"\x1b[?1049h\x1b[?1007h\x1b[?1h")
  assert_eq(
    screen.mouse(@input.MouseEvent::new(Scroll(Up), 1, 2)),
    b"\x1bOA\x1bOA\x1bOA",
  )
}

///|
test "screen keyboard protocol preserves key releases requested by the child" {
  let screen = @terminal.Screen(cols=10, rows=2)
  defer screen.close()
  screen.feed(b"\x1b[>2u")
  assert_eq(screen.key(@input.KeyEvent::new(F1, kind=Release)), b"\x1b[1;1:3P")
}
