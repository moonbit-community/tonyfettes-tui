///|
test "Markdown renders headings emphasis code and table cells instead of source markers" {
  let source =
    #|## 验证
    #|
    #|**未提交**，运行 `moon check`。
    #|
    #|| 门禁 | 结果 |
    #|| --- | --- |
    #|| `moon check --target native` | 通过 |
    #|| `moon test --target js` | 3705/3705 |
  let lines = @markdown.render(source, 40)
  let text = lines.map(line => line.to_text()).join("\n")
  assert_true(text.contains("验证"))
  assert_true(text.contains("未提交"))
  assert_true(text.contains("moon check"))
  assert_true(text.contains("3705/3705"))
  for marker in ["##", "**", "`", "| ---", "| 门禁"] {
    assert_true(
      !text.contains(marker),
      msg="Markdown marker remains: \{marker}",
    )
  }
  for line in lines {
    assert_true(line.width() <= 40)
  }
  let frame = @tui.Frame(width=40, height=lines.length())
  frame.lines(frame.area(), lines[:])
  assert_true(frame.style_at(row=0, col=0).bold)
  assert_true(frame.style_at(row=2, col=0).bold)
  assert_true(!(frame.style_at(row=2, col=14).bg is Default))
}

///|
test "wide tables align cells and narrow tables retain their header labels" {
  let source =
    #|| 门禁 | 结果 |
    #|| :--- | ---: |
    #|| `moon check --target native` | 通过 |
    #|| `moon test --target js` | 3705/3705 |
  let wide = @markdown.render(source, 80).map(line => line.to_text()).join("\n")
  inspect(
    wide,
    content=(
      #|门禁                       │      结果
      #|───────────────────────────┼──────────
      #|moon check --target native │      通过
      #|moon test --target js      │ 3705/3705
    ),
  )
  let narrow = @markdown.render(source, 30)
    .map(line => line.to_text())
    .join("\n")
  inspect(
    narrow,
    content=(
      #|门禁: moon check --target
      #|native
      #|结果: 通过
      #|
      #|门禁: moon test --target js
      #|结果: 3705/3705
    ),
  )
}

///|
test "nested lists quotes links hard breaks and code fences preserve meaning and styling" {
  let source =
    #|1. **first** and *italic*
    #|   - nested 中文
    #|2. [Docs][docs]
    #|
    #|> quoted  
    #|> second line
    #|
    #|- [x] done
    #|- [ ] todo
    #|
    #|```moonbit
    #|let x = "**literal**"
    #|  x + 1
    #|```
    #|
    #|[docs]: https://example.com
  let lines = @markdown.render(source, 60)
  inspect(
    lines.map(line => line.to_text()).join("\n"),
    content=(
      #|1. first and italic
      #|   
      #|   • nested 中文
      #|2. Docs (https://example.com)
      #|
      #|│ quoted
      #|│ second line
      #|
      #|☑ done
      #|☐ todo
      #|
      #|moonbit
      #|│ let x = "**literal**"
      #|│   x + 1
    ),
  )
  let frame = @tui.Frame(width=60, height=lines.length())
  frame.lines(frame.area(), lines[:])
  assert_true(frame.style_at(row=0, col=3).bold)
  assert_true(frame.style_at(row=0, col=13).italic)
}

///|
test "partial streaming Markdown unicode and long links remain bounded at narrow widths" {
  let parts = [
    "**正在", "**正在完成**", "`partial", "```moonbit\nlet x = 1", "```moonbit\nlet x = 1\n```",
    "- 中文👨‍👩‍👧‍👦é **粗体** content\n  - nested content",
    "| 中文 | result |\n| --- | --- |\n| 中文 | [long](https://example.com/very/long/path) |",
    "> - [x] nested 中文中文中文 content",
  ]
  for source in parts {
    for width in [1, 4, 10, 30, 60, 80] {
      let lines = @markdown.render(source, width)
      for line in lines {
        assert_true(
          line.width() <= width,
          msg="width \{width}: \{line.to_text()}",
        )
        assert_true(!line.to_text().contains("�"))
      }
    }
  }
  let complete = @markdown.render("**正在完成**", 40)
    .map(line => line.to_text())
    .join("\n")
  assert_eq(complete, "正在完成")
  let code = @markdown.render("```\n**literal**\n", 40)
    .map(line => line.to_text())
    .join("\n")
  assert_eq(code, "│ **literal**")
}

///|
test "dim reasoning retains emphasis while inline code remains distinct" {
  let lines = @markdown.render("**bold** `code`", 40, dim=true)
  let frame = @tui.Frame(width=40, height=1)
  frame.lines(frame.area(), lines[:])
  assert_true(frame.style_at(row=0, col=0).bold)
  assert_true(frame.style_at(row=0, col=0).fg is Rgb(133, 148, 169))
  assert_true(frame.style_at(row=0, col=5).bg is Rgb(25, 31, 41))
}

///|
test "custom themes cover semantic styles and inherit the text background" {
  let theme = @markdown.Theme(
    text=@tui.Style(fg=Basic(Black), bg=Basic(White)),
    muted=@tui.Style(fg=Basic(BrightBlack)),
    heading=@tui.Style(fg=Basic(Magenta), bold=true),
    code=@tui.Style(fg=Basic(Red)),
    link=@tui.Style(fg=Basic(Blue), underline=true),
  )
  let lines = @markdown.render(
    "## Title\n\n**bold `code`** [link](link)\n\n> quote\n\n- item\n\n---",
    40,
    theme~,
  )
  let frame = @tui.Frame(width=40, height=lines.length())
  frame.lines(frame.area(), lines[:])
  assert_true(frame.style_at(row=0, col=0).fg is Basic(Magenta))
  assert_true(frame.style_at(row=0, col=0).bold)
  assert_true(frame.style_at(row=2, col=0).fg is Basic(Black))
  let code = frame.style_at(row=2, col=5)
  assert_true(code.fg is Basic(Red))
  assert_true(code.bg is Basic(White))
  assert_true(code.bold)
  let link = frame.style_at(row=2, col=10)
  assert_true(link.fg is Basic(Blue))
  assert_true(link.underline)
  for row in [4, 6, 8] {
    let prefix = frame.style_at(row~, col=0)
    assert_true(prefix.fg is Basic(BrightBlack))
    assert_true(prefix.bg is Basic(White))
  }
}

///|
test "terminal default role colors preserve the surrounding panel" {
  let theme = @markdown.Theme(
    muted=@tui.Style(),
    heading=@tui.Style(bold=true),
    code=@tui.Style(),
    link=@tui.Style(underline=true),
  )
  let lines = @markdown.render("**`code`** [link](link)", 40, theme~)
  let frame = @tui.Frame(width=40, height=1, inherit_colors=true)
  let panel = @tui.Style(fg=Basic(Black), bg=Basic(White))
  frame.fill(frame.area(), style=panel)
  frame.lines(frame.area(), lines[:])
  for col in [0, 5] {
    let cell = frame.style_at(row=0, col~)
    assert_true(cell.fg is Basic(Black))
    assert_true(cell.bg is Basic(White))
  }
  assert_true(frame.style_at(row=0, col=0).bold)
  assert_true(frame.style_at(row=0, col=5).underline)
  let dim = @markdown.render(
    "**bold** `code`",
    40,
    dim=true,
    theme=@markdown.Theme(
      text=panel,
      muted=@tui.Style(fg=Basic(BrightBlack)),
      code=@tui.Style(fg=Basic(Red)),
    ),
  )
  frame.lines(frame.area(), dim[:])
  assert_true(frame.style_at(row=0, col=0).fg is Basic(BrightBlack))
  assert_true(frame.style_at(row=0, col=5).fg is Basic(BrightBlack))
  assert_true(frame.style_at(row=0, col=5).bg is Basic(White))
}
