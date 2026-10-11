///|
fn heights(areas : Array[@tui.Rect]) -> Array[(Int, Int)] {
  areas.map(area => (area.row, area.height))
}

///|
test "split rows gives fixed pieces their size and fill the rest" {
  let area = @tui.Rect(row=0, col=0, width=80, height=24)
  let rows = area.split_rows([Fixed(1), Fill, Fixed(3), Fixed(1)])
  debug_inspect(
    heights(rows),
    content=(
      #|[(0, 1), (1, 19), (20, 3), (23, 1)]
    ),
  )
  for row in rows {
    @debug.assert_eq((row.col, row.width), (0, 80))
  }
}

///|
test "fill pieces share the rest, earlier ones taking the extra" {
  let area = @tui.Rect(row=2, col=5, width=10, height=3)
  let cols = area.split_cols([Fill, Fixed(2), Fill, Fill])
  debug_inspect(
    cols.map(col => (col.col, col.width)),
    content=(
      #|[(5, 3), (8, 2), (10, 3), (13, 2)]
    ),
  )
  for col in cols {
    @debug.assert_eq((col.row, col.height), (2, 3))
  }
}

///|
test "pieces that do not fit shrink to zero but are still returned" {
  let area = @tui.Rect(row=0, col=0, width=10, height=4)
  debug_inspect(
    heights(area.split_rows([Fixed(3), Fill, Fixed(3), Fixed(3)])),
    content=(
      #|[(0, 3), (3, 0), (3, 1), (4, 0)]
    ),
  )
  debug_inspect(
    heights(area.split_rows([])),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    heights(area.split_rows([Fixed(-5), Fill])),
    content=(
      #|[(0, 0), (0, 4)]
    ),
  )
}

///|
test "a rect never has a negative size" {
  @debug.assert_eq(
    @tui.Rect(row=1, col=1, width=-3, height=-1),
    @tui.Rect(row=1, col=1, width=0, height=0),
  )
}
