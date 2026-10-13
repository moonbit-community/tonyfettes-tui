///|
/// A rectangular area of a frame: `height` rows starting at `row`, `width`
/// columns starting at `col`. Rows and columns are 0-based.
pub struct Rect {
  row : Int32
  col : Int32
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
/// Build an area. A negative width or height becomes zero.
pub fn Rect::Rect(
  row~ : Int32,
  col~ : Int32,
  width~ : Int32,
  height~ : Int32,
) -> Rect {
  { row, col, width: width.max(0), height: height.max(0), }
}

///|
/// The part of `self` that is also inside `other`.
fn Rect::intersect(self : Rect, other : Rect) -> Rect {
  let row = self.row.max(other.row)
  let col = self.col.max(other.col)
  let bottom = (self.row + self.height).min(other.row + other.height)
  let right = (self.col + self.width).min(other.col + other.width)
  Rect(row~, col~, width=right - col, height=bottom - row)
}
