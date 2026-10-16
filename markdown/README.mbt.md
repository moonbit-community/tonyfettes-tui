# Terminal Markdown

Import `moonbit-community/tui/markdown` to turn CommonMark into styled `Line`s.
The renderer includes tables, task lists, strikethrough, and math extensions.
It accepts unfinished input for streaming transcripts and measures width in
terminal display columns, including CJK and emoji graphemes.

```mbt check
///|
test {
  let lines = @markdown.render("## Hello\n\n**MoonBit** and `code`.", 40)
  let frame = @tui.Frame(width=40, height=lines.length())
  frame.lines(frame.area(), lines[:])
  assert_true(frame.style_at(row=0, col=0).bold)
  assert_eq(lines[0].to_text(), "Hello")
}
```

`render(text, width, theme~, dim~)` returns lines for `Frame.lines`, so scrolling
and selection use the same interface as ordinary text. Widths below one are
treated as one. Narrow tables become labeled records; wider tables use an
aligned grid. Code blocks preserve their literal content, expand tabs to four
spaces, and wrap to the available width. Links show destinations when they
differ from the label. Raw HTML is displayed as text; math is displayed as its
source. The renderer does not execute HTML, open links, or highlight code syntax.

## Themes

`Theme()` retains the original dark palette. Configure the five semantic styles
to match the surrounding terminal. `Default` foreground or background colors in
a role inherit the text style; attributes add to enclosing emphasis. A theme can
therefore use a light background or leave all colors to its parent panel:

```mbt check
///|
test {
  let theme = @markdown.Theme(
    muted=@tui.Style(),
    heading=@tui.Style(bold=true),
    code=@tui.Style(),
    link=@tui.Style(underline=true),
  )
  let lines = @markdown.render("**`code`**", 40, theme~)
  let frame = @tui.Frame(width=40, height=1, inherit_colors=true)
  frame.fill(frame.area(), style=@tui.Style(bg=Basic(White)))
  frame.lines(frame.area(), lines[:])
  let cell = frame.style_at(row=0, col=0)
  assert_true(cell.bg is Basic(White))
  assert_true(cell.bold)
}
```

`dim=true` applies the theme's muted foreground to ordinary text and code while
retaining emphasis and the code background. Headings and links keep their
semantic styles. Blank lines and unused panel space remain the caller's to fill.
