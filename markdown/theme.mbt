///|
/// Styles for terminal Markdown. Default colors preserve the original dark
/// palette. Pass terminal-default colors to inherit the surrounding panel.
struct Theme {
  text : @tui.Style
  muted : @tui.Style
  heading : @tui.Style
  code : @tui.Style
  link : @tui.Style
}

///|
/// Configure semantic styles. Role colors set to `Default` inherit the current
/// text colors; role attributes add to enclosing emphasis.
pub fn Theme::Theme(
  text~ : @tui.Style = @tui.Style(),
  muted~ : @tui.Style = @tui.Style(fg=Rgb(133, 148, 169)),
  heading~ : @tui.Style = @tui.Style(fg=Rgb(118, 194, 255), bold=true),
  code~ : @tui.Style = @tui.Style(fg=Rgb(210, 200, 166), bg=Rgb(25, 31, 41)),
  link~ : @tui.Style = @tui.Style(fg=Rgb(118, 194, 255), underline=true),
) -> Theme {
  { text, muted, heading, code, link, }
}

///|
fn styled(base : @tui.Style, role : @tui.Style) -> @tui.Style {
  @tui.Style(
    fg=if role.fg is Default { base.fg } else { role.fg },
    bg=if role.bg is Default { base.bg } else { role.bg },
    bold=base.bold || role.bold,
    italic=base.italic || role.italic,
    underline=base.underline || role.underline,
    reverse=base.reverse || role.reverse,
  )
}
