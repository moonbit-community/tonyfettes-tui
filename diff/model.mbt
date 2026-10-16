///|
priv enum Kind {
  Context
  Added
  Removed
  Hunk
}

///|
priv struct UnifiedRow {
  prefix : String
  text : String
  kind : Kind
}

///|
priv struct SourceLine {
  number : Int32
  text : String
  changed : Bool
}

///|
priv enum SplitRow {
  Header(String)
  Cells(SourceLine?, SourceLine?)
}

///|
fn source_lines(source : String) -> Array[String] {
  if source.is_empty() {
    []
  } else {
    source.split("\n").map(line => line.to_owned()).collect()
  }
}

///|
fn displayed_text(text : String) -> String {
  text.strip_suffix("\r").map(line => line.to_owned()).unwrap_or(text)
}

///|
fn source_line(line : @model.DiffLine, changed : Bool) -> SourceLine {
  { number: line.index + 1, text: displayed_text(line.text()), changed, }
}

///|
fn diff_rows(
  original : String,
  modified : String,
  context : Int32,
) -> (Array[UnifiedRow], Array[SplitRow]) {
  let document = @linediff.line_diff(
    old=source_lines(original),
    new=source_lines(modified),
    context~,
  )
  let unified : Array[UnifiedRow] = []
  let split : Array[SplitRow] = []
  for hunk in document.hunks {
    let old_start = hunk.old_start + (if hunk.old_len == 0 { 0 } else { 1 })
    let new_start = hunk.new_start + (if hunk.new_len == 0 { 0 } else { 1 })
    let header = "@@ -\{old_start},\{hunk.old_len} +\{new_start},\{hunk.new_len} @@"
    unified.push({ prefix: "", text: header, kind: Hunk, })
    split.push(Header(header))
    for block in hunk.blocks {
      match block {
        ContextBlock(lines) =>
          for line in lines {
            let text = displayed_text(line.text)
            unified.push({ prefix: " ", text, kind: Context, })
            split.push(
              Cells(
                Some({ number: line.old_index + 1, text, changed: false, }),
                Some({ number: line.new_index + 1, text, changed: false, }),
              ),
            )
          }
        ChangeBlock(rows) | IgnoredBlock(rows) => {
          let changed = block is ChangeBlock(_)
          for row in rows {
            match row {
              Paired(old, new) =>
                split.push(
                  Cells(
                    Some(source_line(old, changed)),
                    Some(source_line(new, changed)),
                  ),
                )
              OldOnly(old) =>
                split.push(Cells(Some(source_line(old, changed)), None))
              NewOnly(new) =>
                split.push(Cells(None, Some(source_line(new, changed))))
            }
          }
          for row in rows {
            match row {
              Paired(old, _) | OldOnly(old) =>
                unified.push({
                  prefix: if changed {
                    "-"
                  } else {
                    " "
                  },
                  text: displayed_text(old.text()),
                  kind: if changed {
                    Removed
                  } else {
                    Context
                  },
                })
              NewOnly(_) => ()
            }
          }
          for row in rows {
            match row {
              Paired(_, new) | NewOnly(new) =>
                unified.push({
                  prefix: if changed {
                    "+"
                  } else {
                    " "
                  },
                  text: displayed_text(new.text()),
                  kind: if changed {
                    Added
                  } else {
                    Context
                  },
                })
              OldOnly(_) => ()
            }
          }
        }
      }
    }
  }
  (unified, split)
}
