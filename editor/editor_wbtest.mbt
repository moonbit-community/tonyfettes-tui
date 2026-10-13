// These tests look inside the editor because what they check is an internal
// invariant: however the text was arrived at, the glyphs the editor holds are
// the ones its text would be cut into from scratch. An edit only cuts a window
// around itself again, so this is what could silently go wrong.

///|
fn check_glyphs(editor : Editor, context : String) -> Unit raise {
  let fresh = glyphs_of(editor.text())
  let held = editor.glyphs.map(glyph => (glyph.text, glyph.width))
  let expected = fresh.map(glyph => (glyph.text, glyph.width))
  if held != expected {
    fail(
      "\{context}: the editor holds \{Repr(held)} but its text cuts into \{Repr(expected)}",
    )
  }
  if editor.cursor < 0 || editor.cursor > editor.glyphs.length() {
    fail("\{context}: the cursor is at \{editor.cursor}, outside the text")
  }
}

///|
test "after any edit the glyphs are those of the text cut from scratch" {
  // Pieces chosen because what they are depends on their neighbours: marks
  // that join the letter before them, letters that join into a ligature,
  // flags made of two regional indicators, and emoji joined by a ZWJ or
  // followed by a skin tone.
  let pieces = [
    "a", "b", " ", "\n", "你", "e", "\u{301}", "\u{644}", "\u{627}", "\u{1F1E6}",
    "\u{1F1E8}", "\u{1F1F3}", "\u{1F469}", "\u{200D}", "\u{1F4BB}", "\u{1F3FD}",
    "x\u{301}y", "\u{1F1E6}\u{1F1E8}\u{1F1F3}", "\u{1F469}\u{200D}\u{1F4BB}",
  ]
  let editor = Editor()
  // A small linear congruential generator keeps the edits varied but the
  // test deterministic.
  let mut seed = 20261014
  fn next(bound : Int32) -> Int32 {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    seed / 16 % bound
  }

  for step in 0..<3000 {
    // Go somewhere, then change something there.
    for _ in 0..<next(6) {
      match next(4) {
        0 => editor.move_left()
        1 => editor.move_right()
        2 => ignore(editor.move_up())
        _ => ignore(editor.move_down())
      }
    }
    match next(10) {
      0 => editor.delete_before()
      1 => editor.delete_after()
      2 => editor.delete_word_before()
      3 => editor.kill_after()
      _ => editor.insert(pieces[next(pieces.length())])
    }
    check_glyphs(editor, "step \{step}")
  }
}

///|
test "long runs that pair up are cut again as far as an edit reaches" {
  // Regional indicators pair into flags from the start of a run, so adding
  // one at the front changes every pair after it. The window around the edit
  // has to keep widening until it covers the whole run.
  let flags = "\u{1F1E6}\u{1F1E8}".repeat(200)
  let editor = Editor(text="start " + flags + " end")
  editor.move_to_start()
  for _ in 0..<6 {
    editor.move_right()
  }
  editor.insert("\u{1F1F3}")
  check_glyphs(editor, "after inserting into the run")
  editor.delete_before()
  check_glyphs(editor, "after deleting it again")
}

///|
test "an edit far inside a long line leaves the rest of the line alone" {
  let editor = Editor(text="ab".repeat(500))
  for _ in 0..<400 {
    editor.move_left()
  }
  editor.insert("\u{301}")
  editor.insert("Z")
  check_glyphs(editor, "after the edits")
  // The mark joined the letter before it, so only "Z" added a column.
  @debug.assert_eq(editor.position(), (0, 601))
  inspect(editor.text().length(), content="1002")
}
