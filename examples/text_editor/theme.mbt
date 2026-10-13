// The colors, after the Tokyo Night theme.

///|
fn rgb(hex : Int32) -> @color.Color {
  Rgb((hex >> 16) & 0xff, (hex >> 8) & 0xff, hex & 0xff)
}

///|
let background : @color.Color = rgb(0x1a1b26)

///|
let foreground : @color.Color = rgb(0xc0caf5)

///|
/// Plain text on the editor's background.
let text_style : @tui.Style = Style(fg=foreground, bg=background)

///|
let line_number_style : @tui.Style = Style(fg=rgb(0x3b4261), bg=background)

///|
/// Laid over the line the cursor is on.
let current_line_style : @tui.Style = Style(bg=rgb(0x292e42))

///|
/// The strip behind the file tab and the hints row.
let chrome_style : @tui.Style = Style(fg=rgb(0x565f89), bg=rgb(0x16161e))

///|
/// The tab of the open file: the editor's own background, so it reads as
/// attached to the text below.
let tab_style : @tui.Style = Style(fg=foreground, bg=background, bold=true)

///|
let modified_style : @tui.Style = Style(fg=rgb(0xe0af68), bg=background)

///|
let status_style : @tui.Style = Style(fg=foreground, bg=rgb(0x3b4261))

///|
/// The badge at the left of the status row.
let badge_style : @tui.Style = Style(
  fg=rgb(0x16161e),
  bg=rgb(0x7aa2f7),
  bold=true,
)

///|
let comment_style : @tui.Style = Style(fg=rgb(0x565f89), italic=true)

///|
let keyword_style : @tui.Style = Style(fg=rgb(0xbb9af7))

///|
let string_style : @tui.Style = Style(fg=rgb(0x9ece6a))

///|
let number_style : @tui.Style = Style(fg=rgb(0xff9e64))

///|
let type_style : @tui.Style = Style(fg=rgb(0x2ac3de))

///|
let function_style : @tui.Style = Style(fg=rgb(0x7aa2f7))

///|
let package_style : @tui.Style = Style(fg=rgb(0xe0af68))

///|
let operator_style : @tui.Style = Style(fg=rgb(0x89ddff))
