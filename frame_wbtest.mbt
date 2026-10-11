///|
test "set_cursor is relative to its area and stays inside it" {
  let frame = Frame(width=10, height=5)
  let area = Rect(row=2, col=3, width=4, height=2)
  assert_true(frame.cursor is None)
  frame.set_cursor(area, col=2)
  assert_true(frame.cursor == Some({ row: 2, col: 5, }))
  frame.set_cursor(area, row=9, col=9)
  assert_true(frame.cursor == Some({ row: 3, col: 6, }))
  // An area that sticks out of the frame is cut to the frame first.
  frame.set_cursor(Rect(row=4, col=8, width=10, height=10), row=5, col=5)
  assert_true(frame.cursor == Some({ row: 4, col: 9, }))
}

///|
test "clipping a frame drops a wide grapheme cut by the edge" {
  let frame = Frame(width=6, height=2)
  frame.text(row=0, col=0, "ab你好")
  frame.text(row=1, col=0, "abcdef")
  frame.set_cursor(frame.area(), row=1, col=5)
  let clipped = frame.clipped(width=5, height=1)
  inspect(
    clipped.to_text(),
    content=(
      #|ab你
    ),
  )
  assert_true(clipped.cursor == Some({ row: 0, col: 4, }))
  // A frame that already fits is copied unchanged.
  let same = frame.clipped(width=80, height=24)
  assert_true(same.cells == frame.cells && same.cursor == frame.cursor)
}
