///|
/// Display format. Split mode falls back to unified below forty columns.
pub(all) enum Mode {
  Unified
  Split
}

///|
/// Styles for unchanged text, additions, removals, hunk headings, pane labels
/// and the split separator. Values are immutable after construction.
struct Theme {
  text : @tui.Style
  added : @tui.Style
  removed : @tui.Style
  hunk : @tui.Style
  label : @tui.Style
  separator : @tui.Style
}

///|
pub fn Theme::Theme(
  text~ : @tui.Style = @tui.Style(),
  added~ : @tui.Style = @tui.Style(fg=Rgb(139, 222, 173), bg=Rgb(20, 45, 32)),
  removed~ : @tui.Style = @tui.Style(fg=Rgb(241, 164, 166), bg=Rgb(48, 27, 32)),
  hunk~ : @tui.Style = @tui.Style(fg=Rgb(117, 185, 239), bg=Rgb(26, 36, 50)),
  label~ : @tui.Style = @tui.Style(fg=Rgb(143, 157, 178), bg=Rgb(28, 36, 49)),
  separator~ : @tui.Style = @tui.Style(fg=Rgb(48, 60, 79)),
) -> Theme {
  { text, added, removed, hunk, label, separator, }
}
