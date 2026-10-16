///|
fn texts(lines : Array[@tui.Line]) -> Array[String] {
  lines.map(line => line.to_text())
}

///|
test "line width counts display columns across spans" {
  @debug.assert_eq(@tui.Line::from_text("hello").width(), 5)
  @debug.assert_eq(@tui.Line::from_text("你好").width(), 4)
  @debug.assert_eq(
    @tui.Line([Span("> "), Span("你好"), Span("!")]).width(),
    7,
  )
  @debug.assert_eq(@tui.Line([]).width(), 0)
}

///|
test "control characters take no width and are not part of the text" {
  let line = @tui.Line::from_text("a\tb\u{1b}[0mc\n")
  @debug.assert_eq(line.width(), 6)
  inspect(
    line.to_text(),
    content=(
      #|ab[0mc
    ),
  )
}

///|
test "wrap breaks at the last space that fits and drops it" {
  let line = @tui.Line::from_text("the quick brown fox jumps")
  debug_inspect(
    texts(line.wrap(10)),
    content=(
      #|["the quick", "brown fox", "jumps"]
    ),
  )
  debug_inspect(
    texts(line.wrap(100)),
    content=(
      #|["the quick brown fox jumps"]
    ),
  )
}

///|
test "wrap breaks a long word and text without spaces at the edge" {
  debug_inspect(
    texts(@tui.Line::from_text("abcdefghij").wrap(4)),
    content=(
      #|["abcd", "efgh", "ij"]
    ),
  )
  // Three wide graphemes would need six columns, so two fit per line of five.
  debug_inspect(
    texts(@tui.Line::from_text("你好世界你").wrap(5)),
    content=(
      #|["你好", "世界", "你"]
    ),
  )
  debug_inspect(
    texts(@tui.Line::from_text("see abcdefghij now").wrap(6)),
    content=(
      #|["see", "abcdef", "ghij", "now"]
    ),
  )
}

///|
test "wrap keeps an empty line and handles widths that fit nothing" {
  debug_inspect(
    texts(@tui.Line([]).wrap(10)),
    content=(
      #|[""]
    ),
  )
  debug_inspect(
    texts(@tui.Line::from_text("abc").wrap(0)),
    content=(
      #|[]
    ),
  )
  // A wide grapheme cannot fit in one column and is left out.
  debug_inspect(
    texts(@tui.Line::from_text("a你b").wrap(1)),
    content=(
      #|["a", "b"]
    ),
  )
}

///|
test "wrap keeps each grapheme's style" {
  let red = @tui.Style(fg=Basic(Red))
  let line = @tui.Line([Span("ab cd", style=red), Span("ef gh")])
  // "cdef" is one word even though it spans two styles.
  @debug.assert_eq(line.wrap(6), [
    Line([Span("ab", style=red)]),
    Line([Span("cd", style=red), Span("ef")]),
    Line([Span("gh")]),
  ])
}

///|
test "wrapped lines are never wider than the width" {
  let line = @tui.Line::from_text(
    "MoonBit 是一个 end-to-end 的编程语言工具链, for cloud and edge computing.",
  )
  for width in 1..<40 {
    for wrapped in line.wrap(width) {
      assert_true(wrapped.width() <= width)
    }
  }
}

///|
test "concatenation preserves the styles of wrapped cells without changing inputs" {
  let first = @tui.Line::from_text("│ ")
  let content = @tui.Line::from_text("中文 code", style=@tui.Style(bold=true))
  let wrapped = content.wrap(4)
  let joined = first.concat(wrapped[0])
  assert_eq(joined.to_text(), "│ 中文")
  assert_eq(joined.width(), 6)
  assert_eq(first.to_text(), "│ ")
  assert_eq(content.to_text(), "中文 code")
  let frame = @tui.Frame(width=6, height=1)
  frame.line(frame.area(), joined)
  assert_true(!frame.style_at(row=0, col=0).bold)
  assert_true(frame.style_at(row=0, col=2).bold)
}
