///|
test "viewer navigates source without admitting editing actions" {
  let source = "\t中🌙ab\r\nsecond\r\nthird"
  let viewer = @viewer.Viewer(source~)
  let frame = @tui.Frame(width=30, height=3)
  viewer.draw(frame, frame.area(), focused=true)
  assert_true(viewer.navigate(@input.KeyEvent::new(Right)))
  assert_eq(viewer.source_position(), (0, 1))
  assert_true(viewer.navigate(@input.KeyEvent::new(End)))
  assert_eq(viewer.source_position(), (0, 6))
  for
    code in (
      [Text, Char('x'), Enter, Tab, Backspace, Delete] : Array[@input.KeyCode]) {
    assert_true(!viewer.navigate(@input.KeyEvent::new(code, text="edit")))
  }
  for
    code in (
      [
        Char('s'),
        Char('z'),
        Char('y'),
        Char('j'),
        Char('k'),
        Char('u'),
        Char('w'),
        Char('d'),
      ] : Array[@input.KeyCode]) {
    assert_true(
      !viewer.navigate(
        @input.KeyEvent::new(
          code,
          modifiers=@input.KeyModifiers::new(ctrl=true),
        ),
      ),
    )
  }
  assert_eq(viewer.source(), source)
  assert_true(viewer.navigate(@input.KeyEvent::new(PageDown)))
  assert_eq(viewer.source_position().0, 2)
}

///|
test "viewer replaces disk snapshots while preserving its source location" {
  let viewer = @viewer.Viewer(source="first\nsecond")
  viewer.goto_source(line=1, character=3)
  viewer.set_source("changed\nnew content")
  assert_eq(viewer.source_position(), (1, 3))
  let frame = @tui.Frame(width=25, height=4)
  viewer.draw(frame, frame.area(), line_numbers=@tui.Style())
  assert_eq(viewer.source_at(row=1, col=3), Some((1, 0)))
  assert_true(viewer.mouse(@input.MouseEvent::new(Press(Left), 1, 4)))
  assert_eq(viewer.source_position(), (0, 0))
  assert_eq(viewer.source(), "changed\nnew content")
}
