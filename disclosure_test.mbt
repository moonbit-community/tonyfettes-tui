///|
test "collapsed header is one row and retains wide styled title" {
  let disclosure = @tui.Disclosure()
  let style = @tui.Style(fg=Basic(Red), italic=true)
  let lines = disclosure.lines(
    @tui.Line::from_text("你好世界", style~),
    [@tui.Line::from_text("hidden")],
    width=7,
    selected=true,
  )
  assert_eq(lines.length(), 1)
  assert_eq(lines[0].to_text(), "▸ 你好…")
  let frame = @tui.Frame(width=7, height=1)
  frame.lines(frame.area(), lines)
  assert_eq(
    frame.style_at(row=0, col=2),
    @tui.Style(fg=Basic(Red), italic=true, bold=true, reverse=true),
  )
}

///|
test "expanded content wraps with indentation and preserves colors" {
  let disclosure = @tui.Disclosure(expanded=true)
  let lines = disclosure.lines(
    @tui.Line::from_text("details"),
    [@tui.Line::from_text("你好世界", style=@tui.Style(fg=Basic(Green)))],
    width=6,
  )
  assert_eq(lines.map(line => line.to_text()), [
    "▾ det…", "  你好", "  世界",
  ])
  let frame = @tui.Frame(width=6, height=3)
  frame.lines(frame.area(), lines)
  assert_eq(frame.style_at(row=2, col=2), @tui.Style(fg=Basic(Green)))
  assert_eq(
    disclosure.lines(@tui.Line::from_text("title"), [], width=0).length(),
    0,
  )
  assert_eq(
    disclosure.lines(@tui.Line::from_text("title"), [], width=1)[0].to_text(),
    "…",
  )
}

///|
test "only matching stationary header clicks expand" {
  let disclosure = @tui.Disclosure()
  let header = @tui.Rect(row=4, col=3, width=12, height=1)
  assert_true(
    !disclosure.mouse(@input.MouseEvent::new(Press(Left), 6, 5), header),
  )
  assert_true(
    disclosure.mouse(@input.MouseEvent::new(Press(Left), 5, 5), header),
  )
  assert_true(
    !disclosure.mouse(@input.MouseEvent::new(Drag(Left), 5, 7), header),
  )
  assert_true(
    !disclosure.mouse(@input.MouseEvent::new(Release(Left), 5, 5), header),
  )
  assert_true(!disclosure.expanded())
  assert_true(
    disclosure.mouse(@input.MouseEvent::new(Press(Left), 5, 5), header),
  )
  assert_true(
    disclosure.mouse(@input.MouseEvent::new(Release(Left), 5, 5), header),
  )
  assert_true(disclosure.expanded())
  assert_true(
    disclosure.mouse(@input.MouseEvent::new(Press(Left), 5, 5), header),
  )
  assert_true(
    !disclosure.mouse(
      @input.MouseEvent::new(Release(Left), 5, 5),
      @tui.Rect(row=4, col=3, width=10, height=1),
    ),
  )
  assert_true(disclosure.expanded())
}

///|
test "keyboard toggles only selected header on an unmodified press" {
  let disclosure = @tui.Disclosure()
  assert_true(!disclosure.key(@input.KeyEvent::new(Enter), selected=false))
  assert_true(disclosure.key(@input.KeyEvent::new(Enter), selected=true))
  assert_true(disclosure.expanded())
  assert_true(
    !disclosure.key(@input.KeyEvent::new(Enter, kind=Repeat), selected=true),
  )
  assert_true(
    !disclosure.key(@input.KeyEvent::new(Enter, kind=Release), selected=true),
  )
  assert_true(
    !disclosure.key(
      @input.KeyEvent::new(
        Char(' '),
        modifiers=@input.KeyModifiers::new(ctrl=true),
      ),
      selected=true,
    ),
  )
  assert_true(disclosure.key(@input.KeyEvent::new(Char(' ')), selected=true))
  assert_true(!disclosure.expanded())
}
