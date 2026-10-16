///|
fn Renderer::table(
  self : Renderer,
  table : @cmark.Table,
  width : Int32,
) -> Array[@tui.Line] {
  let rows : Array[Array[Array[@tui.Line]]] = []
  let aligns : Array[@cmark.TableAlign?] = []
  for (row, _) in table.rows.iter() {
    match row.v {
      Header(cells) | Data(cells) =>
        rows.push(
          cells
          .iter()
          .map(cell => {
            self.inline_lines(
              cell.0,
              if row.v is Header(_) {
                self.heading()
              } else {
                self.base()
              },
            )
          })
          .collect(),
        )
      Sep(cells) =>
        for cell in cells.iter() {
          aligns.push(cell.v.0.0)
        }
    }
  }
  let cols = table.col_count
  guard cols > 0 && !rows.is_empty() else { return [] }
  // Narrow terminals show each record vertically, keeping its column labels.
  // A squeezed grid makes long commands and their results hard to associate.
  if width < cols * 24 + (cols - 1) * 3 {
    let lines : Array[@tui.Line] = []
    if rows.length() == 1 {
      return rows[0]
        .iter()
        .flat_map(cell => cell.iter().flat_map(line => line.wrap(width).iter()))
        .collect()
    }
    for row in rows[1:] {
      if !lines.is_empty() {
        lines.push(@tui.Line([]))
      }
      for col in 0..<cols {
        let header = rows[0]
          .get(col)
          .unwrap_or([])
          .map(line => line.to_text())
          .join(" ")
        let label = @tui.Line::from_text("\{header}: ", style=self.heading())
        let cell = row.get(col).unwrap_or([@tui.Line([])])
        for i, line in cell {
          lines.append(
            (if i == 0 { label.concat(line) } else { line }).wrap(width),
          )
        }
      }
    }
    return lines
  }
  let widths = Array::make(cols, 1)
  for row in rows {
    for col, cell in row {
      if col < cols {
        for line in cell {
          widths[col] = widths[col].max(line.width())
        }
      }
    }
  }
  let available = width - (cols - 1) * 3
  let mut total = widths.fold(init=0, (sum, value) => sum + value)
  while total > available {
    let mut widest = 0
    for col in 1..<cols {
      if widths[col] > widths[widest] {
        widest = col
      }
    }
    widths[widest] -= 1
    total -= 1
  }
  let lines : Array[@tui.Line] = []
  for index, row in rows {
    let cells = Array::makei(cols, col => {
      row
      .get(col)
      .unwrap_or([@tui.Line([])])
      .iter()
      .flat_map(line => line.wrap(widths[col]).iter())
      .collect()
    })
    let height = cells.fold(init=1, (height, cell) => height.max(cell.length()))
    for y in 0..<height {
      let mut line = @tui.Line([])
      for col, cell in cells {
        if col > 0 {
          line = line.concat(@tui.Line::from_text(" │ ", style=self.muted()))
        }
        let value = cell.get(y).unwrap_or(@tui.Line([]))
        let padding = (widths[col] - value.width()).max(0)
        let before = match aligns.get(col).bind(x => x) {
          Some(Right) => padding
          Some(Center) => padding / 2
          _ => 0
        }
        line = line
          .concat(@tui.Line::from_text(" ".repeat(before), style=self.base()))
          .concat(value)
          .concat(
            @tui.Line::from_text(
              " ".repeat(padding - before),
              style=self.base(),
            ),
          )
      }
      lines.push(line)
    }
    if index == 0 {
      lines.push(
        @tui.Line::from_text(
          widths.map(size => "─".repeat(size)).join("─┼─"),
          style=self.muted(),
        ),
      )
    }
  }
  lines
}
