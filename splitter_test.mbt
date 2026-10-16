///|
test "horizontal splitter captures outside drag and applies pane limits" {
  let split = @tui.Splitter(
    axis=Horizontal,
    position=5,
    min_first=3,
    min_second=4,
    max_first=9,
  )
  let frame = @tui.Frame(width=20, height=6)
  let (first, second) = split.draw(
    frame,
    @tui.Rect(row=1, col=2, width=15, height=4),
  )
  assert_eq(first, @tui.Rect(row=1, col=2, width=5, height=4))
  assert_eq(second, @tui.Rect(row=1, col=8, width=9, height=4))
  assert_true(!split.mouse(@input.MouseEvent::new(Drag(Left), 3, 8)))
  assert_true(split.mouse(@input.MouseEvent::new(Press(Left), 3, 8)))
  assert_true(split.mouse(@input.MouseEvent::new(Scroll(Down), 100, 100)))
  assert_true(split.mouse(@input.MouseEvent::new(Drag(Left), 100, 100)))
  assert_eq(split.position(), 9)
  assert_true(split.mouse(@input.MouseEvent::new(Release(Left), 1, 1)))
  assert_eq(split.position(), 3)
  assert_true(!split.dragging())
  assert_true(!split.mouse(@input.MouseEvent::new(Drag(Left), 3, 8)))
}

///|
test "vertical splitter draws across its clipped bounds" {
  let split = @tui.Splitter(axis=Vertical, position=2)
  let frame = @tui.Frame(width=8, height=6)
  let (first, second) = split.draw(
    frame,
    @tui.Rect(row=1, col=2, width=20, height=20),
  )
  assert_eq(first, @tui.Rect(row=1, col=2, width=6, height=2))
  assert_eq(second, @tui.Rect(row=4, col=2, width=6, height=2))
  assert_true(frame.to_text().contains("  ──────"))
  assert_true(split.mouse(@input.MouseEvent::new(Press(Left), 4, 4)))
  assert_true(split.mouse(@input.MouseEvent::new(Release(Left), 6, 4)))
  assert_eq(split.position(), 4)
}

///|
test "bounds changes and explicit cancellation release capture" {
  let split = @tui.Splitter(
    axis=Horizontal,
    position=5,
    min_first=4,
    min_second=4,
  )
  let frame = @tui.Frame(width=12, height=4)
  ignore(split.draw(frame, frame.area()))
  assert_true(split.mouse(@input.MouseEvent::new(Press(Left), 2, 6)))
  let small = @tui.Frame(width=4, height=2)
  let (first, second) = split.draw(small, small.area())
  assert_true(!split.dragging())
  assert_eq(first.width, 3)
  assert_eq(second.width, 0)
  assert_true(!split.mouse(@input.MouseEvent::new(Release(Left), 2, 12)))
  assert_true(split.mouse(@input.MouseEvent::new(Press(Left), 1, 4)))
  split.cancel()
  assert_true(!split.dragging())
}

///|
test "empty split does not capture a pointer" {
  let split = @tui.Splitter(axis=Horizontal, position=10)
  let frame = @tui.Frame(width=0, height=0)
  let (first, second) = split.draw(frame, frame.area())
  assert_eq(first.width, 0)
  assert_eq(second.width, 0)
  assert_true(!split.mouse(@input.MouseEvent::new(Press(Left), 1, 1)))
}
