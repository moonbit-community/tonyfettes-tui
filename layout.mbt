///|
/// How much of the space one piece of a layout takes.
pub(all) enum Constraint {
  /// Exactly this many rows or columns.
  Length(Int32)
  /// This percentage of the space.
  Percentage(Int32)
  /// This fraction of the space: `Ratio(1, 3)` is a third.
  Ratio(Int32, Int32)
  /// At least this many. It grows into space that no `Fill` claims.
  Min(Int32)
  /// At most this many. It takes that much when there is room.
  Max(Int32)
  /// A share of the space the other pieces leave over, in proportion to its
  /// weight: `Fill(2)` gets twice what `Fill(1)` gets.
  Fill(Int32)
} derive(Eq, Debug)

///|
/// Where the pieces of a layout sit when they do not use all of the space,
/// which happens only when none of them is a `Fill` or a `Min`.
pub(all) enum Flex {
  /// Together at the start, leaving the space after them.
  Start
  /// Together in the middle.
  Center
  /// Together at the end.
  End
  /// The first at the start, the last at the end, the space shared out between
  /// them.
  SpaceBetween
} derive(Eq, Debug)

///|
priv enum Direction {
  Vertical
  Horizontal
}

///|
/// A way of dividing an area into pieces along one direction.
///
/// `Layout::vertical` stacks the pieces top to bottom and
/// `Layout::horizontal` puts them side by side; `split` applies the layout to
/// an area. A layout is a plain value: build it where it is used, or keep one
/// and split different areas with it.
///
/// The sizes are worked out in three steps, the same way in both directions:
///
/// 1. Each piece asks for a size: `Length`, `Min` and `Max` for their number,
///    `Percentage` and `Ratio` for their share of the space, `Fill` for
///    nothing.
/// 2. The pieces are served in order. Each gets what it asked for, or what is
///    left if that is less, so when the space runs out it is the later pieces
///    that shrink.
/// 3. Space still left goes to the `Fill` pieces in proportion to their
///    weights. With no `Fill`, it goes to the `Min` pieces in equal parts.
///    With neither, it stays empty and `flex` says where.
struct Layout {
  direction : Direction
  constraints : Array[Constraint]
  spacing : Int32
  margin : Int32
  flex : Flex
}

///|
/// A layout that stacks its pieces top to bottom, one per constraint.
///
/// `spacing` leaves that many empty rows between neighbouring pieces, and
/// `margin` that many rows and columns around all of them. `flex` places the
/// pieces when they do not fill the space.
pub fn Layout::vertical(
  constraints : Array[Constraint],
  spacing~ : Int32 = 0,
  margin~ : Int32 = 0,
  flex~ : Flex = Start,
) -> Layout {
  {
    direction: Vertical,
    constraints: constraints.copy(),
    spacing: spacing.max(0),
    margin: margin.max(0),
    flex,
  }
}

///|
/// A layout that puts its pieces side by side, left to right, one per
/// constraint.
///
/// `spacing` leaves that many empty columns between neighbouring pieces, and
/// `margin` that many rows and columns around all of them. `flex` places the
/// pieces when they do not fill the space.
pub fn Layout::horizontal(
  constraints : Array[Constraint],
  spacing~ : Int32 = 0,
  margin~ : Int32 = 0,
  flex~ : Flex = Start,
) -> Layout {
  {
    direction: Horizontal,
    constraints: constraints.copy(),
    spacing: spacing.max(0),
    margin: margin.max(0),
    flex,
  }
}

///|
/// The size a piece asks for out of `space`, before anything is shared out.
fn Constraint::wanted(self : Constraint, space : Int32) -> Int32 {
  let size = match self {
    Length(size) | Min(size) | Max(size) => size
    Percentage(percent) => space * percent / 100
    Ratio(_, 0) => 0
    Ratio(part, whole) => space * part / whole
    Fill(_) => 0
  }
  size.max(0)
}

///|
/// Share `extra` among the pieces with a positive weight, in proportion to
/// the weights. What rounding leaves over goes to the earliest of them, one
/// each.
fn share(sizes : Array[Int32], weights : Array[Int32], extra : Int32) -> Unit {
  let mut total = 0
  for weight in weights {
    total += weight
  }
  if total == 0 {
    return
  }
  let mut given = 0
  for index, weight in weights {
    let part = extra * weight / total
    sizes[index] += part
    given += part
  }
  let mut rest = extra - given
  for index, weight in weights {
    if rest == 0 {
      break
    }
    if weight > 0 {
      sizes[index] += 1
      rest -= 1
    }
  }
}

///|
/// The sizes of the pieces in `space`, and how much of it none of them took.
fn sizes(
  constraints : Array[Constraint],
  space : Int32,
) -> (Array[Int32], Int32) {
  let sizes = []
  let mut left = space
  for constraint in constraints {
    let size = constraint.wanted(space).min(left)
    sizes.push(size)
    left -= size
  }
  let fills = constraints.map(constraint => {
    if constraint is Fill(weight) {
      weight.max(0)
    } else {
      0
    }
  })
  let minimums = constraints.map(constraint => {
    if constraint is Min(_) {
      1
    } else {
      0
    }
  })
  for weights in [fills, minimums] {
    if weights.any(weight => weight > 0) {
      share(sizes, weights, left)
      return (sizes, 0)
    }
  }
  (sizes, left)
}

///|
/// Divide `area` into one area per constraint.
///
/// The result always has as many areas as the layout has constraints, in
/// order, so it can be destructured to name them:
///
/// ```mbt nocheck
/// guard! Layout::vertical([Length(1), Fill(1), Length(1)]).split(area)
///   is [header, body, footer]
/// ```
///
/// Pieces that do not fit come out with a size of zero.
pub fn Layout::split(self : Layout, area : Rect) -> Array[Rect] {
  let area = Rect(
    row=area.row + self.margin,
    col=area.col + self.margin,
    width=area.width - 2 * self.margin,
    height=area.height - 2 * self.margin,
  )
  let count = self.constraints.length()
  let length = match self.direction {
    Vertical => area.height
    Horizontal => area.width
  }
  let gaps = self.spacing * (count - 1).max(0)
  let (sizes, unused) = sizes(self.constraints, (length - gaps).max(0))
  // Where the first piece starts, and how much each gap grows, when the
  // pieces leave space unused.
  let (lead, between) = match self.flex {
    Start => (0, 0)
    Center => (unused / 2, 0)
    End => (unused, 0)
    SpaceBetween => if count > 1 { (0, unused) } else { (0, 0) }
  }
  let areas = []
  let mut offset = lead
  for index, size in sizes {
    areas.push(
      match self.direction {
        Vertical =>
          Rect(
            row=area.row + offset,
            col=area.col,
            width=area.width,
            height=size,
          )
        Horizontal =>
          Rect(
            row=area.row,
            col=area.col + offset,
            width=size,
            height=area.height,
          )
      },
    )
    // The gap after this piece: the spacing, plus this gap's part of the
    // space being spread between the pieces.
    let gap = if index < count - 1 {
      between * (index + 1) / (count - 1) - between * index / (count - 1)
    } else {
      0
    }
    offset += size + self.spacing + gap
  }
  areas
}
