///|
test "source hit testing maps wrapped CJK tabs and emoji to UTF16" {
  let editor = @editor.Editor(text="\t中🌙ab\r\nnext", preserve_text=true)
  editor.move_to_start()
  let frame = @tui.Frame(width=20, height=8)
  // 3-cell gutter, 8 text cells, 7 usable cells before wrapping.
  editor.draw(
    frame,
    @tui.Rect(row=2, col=4, width=11, height=5),
    line_numbers=@tui.Style(),
  )
  assert_eq(editor.source_at(row=2, col=4), None)
  assert_eq(editor.source_at(row=2, col=7), Some((0, 0)))
  assert_eq(editor.source_at(row=2, col=10), Some((0, 0)))
  assert_eq(editor.source_at(row=2, col=11), Some((0, 1)))
  assert_eq(editor.source_at(row=2, col=12), Some((0, 1)))
  assert_eq(editor.source_at(row=2, col=13), None)
  assert_eq(editor.source_at(row=3, col=7), Some((0, 2)))
  assert_eq(editor.source_at(row=3, col=8), Some((0, 2)))
  assert_eq(editor.source_at(row=3, col=9), Some((0, 4)))
  assert_eq(editor.source_at(row=4, col=7), Some((1, 0)))
  assert_eq(editor.source_at(row=5, col=7), None)
  assert_eq(editor.source_position(), (0, 0))
  editor.goto_source(line=0, character=3)
  assert_eq(editor.source_position(), (0, 2))
  editor.goto_source(line=0, character=999)
  assert_eq(editor.source_position(), (0, 6))
  editor.goto_source(line=1, character=2)
  assert_eq(editor.source_position(), (1, 2))
  editor.goto_source(line=999, character=0)
  assert_eq(editor.source_position(), (1, 4))
}

///|
test "source hits follow wheel viewport and clear on hidden draw" {
  let editor = @editor.Editor(
    text="zero\none\ntwo\nthree\nfour\nfive",
    preserve_text=true,
  )
  editor.move_to_start()
  let frame = @tui.Frame(width=20, height=2)
  editor.draw(frame, frame.area())
  assert_eq(editor.source_at(row=0, col=0), Some((0, 0)))
  ignore(editor.mouse(@input.MouseEvent::new(Scroll(Down), 1, 1)))
  editor.draw(frame, frame.area())
  assert_eq(editor.source_at(row=0, col=0), Some((3, 0)))
  assert_eq(editor.source_position(), (0, 0))
  editor.draw(frame, @tui.Rect(row=0, col=0, width=0, height=0))
  assert_eq(editor.source_at(row=0, col=0), None)
}
