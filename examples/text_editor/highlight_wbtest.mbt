///|
/// The spans of `line` as `text:style` pairs, naming each style by what it is
/// used for.
fn tokens(line : String) -> String {
  let names = [
    (comment_style, "comment"),
    (keyword_style, "keyword"),
    (string_style, "string"),
    (number_style, "number"),
    (type_style, "type"),
    (function_style, "function"),
    (package_style, "package"),
    (operator_style, "operator"),
  ]
  let parts = []
  for span in highlight_moonbit(line) {
    let mut name = "plain"
    for pair in names {
      if pair.0 == span.style {
        name = pair.1
      }
    }
    if name != "plain" {
      parts.push("\{span.text}:\{name}")
    }
  }
  parts.join(" ")
}

///|
test "moonbit tokens" {
  inspect(
    tokens("pub fn Frame::text(self : Frame, row~ : Int) -> Unit {"),
    content=(
      #|pub:keyword fn:keyword Frame:type :::operator text:function ::operator Frame:type ~:operator ::operator Int:type ->:operator Unit:type
    ),
  )
  inspect(
    tokens("  let dim = @tui.Style(fg=Basic(BrightBlack))"),
    content=(
      #|let:keyword =:operator @tui:package Style:type =:operator Basic:type BrightBlack:type
    ),
  )
  inspect(
    tokens("  if count >= 10 && name != \"a // b\" { // trailing"),
    content=(
      #|if:keyword >=:operator 10:number &&:operator !=:operator "a // b":string // trailing:comment
    ),
  )
  inspect(
    tokens("    #|a string line, not a // comment"),
    content=(
      #|#|a string line, not a // comment:string
    ),
  )
  inspect(
    tokens("///| top-level marker"),
    content=(
      #|///| top-level marker:comment
    ),
  )
  inspect(
    tokens("  Char('x') | '\\n' => it's fine"),
    content=(
      #|Char:type 'x':string |:operator '\n':string =>:operator
    ),
  )
  inspect(
    tokens("#deprecated(\"use x\")"),
    content=(
      #|#deprecated:package "use x":string
    ),
  )
  inspect(
    tokens("  for i in 0..<0x1f { total += 1.5 }"),
    content=(
      #|for:keyword in:keyword 0:number <:operator 0x1f:number +=:operator 1.5:number
    ),
  )
}

///|
test "the spans always add up to the line" {
  let lines = [
    "", "   ", "fn main {", "  \"unterminated", "  'x", "let s = \"a\\\"b\" + 'c'",
    "你好 // 中文注释", "@pkg/path.f(x~, y?=1)", "a=>b->c::d", "#|", "$|x",
    "@ # '",
  ]
  for line in lines {
    let joined = StringBuilder()
    for span in highlight_moonbit(line) {
      joined.write_string(span.text)
    }
    @debug.assert_eq(joined.to_string(), line)
  }
}

///|
test "the language is chosen by file name" {
  assert_true(language(Some("a/b.mbt")) is Some(("MoonBit", _)))
  assert_true(language(Some("pkg.generated.mbti")) is Some(_))
  assert_true(language(Some("notes.txt")) is None)
  assert_true(language(None) is None)
}
