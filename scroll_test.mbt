///|
/// Draw lines "0", "1", ... `count - 1` through `scroll` into an area `height`
/// rows tall, and return what shows.
fn window(scroll : @tui.Scroll, count~ : Int, height~ : Int) -> String {
  let frame = @tui.Frame(width=4, height~)
  let lines = Array::makei(count, index => @tui.Line::from_text("\{index}"))
  frame.lines(frame.area(), lines, scroll~)
  frame.to_text().replace_all(old="\n", new=" ")
}

///|
test "a scrolled area is a window onto the lines" {
  let scroll = @tui.Scroll()
  inspect(
    window(scroll, count=10, height=3),
    content=(
      #|0 1 2
    ),
  )
  scroll.scroll_by(4)
  inspect(
    window(scroll, count=10, height=3),
    content=(
      #|4 5 6
    ),
  )
  @debug.assert_eq(scroll.offset(), 4)
}

///|
test "scrolling stops at both ends" {
  let scroll = @tui.Scroll()
  ignore(window(scroll, count=10, height=3))
  scroll.scroll_by(-5)
  inspect(
    window(scroll, count=10, height=3),
    content=(
      #|0 1 2
    ),
  )
  scroll.scroll_by(100)
  inspect(
    window(scroll, count=10, height=3),
    content=(
      #|7 8 9
    ),
  )
  assert_true(scroll.at_bottom())
  // One step back is immediately visible: the position never ran past the end.
  scroll.scroll_by(-1)
  inspect(
    window(scroll, count=10, height=3),
    content=(
      #|6 7 8
    ),
  )
  assert_true(!scroll.at_bottom())
}

///|
test "a page is the area height less one line of overlap" {
  let scroll = @tui.Scroll()
  ignore(window(scroll, count=20, height=5))
  scroll.page_down()
  inspect(
    window(scroll, count=20, height=5),
    content=(
      #|4 5 6 7 8
    ),
  )
  scroll.page_down()
  inspect(
    window(scroll, count=20, height=5),
    content=(
      #|8 9 10 11 12
    ),
  )
  scroll.page_up()
  inspect(
    window(scroll, count=20, height=5),
    content=(
      #|4 5 6 7 8
    ),
  )
  scroll.to_bottom()
  inspect(
    window(scroll, count=20, height=5),
    content=(
      #|15 16 17 18 19
    ),
  )
  scroll.to_top()
  inspect(
    window(scroll, count=20, height=5),
    content=(
      #|0 1 2 3 4
    ),
  )
}

///|
test "stick to bottom follows new lines until the user scrolls up" {
  let scroll = @tui.Scroll(stick_to_bottom=true)
  inspect(
    window(scroll, count=10, height=3),
    content=(
      #|7 8 9
    ),
  )
  inspect(
    window(scroll, count=12, height=3),
    content=(
      #|9 10 11
    ),
  )
  scroll.scroll_by(-2)
  inspect(
    window(scroll, count=12, height=3),
    content=(
      #|7 8 9
    ),
  )
  // New lines arrive while scrolled up: the view stays where it is.
  inspect(
    window(scroll, count=20, height=3),
    content=(
      #|7 8 9
    ),
  )
  assert_true(!scroll.at_bottom())
  // Back at the end, it follows again.
  scroll.to_bottom()
  inspect(
    window(scroll, count=20, height=3),
    content=(
      #|17 18 19
    ),
  )
  inspect(
    window(scroll, count=22, height=3),
    content=(
      #|19 20 21
    ),
  )
}

///|
test "without stick to bottom the view stays put as lines are added" {
  let scroll = @tui.Scroll()
  inspect(
    window(scroll, count=10, height=3),
    content=(
      #|0 1 2
    ),
  )
  inspect(
    window(scroll, count=20, height=3),
    content=(
      #|0 1 2
    ),
  )
}

///|
test "the position is brought back in range when content or area changes" {
  let scroll = @tui.Scroll()
  ignore(window(scroll, count=20, height=3))
  scroll.to_bottom()
  inspect(
    window(scroll, count=20, height=3),
    content=(
      #|17 18 19
    ),
  )
  // Fewer lines than before.
  inspect(
    window(scroll, count=6, height=3),
    content=(
      #|3 4 5
    ),
  )
  // A taller area shows more above, since there is nothing below.
  inspect(
    window(scroll, count=6, height=5),
    content=(
      #|1 2 3 4 5
    ),
  )
  // Everything fits: nothing to scroll.
  inspect(
    window(scroll, count=2, height=5),
    content=(
      #|0 1   
    ),
  )
  @debug.assert_eq(scroll.offset(), 0)
  assert_true(scroll.at_bottom())
  inspect(
    window(scroll, count=0, height=5),
    content=(
      #|    
    ),
  )
}
