///|
/// How a cell is drawn: its colors and text attributes.
pub struct Style {
  fg : @color.Color
  bg : @color.Color
  bold : Bool
  italic : Bool
  underline : Bool
  reverse : Bool
} derive(Eq, Debug)

///|
/// Build a style. Omitted fields keep the terminal default, so `Style()` is
/// unstyled text and `Style(fg=Basic(Red), bold=true)` changes only those two.
pub fn Style::Style(
  fg? : @color.Color = Default,
  bg? : @color.Color = Default,
  bold? : Bool = false,
  italic? : Bool = false,
  underline? : Bool = false,
  reverse? : Bool = false,
) -> Style {
  { fg, bg, bold, italic, underline, reverse, }
}

///|
pub extend Style with Eq::{equal, not_equal}

///|
pub extend Style with @debug.Debug::{to_repr}
