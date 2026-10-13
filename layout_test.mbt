///|
/// The position and size of each area along the layout's direction.
fn rows(areas : Array[@tui.Rect]) -> Array[(Int32, Int32)] {
  areas.map(area => (area.row, area.height))
}

///|
fn cols(areas : Array[@tui.Rect]) -> Array[(Int32, Int32)] {
  areas.map(area => (area.col, area.width))
}

///|
let screen : @tui.Rect = @tui.Rect(row=0, col=0, width=80, height=24)

///|
test "lengths take their size and a fill takes the rest" {
  let areas = @tui.Layout::vertical([Length(1), Fill(1), Length(3), Length(1)]).split(
    screen,
  )
  @debug.assert_eq(rows(areas), [(0, 1), (1, 19), (20, 3), (23, 1)])
  // Across the direction, every piece spans the whole area.
  for area in areas {
    @debug.assert_eq((area.col, area.width), (0, 80))
  }
}

///|
test "horizontal lays the pieces out left to right" {
  let area = @tui.Rect(row=2, col=5, width=10, height=3)
  let areas = @tui.Layout::horizontal([Fill(1), Length(2), Fill(1), Fill(1)]).split(
    area,
  )
  // Eight columns among three fills: two each, and the two left over go to
  // the earliest.
  @debug.assert_eq(cols(areas), [(5, 3), (8, 2), (10, 3), (13, 2)])
  for area in areas {
    @debug.assert_eq((area.row, area.height), (2, 3))
  }
}

///|
test "fills share the leftover space by weight" {
  // Twenty rows at one to two: 6 and 13, and the row rounding left goes to
  // the first.
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Fill(1), Fill(2), Length(4)]).split(screen)),
    [(0, 7), (7, 13), (20, 4)],
  )
  // A weight of zero gets nothing.
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Fill(0), Fill(3)]).split(screen)),
    [(0, 0), (0, 24)],
  )
}

///|
test "percentage and ratio are shares of the whole space" {
  @debug.assert_eq(
    cols(
      @tui.Layout::horizontal([Percentage(25), Ratio(1, 4), Fill(1)]).split(
        screen,
      ),
    ),
    [(0, 20), (20, 20), (40, 40)],
  )
  // A ratio over zero is nothing rather than an error.
  @debug.assert_eq(
    cols(@tui.Layout::horizontal([Ratio(1, 0), Fill(1)]).split(screen)),
    [(0, 0), (0, 80)],
  )
}

///|
test "min grows only when no fill claims the leftover space" {
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Length(1), Min(5)]).split(screen)),
    [(0, 1), (1, 23)],
  )
  // Two minimums split what is left equally: nine more rows each.
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Min(2), Min(4)]).split(screen)),
    [(0, 11), (11, 13)],
  )
  // Next to a fill, a minimum stays at its minimum.
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Min(5), Fill(1)]).split(screen)),
    [(0, 5), (5, 19)],
  )
}

///|
test "max takes its size when there is room and less when there is not" {
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Max(10), Fill(1)]).split(screen)),
    [(0, 10), (10, 14)],
  )
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Length(20), Max(10)]).split(screen)),
    [(0, 20), (20, 4)],
  )
}

///|
test "when space runs out the later pieces shrink, but all are returned" {
  let area = @tui.Rect(row=0, col=0, width=10, height=4)
  @debug.assert_eq(
    rows(
      @tui.Layout::vertical([Length(3), Fill(1), Length(3), Length(3)]).split(
        area,
      ),
    ),
    [(0, 3), (3, 0), (3, 1), (4, 0)],
  )
  // Asking for more than everything is the same as asking for everything.
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Percentage(150), Length(2)]).split(area)),
    [(0, 4), (4, 0)],
  )
  // Negative sizes count as zero.
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Length(-5), Fill(1)]).split(area)),
    [(0, 0), (0, 4)],
  )
  @debug.assert_eq(rows(@tui.Layout::vertical([]).split(area)), [])
  // An area with no room gives areas with no room.
  let empty = @tui.Rect(row=3, col=3, width=0, height=0)
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Length(2), Fill(1)]).split(empty)),
    [(3, 0), (3, 0)],
  )
}

///|
test "spacing leaves gaps between the pieces, not around them" {
  let area = @tui.Rect(row=0, col=0, width=20, height=1)
  // Two gaps of one column leave eighteen: 5, 8 and 5.
  @debug.assert_eq(
    cols(
      @tui.Layout::horizontal([Length(5), Fill(1), Length(5)], spacing=1).split(
        area,
      ),
    ),
    [(0, 5), (6, 8), (15, 5)],
  )
  // A single piece has no gaps.
  @debug.assert_eq(
    cols(@tui.Layout::horizontal([Fill(1)], spacing=3).split(area)),
    [(0, 20)],
  )
}

///|
test "margin shrinks the area on every side before it is divided" {
  let areas = @tui.Layout::vertical([Length(2), Fill(1)], margin=1).split(
    screen,
  )
  @debug.assert_eq(areas, [
    Rect(row=1, col=1, width=78, height=2),
    Rect(row=3, col=1, width=78, height=20),
  ])
  // A margin larger than the area leaves nothing.
  let tiny = @tui.Rect(row=0, col=0, width=3, height=1)
  @debug.assert_eq(
    rows(@tui.Layout::vertical([Fill(1)], margin=2).split(tiny)),
    [(2, 0)],
  )
}

///|
test "flex places pieces that leave space unused" {
  let area = @tui.Rect(row=0, col=0, width=20, height=1)
  let pieces : Array[@tui.Constraint] = [Length(4), Length(6)]
  @debug.assert_eq(cols(@tui.Layout::horizontal(pieces).split(area)), [
    (0, 4),
    (4, 6),
  ])
  @debug.assert_eq(
    cols(@tui.Layout::horizontal(pieces, flex=End).split(area)),
    [(10, 4), (14, 6)],
  )
  @debug.assert_eq(
    cols(@tui.Layout::horizontal(pieces, flex=Center).split(area)),
    [(5, 4), (9, 6)],
  )
  @debug.assert_eq(
    cols(@tui.Layout::horizontal(pieces, flex=SpaceBetween).split(area)),
    [(0, 4), (14, 6)],
  )
  // Fourteen unused columns between three pieces: seven in each gap.
  @debug.assert_eq(
    cols(
      @tui.Layout::horizontal(
        [Length(2), Length(2), Length(2)],
        flex=SpaceBetween,
      ).split(area),
    ),
    [(0, 2), (9, 2), (18, 2)],
  )
  // With a fill there is no unused space, so flex changes nothing.
  @debug.assert_eq(
    cols(@tui.Layout::horizontal([Length(4), Fill(1)], flex=End).split(area)),
    [(0, 4), (4, 16)],
  )
}

///|
test "centering a box takes one layout in each direction" {
  // The way to place a dialog: a fixed size, centered both ways.
  guard @tui.Layout::vertical([Length(4)], flex=Center).split(screen) is [band] else {
    fail("one constraint gives one area")
  }
  guard @tui.Layout::horizontal([Length(30)], flex=Center).split(band)
    is [dialog] else {
    fail("one constraint gives one area")
  }
  @debug.assert_eq(dialog, @tui.Rect(row=10, col=25, width=30, height=4))
}

///|
test "a rect never has a negative size" {
  @debug.assert_eq(
    @tui.Rect(row=1, col=1, width=-3, height=-1),
    @tui.Rect(row=1, col=1, width=0, height=0),
  )
}
