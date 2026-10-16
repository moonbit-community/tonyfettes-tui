///|
test "MoonBit highlighter preserves exact text and uses lexer token classes" {
  let source = "\tpub fn greet(名字 : String) -> Int { // 注释 🌙"
  for path in ["main.mbt", "pkg.generated.mbti", "scripts/check.mbtx"] {
    let highlight = @moonbit.for_path(path).unwrap()
    let spans = highlight(source)
    assert_eq(spans.map(span => span.text).join(""), source)
    assert_true(
      spans
      .iter()
      .any(span => span.text == "pub" && span.style.fg is Rgb(86, 156, 214)),
    )
    assert_true(
      spans
      .iter()
      .any(span => span.text == "greet" && span.style.fg is Rgb(220, 220, 170)),
    )
    assert_true(
      spans
      .iter()
      .any(span => span.text == "String" && span.style.fg is Rgb(78, 201, 176)),
    )
    assert_true(
      spans
      .iter()
      .any(span => {
        span.text == "// 注释 🌙" && span.style.fg is Rgb(106, 153, 85)
      }),
    )
  }
  assert_true(@moonbit.for_path("README.mbt.md") is None)
  assert_true(@moonbit.for_path("main.txt") is None)
}

///|
test "strings numbers incomplete edits and diff backgrounds remain intact" {
  let base = @tui.Style(bg=Rgb(20, 45, 32), reverse=true)
  let highlight = @moonbit.for_path("main.mbt", base~).unwrap()
  for
    source in [
      "let x = 42", "let s = \"你好 🌙\\n\"", "let s = \"unfinished", "#|literal text",
      "$|hello \\{x}", "", "  ",
    ] {
    let spans = highlight(source)
    assert_eq(spans.map(span => span.text).join(""), source)
    for span in spans {
      assert_eq(span.style.bg, base.bg)
      assert_true(span.style.reverse)
    }
  }
  assert_true(highlight("42")[0].style.fg is Rgb(181, 206, 168))
  assert_true(highlight("#|literal")[0].style.fg is Rgb(206, 145, 120))
  assert_true(highlight("/// doc")[0].style.fg is Rgb(106, 153, 85))
}

///|
test "custom token colors preserve every non-foreground base attribute" {
  let base = @tui.Style(
    fg=Rgb(1, 2, 3),
    bg=Rgb(4, 5, 6),
    bold=true,
    italic=true,
    underline=true,
    reverse=true,
  )
  let theme = @moonbit.Theme(
    keyword=Rgb(10, 11, 12),
    type_=Rgb(20, 21, 22),
    function_=Rgb(30, 31, 32),
    string=Rgb(40, 41, 42),
    number=Rgb(50, 51, 52),
    comment=Rgb(60, 61, 62),
  )
  guard @moonbit.for_path("src/main.mbt", base~, theme~) is Some(highlight) else {
    fail("expected a MoonBit highlighter")
  }
  let spans = highlight(
    "pub fn greet(name : String) { let n = 42; let s = \"hi\" // docs",
  )
  for
    (text, color) in [
      ("pub", @color.Rgb(10, 11, 12)),
      ("String", @color.Rgb(20, 21, 22)),
      ("greet", @color.Rgb(30, 31, 32)),
      ("\"hi\"", @color.Rgb(40, 41, 42)),
      ("42", @color.Rgb(50, 51, 52)),
      ("// docs", @color.Rgb(60, 61, 62)),
    ] {
    assert_true(
      spans.iter().any(span => span.text == text && span.style.fg == color),
    )
  }
  for span in spans {
    assert_eq(span.style.bg, base.bg)
    assert_true(
      span.style.bold &&
      span.style.italic &&
      span.style.underline &&
      span.style.reverse,
    )
  }
}

///|
test "unknown extensions do not opt into MoonBit tokenization" {
  for
    path in [
      "", "README.md", "main.mbt.md", "main.mbt.backup", "module.moon", "main.ts",
      "main.MBT",
    ] {
    assert_true(@moonbit.for_path(path) is None)
  }
  for
    path in ["main.mbt", "pkg.generated.mbti", "folder with spaces/script.mbtx"] {
    assert_true(@moonbit.for_path(path) is Some(_))
  }
}

///|
test "UTF-16 source is conserved across astral characters combining marks and incomplete input" {
  guard @moonbit.for_path("main.mbt") is Some(highlight) else {
    fail("expected a MoonBit highlighter")
  }
  for
    source in [
      "🌙 let after = 42", "let invalid_🌙 = 1", "let 名字 = \"🌙e\u0301👩‍💻\"",
      "// before 🌙 after e\u0301", "\t\tlet s = \"🌙\\n", "#|🌙e\u0301", "$|🌙 \\{名字}",
      "", "\t  ", "let x = 1\r", "\"🌙\" + \"𐐀\"",
    ] {
    let spans = highlight(source)
    assert_eq(spans.map(span => span.text).join(""), source)
    assert_eq(
      spans.fold(init=0, (length, span) => length + span.text.length()),
      source.length(),
    )
  }
}
