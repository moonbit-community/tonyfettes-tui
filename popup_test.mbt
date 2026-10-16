///|
test "popup wraps wide text and leaves the anchor visible" {
  let frame = @tui.Frame(width=16, height=8)
  frame.text(row=1, col=12, "X")
  let area = @tui.popup(
    frame,
    [@tui.Line::from_text("你好世界")],
    bounds=frame.area(),
    anchor=@tui.Cursor(row=1, col=12),
    max_width=8,
  )
  assert_eq(area, Some(@tui.Rect(row=2, col=8, width=8, height=4)))
  assert_true(frame.to_text().contains("X"))
  assert_true(frame.to_text().contains("│ 你好 │"))
  assert_true(frame.to_text().contains("│ 世界 │"))
}

///|
test "popup flips above and stays inside an offset viewport" {
  let frame = @tui.Frame(width=20, height=10)
  let area = @tui.popup(
    frame,
    [@tui.Line::from_text("hello")],
    bounds=@tui.Rect(row=2, col=4, width=12, height=7),
    anchor=@tui.Cursor(row=8, col=15),
  )
  assert_eq(area, Some(@tui.Rect(row=5, col=7, width=9, height=3)))
}

///|
test "popup refuses outside anchors and insufficient space" {
  let frame = @tui.Frame(width=12, height=4)
  let lines = [@tui.Line::from_text("hello")]
  assert_eq(
    @tui.popup(
      frame,
      lines,
      bounds=frame.area(),
      anchor=@tui.Cursor(row=1, col=12),
    ),
    None,
  )
  assert_eq(
    @tui.popup(
      frame,
      lines,
      bounds=frame.area(),
      anchor=@tui.Cursor(row=1, col=2),
    ),
    None,
  )
  assert_eq(frame.to_text(), "\n\n\n")
}

///|
test "popup scrolling clips content and retains explicit colors" {
  let frame = @tui.Frame(width=16, height=8)
  let scroll = @tui.Scroll()
  let content = [
    @tui.Line::from_text("first"),
    @tui.Line::from_text("second", style=@tui.Style(fg=Basic(Red))),
    @tui.Line::from_text("third"),
  ]
  let style = @tui.Style(fg=Basic(White), bg=Basic(Blue))
  ignore(
    @tui.popup(
      frame,
      content,
      bounds=frame.area(),
      anchor=@tui.Cursor(row=0, col=0),
      scroll~,
      style~,
      max_height=3,
    ),
  )
  scroll.scroll_by(1)
  let next = @tui.Frame(width=16, height=8)
  ignore(
    @tui.popup(
      next,
      content,
      bounds=next.area(),
      anchor=@tui.Cursor(row=0, col=0),
      scroll~,
      style~,
      max_height=3,
    ),
  )
  assert_true(next.to_text().contains("second"))
  assert_true(!next.to_text().contains("first"))
  assert_eq(
    next.style_at(row=2, col=2),
    @tui.Style(fg=Basic(Red), bg=Basic(Blue)),
  )
}
