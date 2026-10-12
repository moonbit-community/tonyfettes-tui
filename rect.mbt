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
pub extend Rect with Eq::{equal, not_equal}

///|
pub extend Rect with @debug.Debug::{to_repr}

///|
/// The part of `self` that is also inside `other`.
fn Rect::intersect(self : Rect, other : Rect) -> Rect {
  let row = self.row.max(other.row)
  let col = self.col.max(other.col)
  let bottom = (self.row + self.height).min(other.row + other.height)
  let right = (self.col + self.width).min(other.col + other.width)
  Rect(row~, col~, width=right - col, height=bottom - row)
}

///|
/// How much of an area one piece of a split takes.
pub(all) enum Length {
  /// Exactly this many rows or columns, or whatever is left if there are fewer.
  Fixed(Int32)
  /// An equal share of what the `Fixed` pieces leave over.
  Fill
} derive(Eq, Debug)

///|
pub extend Length with Eq::{equal, not_equal}

///|
pub extend Length with @debug.Debug::{to_repr}

///|
/// Divide `total` rows or columns among `lengths`. `Fixed` pieces are served
/// first, in order; the `Fill` pieces share the rest, the earlier ones taking
/// the extra when it does not divide evenly.
fn divide(total : Int32, lengths : Array[Length]) -> Array[Int32] {
  let sizes = []
  let mut rest = total
  let mut fills = 0
  for length in lengths {
    match length {
      Fixed(size) => {
        let size = size.clamp(min=0, max=rest)
        rest -= size
        sizes.push(size)
      }
      Fill => {
        fills += 1
        sizes.push(0)
      }
    }
  }
  if fills > 0 {
    let share = rest / fills
    let mut extra = rest % fills
    for index, length in lengths {
      if length is Fill {
        sizes[index] = if extra > 0 { share + 1 } else { share }
        extra -= 1
      }
    }
  }
  sizes
}

///|
/// Split the area into stacked pieces, top to bottom, one per length. The
/// result always has as many areas as `lengths`; pieces that do not fit have a
/// height of zero.
///
/// Name the pieces by destructuring the result:
///
/// ```mbt nocheck
/// guard! area.split_rows([Fixed(1), Fill, Fixed(1)]) is [header, body, footer]
/// ```
pub fn Rect::split_rows(self : Rect, lengths : Array[Length]) -> Array[Rect] {
  let mut row = self.row
  divide(self.height, lengths).map(height => {
    let area = Rect(row~, col=self.col, width=self.width, height~)
    row += height
    area
  })
}

///|
/// Split the area into side-by-side pieces, left to right, one per length. The
/// result always has as many areas as `lengths`; pieces that do not fit have a
/// width of zero.
///
/// Name the pieces by destructuring the result:
///
/// ```mbt nocheck
/// guard! area.split_cols([Fixed(20), Fill]) is [sidebar, main]
/// ```
pub fn Rect::split_cols(self : Rect, lengths : Array[Length]) -> Array[Rect] {
  let mut col = self.col
  divide(self.width, lengths).map(width => {
    let area = Rect(row=self.row, col~, width~, height=self.height)
    col += width
    area
  })
}
