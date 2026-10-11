///|
test "text paints at an exact cell" {
  let frame = @tui.Frame(width=10, height=2)
  frame.text(row=0, col=2, "hi")
  frame.text(row=1, col=0, "there")
  inspect(
    frame.to_text(),
    content=(
      #|  hi
      #|there
    ),
  )
}

///|
test "wide graphemes take two columns" {
  let frame = @tui.Frame(width=10, height=1)
  frame.text(row=0, col=0, "你好")
  frame.text(row=0, col=4, "a")
  inspect(
    frame.to_text(),
    content=(
      #|你好a
    ),
  )
}

///|
test "text is clipped at the frame edges" {
  let frame = @tui.Frame(width=4, height=2)
  // "ab" fits; the wide grapheme would need columns 3 and 4, so painting
  // stops there and "c" is not shifted into its place.
  frame.text(row=0, col=1, "ab你c")
  frame.text(row=1, col=-2, "abcdef")
  frame.text(row=5, col=0, "off")
  frame.text(row=-1, col=0, "off")
  inspect(
    frame.to_text(),
    content=(
      #| ab
      #|cdef
    ),
  )
}

///|
test "control characters never become cell content" {
  let frame = @tui.Frame(width=20, height=1)
  frame.text(row=0, col=0, "a\u{1b}[31mb\tc\nd\u{7f}e")
  inspect(
    frame.to_text(),
    content=(
      #|a[31mbcde
    ),
  )
}

///|
test "overwriting half of a wide grapheme blanks the other half" {
  let frame = @tui.Frame(width=6, height=2)
  frame.text(row=0, col=0, "你好")
  frame.text(row=0, col=1, "x")
  frame.text(row=1, col=0, "你好")
  frame.text(row=1, col=2, "x")
  inspect(
    frame.to_text(),
    content=(
      #| x好
      #|你x
    ),
  )
}

///|
test "line paints on the first row of its area with alignment" {
  let frame = @tui.Frame(width=12, height=3)
  let rows = frame.area().split_rows([Fixed(1), Fixed(1), Fixed(1)])
  frame.line(rows[0], @tui.Line::from_text("left"))
  frame.line(rows[1], @tui.Line::from_text("mid"), align=Center)
  frame.line(rows[2], @tui.Line::from_text("right"), align=Right)
  inspect(
    frame.to_text(),
    content=(
      #|left
      #|    mid
      #|       right
    ),
  )
}

///|
test "line is clipped to its area, not just to the frame" {
  let frame = @tui.Frame(width=12, height=2)
  frame.fill(frame.area())
  for row in 0..<2 {
    frame.text(row~, col=0, "............")
  }
  let area = @tui.Rect(row=0, col=2, width=5, height=1)
  frame.line(area, Line([Span("abc"), Span("defgh")]))
  // A wide grapheme that would cross the area's edge is cut, and so is
  // everything after it.
  frame.line(
    @tui.Rect(row=1, col=2, width=5, height=1),
    @tui.Line::from_text("ab你好c"),
  )
  inspect(
    frame.to_text(),
    content=(
      #|..abcde.....
      #|..ab你......
    ),
  )
}

///|
test "an area outside the frame paints nothing" {
  let frame = @tui.Frame(width=4, height=1)
  frame.line(
    @tui.Rect(row=3, col=0, width=4, height=1),
    @tui.Line::from_text("no"),
  )
  frame.line(
    @tui.Rect(row=-1, col=0, width=4, height=2),
    @tui.Line::from_text("no"),
  )
  frame.line(
    @tui.Rect(row=0, col=9, width=4, height=1),
    @tui.Line::from_text("no"),
  )
  frame.line(
    @tui.Rect(row=0, col=0, width=0, height=1),
    @tui.Line::from_text("no"),
  )
  inspect(frame.to_text(), content="")
}

///|
test "lines paints one line per row and stops at the area's height" {
  let frame = @tui.Frame(width=8, height=4)
  let area = @tui.Rect(row=1, col=1, width=6, height=2)
  frame.lines(area, [
    @tui.Line::from_text("one"),
    @tui.Line::from_text("two"),
    @tui.Line::from_text("three"),
  ])
  inspect(
    frame.to_text(),
    content=(
      #|
      #| one
      #| two
      #|
    ),
  )
}

///|
test "fill replaces an area and ignores the part outside the frame" {
  let frame = @tui.Frame(width=5, height=3)
  for row in 0..<3 {
    frame.text(row~, col=0, "#####")
  }
  frame.fill(
    @tui.Rect(row=1, col=1, width=10, height=10),
    style=Style(bg=Basic(Blue)),
  )
  inspect(
    frame.to_text(),
    content=(
      #|#####
      #|#
      #|#
    ),
  )
}

///|
test "a frame with no cells is valid" {
  let frame = @tui.Frame(width=0, height=-3)
  @debug.assert_eq(frame.width(), 0)
  @debug.assert_eq(frame.height(), 0)
  @debug.assert_eq(frame.area(), @tui.Rect(row=0, col=0, width=0, height=0))
  frame.text(row=0, col=0, "x")
  frame.line(frame.area(), @tui.Line::from_text("x"))
  frame.set_cursor(frame.area())
  inspect(frame.to_text(), content="")
}
