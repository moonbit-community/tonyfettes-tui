///|
test "unified rows retain Unicode and independent change styles" {
  let view = @diff.DiffView("one\nold 🌙\nthree", "one\nnew 中文\nthree")
  let frame = @tui.Frame(width=50, height=8)
  view.draw(frame, frame.area())
  let lines = frame.to_text().split("\n").collect()
  assert_true(lines[1].contains("@@ -1,3 +1,3 @@"))
  assert_true(lines[3].contains("-old 🌙"))
  assert_true(lines[4].contains("+new 中文"))
  assert_eq(frame.style_at(row=3, col=1).bg, @tui.Style(bg=Rgb(48, 27, 32)).bg)
  assert_eq(frame.style_at(row=4, col=1).bg, @tui.Style(bg=Rgb(20, 45, 32)).bg)
}

///|
test "identical sources show a generic no changes message" {
  let view = @diff.DiffView("same\n", "same\n")
  for mode in [@diff.Unified, @diff.Split] {
    let frame = @tui.Frame(width=81, height=5)
    view.draw(frame, frame.area(), mode~)
    assert_true(frame.to_text().contains("No changes."))
    assert_eq(view.offset(), 0)
  }
}

///|
test "split rows locate repeated text by source index for LF and CRLF" {
  for newline in ["\n", "\r\n"] {
    let view = @diff.DiffView(
      ["same", "separator", "same"].join(newline),
      ["same", "separator", "changed"].join(newline),
    )
    let frame = @tui.Frame(width=81, height=7)
    view.draw(frame, frame.area(), mode=Split)
    assert_eq(frame.style_at(row=2, col=2).bg, @tui.Style().bg)
    assert_eq(
      frame.style_at(row=4, col=2).bg,
      @tui.Style(bg=Rgb(48, 27, 32)).bg,
    )
    assert_eq(
      frame.style_at(row=4, col=43).bg,
      @tui.Style(bg=Rgb(20, 45, 32)).bg,
    )
    let lines = frame.to_text().split("\n").collect()
    assert_true(lines[4].contains("3 same"))
    assert_true(lines[4].contains("3 changed"))
  }
}

///|
test "insertions keep following split context aligned with source line numbers" {
  let view = @diff.DiffView("a\nc", "a\nb\nc")
  let frame = @tui.Frame(width=81, height=7)
  view.draw(
    frame,
    frame.area(),
    mode=Split,
    original_label="Before",
    modified_label="After",
  )
  let lines = frame.to_text().split("\n").collect()
  assert_true(lines[0].contains("Before"))
  assert_true(lines[0].contains("After"))
  assert_true(lines[3].contains("2 b"))
  assert_true(!lines[3].contains("2 c"))
  assert_true(lines[4].contains("2 c"))
  assert_true(lines[4].contains("3 c"))
  assert_eq(frame.style_at(row=3, col=2).bg, @tui.Style().bg)
}

///|
test "narrow split falls back to a clipped unified view" {
  let view = @diff.DiffView("old 中文 🌙 tail", "new 中文 🌙 tail")
  for width in [0, 1, 8, 30, 39] {
    let frame = @tui.Frame(width=width + 4, height=7)
    let pane = @tui.Rect(row=1, col=2, width~, height=5)
    view.draw(frame, pane, mode=Split)
    assert_eq(frame.cursor(), None)
    assert_eq(frame.style_at(row=0, col=0), @tui.Style())
    if width >= 30 {
      assert_true(frame.to_text().contains("-old 中文 🌙 tail"))
      assert_true(frame.to_text().contains("+new 中文 🌙 tail"))
    }
  }
}

///|
test "wheel and keyboard browsing clamp to visible rows and ignore editing" {
  let old = [ for i in 0..<30 => "old \{i}" ].join("\n")
  let new = [ for i in 0..<30 => "new \{i}" ].join("\n")
  let view = @diff.DiffView(old, new)
  let frame = @tui.Frame(width=50, height=8)
  let pane = @tui.Rect(row=1, col=2, width=45, height=5)
  view.draw(frame, pane)
  assert_true(!view.mouse(@input.MouseEvent::new(Scroll(Down), 1, 1)))
  assert_true(!view.mouse(@input.MouseEvent::new(Scroll(Down), 2, 3)))
  assert_true(view.mouse(@input.MouseEvent::new(Scroll(Down), 3, 3)))
  assert_eq(view.offset(), 3)
  assert_true(view.navigate(@input.KeyEvent::new(PageDown)))
  assert_eq(view.offset(), 6)
  assert_true(!view.navigate(@input.KeyEvent::new(Down, kind=Release)))
  assert_true(
    !view.navigate(
      @input.KeyEvent::new(
        Char('s'),
        modifiers=@input.KeyModifiers::new(ctrl=true),
      ),
    ),
  )
  assert_true(!view.navigate(@input.KeyEvent::new(Enter)))
  assert_eq(view.offset(), 6)
  assert_true(view.navigate(@input.KeyEvent::new(End)))
  assert_eq(view.offset(), 57)
  view.scroll_by(100)
  assert_eq(view.offset(), 57)
  view.draw(frame, pane, mode=Split)
  assert_eq(view.offset(), 27)
  view.scroll_by(-100)
  assert_eq(view.offset(), 0)
}

///|
test "replacing sources invalidates cached rows while identical snapshots preserve browsing" {
  let old = [ for i in 0..<20 => "old \{i}" ].join("\n")
  let new = [ for i in 0..<20 => "new \{i}" ].join("\n")
  let view = @diff.DiffView(old, new)
  let frame = @tui.Frame(width=60, height=6)
  view.draw(frame, frame.area())
  view.scroll_by(4)
  view.set_sources(old, new)
  assert_eq(view.offset(), 4)
  view.set_sources("before", "after")
  assert_eq(view.offset(), 0)
  let next = @tui.Frame(width=60, height=6)
  view.draw(next, next.area())
  assert_true(next.to_text().contains("-before"))
  assert_true(next.to_text().contains("+after"))
  assert_true(!next.to_text().contains("old"))
}

///|
test "theme and highlighter receive per-line base styles only for visible source rows" {
  let view = @diff.DiffView("before\nrest", "after\nrest")
  let frame = @tui.Frame(width=50, height=4)
  let calls : Array[String] = []
  let removed = @tui.Style(fg=Rgb(200, 1, 2), bg=Rgb(30, 1, 2))
  let added = @tui.Style(fg=Rgb(1, 200, 2), bg=Rgb(1, 30, 2))
  view.draw(frame, frame.area(), theme=@diff.Theme(removed~, added~), highlight=(
    text,
    base,
  ) => {
    calls.push(text)
    [@tui.Span(text, style=@tui.Style(fg=Rgb(1, 2, 200), bg=base.bg))]
  })
  assert_eq(calls.length(), 2)
  assert_eq(calls[0], "before")
  assert_eq(calls[1], "after")
  assert_eq(frame.style_at(row=2, col=0).fg, removed.fg)
  assert_eq(frame.style_at(row=2, col=1).bg, removed.bg)
  assert_eq(frame.style_at(row=3, col=1).bg, added.bg)
  assert_eq(frame.style_at(row=3, col=1).fg, @tui.Style(fg=Rgb(1, 2, 200)).fg)
}

///|
test "zero context keeps separated hunk headers in original source coordinates" {
  for context in [0, -1] {
    let view = @diff.DiffView("a\nb\nc\nd\ne", "a\nB\nc\nD\ne", context~)
    let frame = @tui.Frame(width=60, height=10)
    view.draw(frame, frame.area())
    let text = frame.to_text()
    assert_true(text.contains("@@ -2,1 +2,1 @@"))
    assert_true(text.contains("@@ -4,1 +4,1 @@"))
    assert_true(text.contains("-b"))
    assert_true(text.contains("+D"))
    assert_true(!text.contains(" c"))
  }
}

///|
test "a CRLF to LF change stays visible even when carriage returns are not drawn" {
  let view = @diff.DiffView("same\r\n", "same\n")
  let frame = @tui.Frame(width=50, height=7)
  view.draw(frame, frame.area())
  assert_true(frame.to_text().contains("-same"))
  assert_true(frame.to_text().contains("+same"))
  assert_true(!frame.to_text().contains("No changes."))
}
