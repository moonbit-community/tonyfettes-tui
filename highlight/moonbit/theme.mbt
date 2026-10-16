///|
/// Foreground colors for the MoonBit lexer's token classes. Background and
/// emphasis always come from the base style supplied to `for_path`.
struct Theme {
  keyword : @color.Color
  type_ : @color.Color
  function_ : @color.Color
  string : @color.Color
  number : @color.Color
  comment : @color.Color
  escape : @color.Color
  invalid : @color.Color
}

///|
pub fn Theme::Theme(
  keyword~ : @color.Color = Rgb(86, 156, 214),
  type_~ : @color.Color = Rgb(78, 201, 176),
  function_~ : @color.Color = Rgb(220, 220, 170),
  string~ : @color.Color = Rgb(206, 145, 120),
  number~ : @color.Color = Rgb(181, 206, 168),
  comment~ : @color.Color = Rgb(106, 153, 85),
  escape~ : @color.Color = Rgb(215, 186, 125),
  invalid~ : @color.Color = Rgb(255, 136, 145),
) -> Theme {
  { keyword, type_, function_, string, number, comment, escape, invalid, }
}
