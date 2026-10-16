# MoonBit syntax highlighting

`moonbit-community/tui/highlight/moonbit` adapts the MoonBit lexer from
`moonbitlang/editor@0.4.6` to TUI spans. Import this optional package when a
source viewer or editor needs MoonBit colors. It has no LSP or editing behavior.

`for_path` returns a line-highlighting callback for the case-sensitive `.mbt`,
`.mbti`, and `.mbtx` extensions, or `None` for other paths. The callback fits
`Editor::draw` and `Viewer::draw`'s optional `highlight` argument.

```mbt check
///|
test "paint highlighted MoonBit source" {
  guard @moonbit.for_path("main.mbt") is Some(highlight) else {
    fail("expected a MoonBit highlighter")
  }
  let source = "pub fn greet(name : String) { // 你好 🌙"
  let spans = highlight(source)
  assert_eq(spans.map(span => span.text).join(""), source)
  let frame = @tui.Frame(width=60, height=1)
  frame.line(frame.area(), @tui.Line(spans))
  assert_true(frame.to_text().contains("你好 🌙"))
}
```

## Colors and base style

`Theme` customizes eight foreground groups: keywords, types/tags, functions,
strings/regular expressions, numbers/constants, comments/documentation,
escapes/attributes, and invalid tokens. Identifiers, variables, punctuation,
operators, delimiters, and plain text retain the base foreground.

The callback preserves the base background, bold, italic, underline, and
reverse attributes for all spans. This keeps added/removed line backgrounds
intact when syntax highlighting is used inside a diff.

```mbt check
///|
test "customize colors while retaining a diff background" {
  let base = @tui.Style(bg=Rgb(20, 45, 32), bold=true)
  let theme = @moonbit.Theme(keyword=Rgb(1, 2, 3))
  guard @moonbit.for_path("script.mbtx", base~, theme~) is Some(highlight) else {
    fail("expected a MoonBit highlighter")
  }
  let spans = highlight("let n = 42")
  assert_eq(spans[0].text, "let")
  assert_eq(spans[0].style.fg, @tui.Style(fg=Rgb(1, 2, 3)).fg)
  for span in spans {
    assert_eq(span.style.bg, base.bg)
    assert_true(span.style.bold)
  }
}
```

## Line-by-line contract

Each call starts the tokenizer in its initial state. A viewport can therefore
highlight visible lines in any order without tokenizing the preceding file.
State from a previous line is not carried into the next call. Token offsets
and span lengths both use UTF-16 code units; concatenating the returned span
text reproduces the supplied source exactly, including spaces, combining marks,
and supplementary-plane characters. The highlighter does not wrap or normalize
source text.
