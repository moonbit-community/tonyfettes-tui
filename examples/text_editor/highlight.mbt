// Syntax highlighting for MoonBit source, one line at a time.
//
// The editor asks for the styles of a line by handing over its text and
// expects the same text back, cut into styled spans. MoonBit suits this well:
// comments run to the end of the line and multi-line strings are written one
// `#|` line at a time, so no line depends on the ones before it.

///|
let keywords : Array[String] = [
  "and", "as", "async", "break", "catch", "const", "continue", "defer", "derive",
  "else", "enum", "extend", "extern", "fn", "for", "guard", "if", "impl", "in", "is",
  "let", "letrec", "loop", "match", "mut", "nobreak", "noraise", "priv", "pub", "raise",
  "return", "struct", "suberror", "test", "trait", "try", "type", "using", "while",
  "with",
]

///|
fn is_ident_start(c : Char) -> Bool {
  c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_ident(c : Char) -> Bool {
  is_ident_start(c) || is_digit(c)
}

///|
/// The index of the first character from `from` on that `keep` rejects.
fn skip(chars : Array[Char], from : Int32, keep : (Char) -> Bool) -> Int32 {
  let mut index = from
  while index < chars.length() && keep(chars[index]) {
    index += 1
  }
  index
}

///|
/// The index just past the number that starts at `from`. A dot is part of the
/// number only when a digit follows, so `0..<n` is a number and a range, not
/// a number that ends in dots.
fn skip_number(chars : Array[Char], from : Int32) -> Int32 {
  let mut index = from
  while index < chars.length() {
    let c = chars[index]
    let fraction = c == '.' &&
      index + 1 < chars.length() &&
      is_digit(chars[index + 1])
    if !is_ident(c) && !fraction {
      break
    }
    index += 1
  }
  index
}

///|
/// The index just past the string or character literal that opens at `from`
/// with `quote`, or the end of the line if it is never closed.
fn skip_quoted(chars : Array[Char], from : Int32, quote : Char) -> Int32 {
  let mut index = from + 1
  while index < chars.length() {
    if chars[index] == '\\' {
      index += 2
    } else if chars[index] == quote {
      return index + 1
    } else {
      index += 1
    }
  }
  chars.length()
}

///|
/// Cut one line of MoonBit into styled spans. The spans add up to exactly the
/// text of the line.
fn highlight_moonbit(line : String) -> Array[@tui.Span] {
  let chars = line.to_array()
  let spans : Array[@tui.Span] = []
  let plain = @tui.Style()
  let mut index = skip(chars, 0, c => c == ' ')
  if index > 0 {
    spans.push(Span(String::from_array(chars[:index])))
  }
  // A multi-line string is a run of lines that start with `#|` or `$|`.
  if index + 1 < chars.length() &&
    (chars[index] == '#' || chars[index] == '$') &&
    chars[index + 1] == '|' {
    spans.push(Span(String::from_array(chars[index:]), style=string_style))
    return spans
  }
  while index < chars.length() {
    let c = chars[index]
    let (end, style) = if c == '/' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '/' {
      (chars.length(), comment_style)
    } else if c == '"' {
      (skip_quoted(chars, index, '"'), string_style)
    } else if c == '\'' {
      // A character literal is short; a lone quote is not one.
      let end = skip_quoted(chars, index, '\'')
      if end - index <= 8 && chars[end - 1] == '\'' && end - index >= 3 {
        (end, string_style)
      } else {
        (index + 1, plain)
      }
    } else if is_digit(c) {
      (skip_number(chars, index), number_style)
    } else if c == '@' || c == '#' {
      // `@pkg/path` names a package; `#name` is an attribute.
      let end = skip(chars, index + 1, c => is_ident(c) || c == '/')
      (end, if end > index + 1 { package_style } else { operator_style })
    } else if is_ident_start(c) {
      let end = skip(chars, index, is_ident)
      let word = String::from_array(chars[index:end])
      let after = skip(chars, end, c => c == ' ')
      let style = if keywords.contains(word) {
        keyword_style
      } else if word == "true" || word == "false" {
        number_style
      } else if c >= 'A' && c <= 'Z' {
        type_style
      } else if after < chars.length() && chars[after] == '(' {
        function_style
      } else {
        plain
      }
      (end, style)
    } else if "=<>!+-*/|&%:~?".contains_char(c) {
      (
        skip(chars, index, c => "=<>!+-*/|&%:~?".contains_char(c)),
        operator_style,
      )
    } else {
      (index + 1, plain)
    }
    spans.push(Span(String::from_array(chars[index:end]), style~))
    index = end
  }
  spans
}

///|
/// The highlighter for a file, chosen by its name, with the language's name
/// for the status row. `None` for files that are shown as plain text.
fn language(path : String?) -> (String, (String) -> Array[@tui.Span])? {
  guard path is Some(path) else { return None }
  if path.has_suffix(".mbt") ||
    path.has_suffix(".mbti") ||
    path.has_suffix(".mbtx") {
    Some(("MoonBit", highlight_moonbit))
  } else {
    None
  }
}
