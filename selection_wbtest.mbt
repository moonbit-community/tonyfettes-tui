///|
/// Mouse events at a 0-based frame cell, like every other coordinate in these
/// tests. The events themselves are 1-based.
fn press(row : Int32, col : Int32) -> @input.MouseEvent {
  @input.MouseEvent::new(Press(Left), row + 1, col + 1)
}

///|
fn drag(row : Int32, col : Int32) -> @input.MouseEvent {
  @input.MouseEvent::new(Drag(Left), row + 1, col + 1)
}

///|
fn release(row : Int32, col : Int32) -> @input.MouseEvent {
  @input.MouseEvent::new(Release(Left), row + 1, col + 1)
}

///|
/// The frame's rows, each followed by a row marking its reverse-video cells
/// with `^` when it has any.
fn shown(frame : Frame) -> String {
  let rows = []
  for row in 0..<frame.height {
    let text = StringBuilder()
    let marks = StringBuilder()
    let mut text_end = 0
    let mut marks_end = 0
    for col in 0..<frame.width {
      let cell = frame.cell(row, col)
      text.write_string(if cell.width == 0 { "" } else { cell.text })
      marks.write_string(if cell.style.reverse { "^" } else { " " })
      if cell.width > 0 && cell.text != " " {
        text_end = text.to_string().length()
      }
      if cell.style.reverse {
        marks_end = col + 1
      }
    }
    rows.push(text.to_string()[:text_end].to_owned())
    if marks_end > 0 {
      rows.push(marks.to_string()[:marks_end].to_owned())
    }
  }
  rows.join("\n")
}

///|
fn plain(texts : Array[String]) -> Array[Line] {
  texts.map(text => Line::from_text(text))
}

///|
/// Draw `lines` into an area that leaves one blank row and column around it,
/// so tests exercise coordinates that are not the frame's own.
fn draw(
  lines : Array[Line],
  selection : Selection,
  scroll? : Scroll,
  width~ : Int32 = 12,
  height~ : Int32 = 3,
  align~ : Align = Left,
) -> Frame {
  let frame = Frame(width=width + 2, height=height + 2)
  let area = Rect(row=1, col=1, width~, height~)
  frame.lines(area, lines, align~, scroll?, selection~)
  frame
}

///|
test "dragging within a line selects from the press to the pointer" {
  let lines = plain(["hello world"])
  let selection = Selection()
  ignore(draw(lines, selection))
  selection.mouse(press(1, 3))
  assert_true(selection.text() is None)
  selection.mouse(drag(1, 8))
  inspect(
    shown(draw(lines, selection)),
    content=(
      #|
      #| hello world
      #|   ^^^^^^
      #|
      #|
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|llo wo
    ),
  )
  selection.mouse(release(1, 8))
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|llo wo
    ),
  )
}

///|
test "dragging backwards selects the same text" {
  let lines = plain(["hello world"])
  let selection = Selection()
  ignore(draw(lines, selection))
  selection.mouse(press(1, 8))
  selection.mouse(drag(1, 3))
  inspect(
    shown(draw(lines, selection)),
    content=(
      #|
      #| hello world
      #|   ^^^^^^
      #|
      #|
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|llo wo
    ),
  )
}

///|
test "a selection across lines joins them with newlines" {
  let lines = plain(["first line", "second", "third line"])
  let selection = Selection()
  ignore(draw(lines, selection))
  selection.mouse(press(1, 7))
  selection.mouse(drag(3, 5))
  inspect(
    shown(draw(lines, selection)),
    content=(
      #|
      #| first line
      #|       ^^^^
      #| second
      #| ^^^^^^
      #| third line
      #| ^^^^^
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|line
      #|second
      #|third
    ),
  )
}

///|
test "a click without a drag selects nothing and removes the selection" {
  let lines = plain(["hello world"])
  let selection = Selection()
  ignore(draw(lines, selection))
  selection.mouse(press(1, 3))
  selection.mouse(release(1, 3))
  assert_true(selection.text() is None)
  selection.mouse(press(1, 3))
  selection.mouse(drag(1, 8))
  selection.mouse(release(1, 8))
  assert_true(selection.text() is Some(_))
  selection.mouse(press(1, 5))
  selection.mouse(release(1, 5))
  assert_true(selection.text() is None)
  inspect(
    shown(draw(lines, selection)),
    content=(
      #|
      #| hello world
      #|
      #|
      #|
    ),
  )
}

///|
test "a press outside the area does not start a selection" {
  let lines = plain(["hello world"])
  let selection = Selection()
  ignore(draw(lines, selection))
  // Row 0 and column 0 are outside the area, which starts at (1, 1).
  selection.mouse(press(0, 3))
  selection.mouse(drag(1, 8))
  assert_true(selection.text() is None)
  selection.mouse(press(1, 0))
  selection.mouse(drag(1, 8))
  assert_true(selection.text() is None)
}

///|
test "other buttons and the wheel are ignored" {
  let lines = plain(["hello world"])
  let selection = Selection()
  ignore(draw(lines, selection))
  selection.mouse(press(1, 3))
  selection.mouse(drag(1, 8))
  selection.mouse(@input.MouseEvent::new(Scroll(Up), 2, 4))
  selection.mouse(@input.MouseEvent::new(Drag(Right), 3, 1))
  selection.mouse(@input.MouseEvent::new(Move, 3, 1))
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|llo wo
    ),
  )
}

///|
test "dragging past the end of a line or below the last line" {
  let lines = plain(["short", "longer line"])
  let selection = Selection()
  ignore(draw(lines, selection))
  // Past the end of "short": nothing more to take from that line.
  selection.mouse(press(1, 3))
  selection.mouse(drag(1, 11))
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|ort
    ),
  )
  // The third row of the area is below the last line.
  selection.mouse(press(1, 3))
  selection.mouse(drag(3, 2))
  inspect(
    shown(draw(lines, selection)),
    content=(
      #|
      #| short
      #|   ^^^
      #| longer line
      #| ^^^^^^^^^^^
      #|
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|ort
      #|longer line
    ),
  )
}

///|
test "either half of a wide grapheme selects all of it" {
  let lines = plain(["你好世界"])
  let selection = Selection()
  ignore(draw(lines, selection))
  // Column 2 is the right half of the first grapheme; column 5 is the left
  // half of the third.
  selection.mouse(press(1, 2))
  selection.mouse(drag(1, 5))
  inspect(
    shown(draw(lines, selection)),
    content=(
      #|
      #| 你好世界
      #| ^^^^^^
      #|
      #|
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|你好世
    ),
  )
}

///|
test "wrapped lines are copied as the text was before wrapping" {
  let selection = Selection()
  let lines = Line::from_text("the quick brown fox jumps").wrap(10)
  ignore(draw(lines, selection))
  selection.mouse(press(1, 5))
  selection.mouse(drag(3, 12))
  inspect(
    shown(draw(lines, selection)),
    content=(
      #|
      #| the quick
      #|     ^^^^^
      #| brown fox
      #| ^^^^^^^^^
      #| jumps
      #| ^^^^^
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|quick brown fox jumps
    ),
  )
  // A word broken at the edge is joined without a space.
  let lines = Line::from_text("abcdefghij").wrap(4)
  ignore(draw(lines, selection))
  selection.mouse(press(1, 2))
  selection.mouse(drag(3, 12))
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|bcdefghij
    ),
  )
  // Separate lines still get a newline between them.
  let lines = [
    ..Line::from_text("one two three").wrap(8),
    Line::from_text("four"),
  ]
  ignore(draw(lines, selection))
  selection.mouse(press(1, 1))
  selection.mouse(drag(3, 12))
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|one two three
      #|four
    ),
  )
}

///|
test "a selection stays on its text while the area scrolls" {
  let lines = Array::makei(20, index => Line::from_text("line \{index}"))
  let selection = Selection()
  let scroll = Scroll()
  ignore(draw(lines, selection, scroll~))
  scroll.scroll_by(5)
  ignore(draw(lines, selection, scroll~))
  selection.mouse(press(2, 6))
  selection.mouse(drag(3, 4))
  selection.mouse(release(3, 4))
  inspect(
    shown(draw(lines, selection, scroll~)),
    content=(
      #|
      #| line 5
      #| line 6
      #|      ^
      #| line 7
      #| ^^^^
      #|
    ),
  )
  scroll.scroll_by(1)
  inspect(
    shown(draw(lines, selection, scroll~)),
    content=(
      #|
      #| line 6
      #|      ^
      #| line 7
      #| ^^^^
      #| line 8
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|6
      #|line
    ),
  )
  // Scrolled out of view, it is still there to be copied.
  scroll.to_top()
  inspect(
    shown(draw(lines, selection, scroll~)),
    content=(
      #|
      #| line 0
      #| line 1
      #| line 2
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|6
      #|line
    ),
  )
}

///|
test "dragging past the bottom or top edge scrolls the area" {
  let lines = Array::makei(20, index => Line::from_text("line \{index}"))
  let selection = Selection()
  let scroll = Scroll()
  ignore(draw(lines, selection, scroll~))
  scroll.scroll_by(5)
  ignore(draw(lines, selection, scroll~))
  selection.mouse(press(2, 1))
  // Row 4 is the frame row just below the area (rows 1 to 3).
  selection.mouse(drag(4, 3))
  @debug.assert_eq(scroll.offset(), 6)
  inspect(
    shown(draw(lines, selection, scroll~)),
    content=(
      #|
      #| line 6
      #| ^^^^^^
      #| line 7
      #| ^^^^^^
      #| line 8
      #| ^^^^^^
      #|
    ),
  )
  selection.mouse(drag(4, 3))
  @debug.assert_eq(scroll.offset(), 7)
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|line 6
      #|line 7
      #|line 8
      #|line 9
    ),
  )
  // Back above the top edge: the selection now runs upwards from the press.
  for _ in 0..<4 {
    ignore(draw(lines, selection, scroll~))
    selection.mouse(drag(0, 3))
  }
  @debug.assert_eq(scroll.offset(), 3)
  inspect(
    shown(draw(lines, selection, scroll~)),
    content=(
      #|
      #| line 3
      #| ^^^^^^
      #| line 4
      #| ^^^^^^
      #| line 5
      #| ^^^^^^
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|line 3
      #|line 4
      #|line 5
      #|l
    ),
  )
}

///|
test "a selection survives added lines but not a change of width" {
  let lines = plain(["alpha", "beta"])
  let selection = Selection()
  ignore(draw(lines, selection))
  selection.mouse(press(1, 1))
  selection.mouse(drag(2, 4))
  selection.mouse(release(2, 4))
  lines.push(Line::from_text("gamma"))
  ignore(draw(lines, selection))
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|alpha
      #|beta
    ),
  )
  // A different width means the lines were wrapped differently.
  ignore(draw(lines, selection, width=10))
  assert_true(selection.text() is None)
}

///|
test "a selection is dropped when its lines are gone" {
  let selection = Selection()
  ignore(draw(plain(["alpha", "beta", "gamma"]), selection))
  selection.mouse(press(2, 1))
  selection.mouse(drag(3, 3))
  ignore(draw(plain(["alpha"]), selection))
  assert_true(selection.text() is None)
  // With no lines at all there is nothing to select.
  ignore(draw([], selection))
  selection.mouse(press(1, 1))
  selection.mouse(drag(2, 3))
  assert_true(selection.text() is None)
}

///|
test "selection follows the alignment of the lines" {
  let lines = plain(["abcd"])
  let selection = Selection()
  ignore(draw(lines, selection, align=Right))
  // Width 12, so "abcd" occupies area columns 8 to 11: frame columns 9 to 12.
  selection.mouse(press(1, 10))
  selection.mouse(drag(1, 11))
  inspect(
    shown(draw(lines, selection, align=Right)),
    content=(
      #|
      #|         abcd
      #|          ^^
      #|
      #|
      #|
    ),
  )
  inspect(
    selection.text().unwrap_or("(none)"),
    content=(
      #|bc
    ),
  )
}
