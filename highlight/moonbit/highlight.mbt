///|
/// Select a terminal highlighter for MoonBit source, interface and script
/// files. Each line starts from the lexer's initial state, so callers can
/// tokenize visible source lines in any order after scrolling or refreshing
/// a snapshot. Token offsets and span lengths both use UTF-16 code units.
pub fn for_path(
  path : String,
  base~ : @tui.Style = @tui.Style(),
  theme~ : Theme = Theme(),
) -> ((String) -> Array[@tui.Span])? {
  guard path.has_suffix(".mbt") ||
    path.has_suffix(".mbti") ||
    path.has_suffix(".mbtx") else {
    return None
  }
  let tokenizer = @lang_moonbit.MoonBitTokenizer()
  Some(line => {
    let (tokens, _) = tokenizer.tokenize_line(line, tokenizer.initial_state())
    let spans : Array[@tui.Span] = []
    let mut at = 0
    for token in tokens {
      if at < token.start {
        spans.push(@tui.Span(line[at:token.start], style=base))
      }
      spans.push(
        @tui.Span(
          line[token.start:token.end],
          style=token_style(token.tag, base, theme),
        ),
      )
      at = token.end
    }
    if at < line.length() {
      spans.push(@tui.Span(line[at:], style=base))
    }
    spans
  })
}

///|
fn token_style(
  tag : @syntax.HighlightTag,
  base : @tui.Style,
  theme : Theme,
) -> @tui.Style {
  @tui.Style(
    fg=match tag {
      Keyword => theme.keyword
      Type | Tag => theme.type_
      Function => theme.function_
      String | Regexp => theme.string
      Number | Constant => theme.number
      Comment | CommentDoc => theme.comment
      StringEscape | Attribute => theme.escape
      Invalid => theme.invalid
      Identifier | Variable | Plain | Punctuation | Operator | Delimiter =>
        base.fg
    },
    bg=base.bg,
    bold=base.bold,
    italic=base.italic,
    underline=base.underline,
    reverse=base.reverse,
  )
}
