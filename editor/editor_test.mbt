///|
/// Draw `editor` into a frame of `width` by `height` and return the rows it
/// shows, with a `^` under the cursor on the row after the one it is on. Blank
/// rows below the text and the cursor are left out.
fn edited(
  editor : @editor.Editor,
  width~ : Int32 = 12,
  height~ : Int32 = 4,
) -> String {
  let frame = @tui.Frame(width~, height~)
  editor.draw(frame, frame.area())
  let rows = []
  for index, text in frame.to_text().split("\n").collect() {
    rows.push(text.to_owned())
    if frame.cursor() is Some(cursor) && cursor.row == index {
      rows.push(" ".repeat(cursor.col) + "^")
    }
  }
  while rows.length() > 0 && rows[rows.length() - 1] == "" {
    ignore(rows.pop())
  }
  rows.join("\n")
}

///|
fn key(
  code : @input.KeyCode,
  ctrl~ : Bool = false,
  alt~ : Bool = false,
  shift~ : Bool = false,
) -> @input.KeyEvent {
  @input.KeyEvent::new(
    code,
    modifiers=@input.KeyModifiers::new(ctrl~, alt~, shift~),
  )
}

///|
/// A key that types `text`.
fn typed(text : String) -> @input.KeyEvent {
  @input.KeyEvent::new(Text, text~)
}

///|
test "typing inserts at the cursor" {
  let editor = @editor.Editor()
  assert_true(editor.is_empty())
  assert_true(editor.key(typed("h")))
  assert_true(editor.key(typed("i")))
  inspect(
    edited(editor),
    content=(
      #|hi
      #|  ^
    ),
  )
  editor.move_left()
  editor.insert("ell")
  inspect(
    edited(editor),
    content=(
      #|helli
      #|    ^
    ),
  )
  inspect(
    editor.text(),
    content=(
      #|helli
    ),
  )
  assert_true(!editor.is_empty())
}

///|
test "moving and deleting go by grapheme, so a wide one is a single step" {
  let editor = @editor.Editor(text="a你b")
  editor.move_left()
  editor.move_left()
  inspect(
    edited(editor),
    content=(
      #|a你b
      #| ^
    ),
  )
  editor.delete_after()
  inspect(
    edited(editor),
    content=(
      #|ab
      #| ^
    ),
  )
  editor.delete_before()
  inspect(
    edited(editor),
    content=(
      #|b
      #|^
    ),
  )
  // Nothing happens at either end.
  editor.delete_before()
  editor.move_left()
  editor.move_right()
  editor.move_right()
  editor.delete_after()
  inspect(
    editor.text(),
    content=(
      #|b
    ),
  )
}

///|
test "word movement and deletion" {
  let editor = @editor.Editor(text="foo bar_baz  你好 qux")
  editor.move_word_left()
  inspect(
    edited(editor, width=30),
    content=(
      #|foo bar_baz  你好 qux
      #|                  ^
    ),
  )
  editor.move_word_left()
  editor.move_word_left()
  inspect(
    edited(editor, width=30),
    content=(
      #|foo bar_baz  你好 qux
      #|    ^
    ),
  )
  editor.move_word_right()
  inspect(
    edited(editor, width=30),
    content=(
      #|foo bar_baz  你好 qux
      #|           ^
    ),
  )
  editor.delete_word_before()
  inspect(
    edited(editor, width=30),
    content=(
      #|foo   你好 qux
      #|    ^
    ),
  )
  editor.move_home()
  editor.delete_word_before()
  inspect(
    editor.text(),
    content=(
      #|foo   你好 qux
    ),
  )
}

///|
test "home, end and kills work on the line between line breaks" {
  let editor = @editor.Editor(text="first\nsecond line\nthird")
  editor.move_up() |> ignore
  editor.move_home()
  for _ in 0..<6 {
    editor.move_right()
  }
  inspect(
    edited(editor, width=20),
    content=(
      #|first
      #|second line
      #|      ^
      #|third
    ),
  )
  editor.kill_after()
  inspect(
    edited(editor, width=20),
    content=(
      #|first
      #|second
      #|      ^
      #|third
    ),
  )
  // At the end of a line, kill_after joins the next line.
  editor.kill_after()
  inspect(
    edited(editor, width=20),
    content=(
      #|first
      #|secondthird
      #|      ^
    ),
  )
  editor.kill_before()
  inspect(
    edited(editor, width=20),
    content=(
      #|first
      #|third
      #|^
    ),
  )
  editor.move_end()
  inspect(
    edited(editor, width=20),
    content=(
      #|first
      #|third
      #|     ^
    ),
  )
}

///|
test "long lines wrap, leaving the last column for the cursor" {
  let editor = @editor.Editor(text="abcdefghij")
  // Width 6 holds five glyphs per row.
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|fghij
      #|     ^
    ),
  )
  @debug.assert_eq(editor.height(width=6), 2)
  @debug.assert_eq(editor.height(width=6, max=1), 1)
  @debug.assert_eq(editor.height(width=11), 1)
  @debug.assert_eq(editor.height(width=10), 2)
  // A wide glyph that does not fit moves to the next row whole.
  let wide = @editor.Editor(text="abcd你好")
  inspect(
    edited(wide, width=6),
    content=(
      #|abcd
      #|你好
      #|    ^
    ),
  )
}

///|
test "at a wrap point the cursor is shown at the start of the next row" {
  let editor = @editor.Editor(text="abcdefgh")
  for _ in 0..<3 {
    editor.move_left()
  }
  // Index 5 is both the end of "abcde" and the start of "fgh".
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|fgh
      #|^
    ),
  )
}

///|
test "up and down keep their column through shorter rows" {
  let editor = @editor.Editor(text="a long first line\nxy\nanother long line")
  ignore(edited(editor, width=30))
  editor.move_home()
  for _ in 0..<9 {
    editor.move_right()
  }
  inspect(
    edited(editor, width=30),
    content=(
      #|a long first line
      #|xy
      #|another long line
      #|         ^
    ),
  )
  assert_true(editor.move_up())
  inspect(
    edited(editor, width=30),
    content=(
      #|a long first line
      #|xy
      #|  ^
      #|another long line
    ),
  )
  assert_true(editor.move_up())
  inspect(
    edited(editor, width=30),
    content=(
      #|a long first line
      #|         ^
      #|xy
      #|another long line
    ),
  )
  // Already on the first row: nothing moves, and the caller is told.
  assert_true(!editor.move_up())
  assert_true(editor.move_down())
  assert_true(editor.move_down())
  inspect(
    edited(editor, width=30),
    content=(
      #|a long first line
      #|xy
      #|another long line
      #|         ^
    ),
  )
  assert_true(!editor.move_down())
}

///|
test "up and down move between the rows of one wrapped line" {
  let editor = @editor.Editor(text="abcdefghijklm")
  ignore(edited(editor, width=6))
  // Rows: "abcde", "fghij", "klm". The cursor starts after "m".
  assert_true(editor.move_up())
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|fghij
      #|   ^
      #|klm
    ),
  )
  assert_true(editor.move_up())
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|   ^
      #|fghij
      #|klm
    ),
  )
  editor.move_end()
  ignore(edited(editor, width=6))
  editor.move_left()
  editor.move_left()
  editor.move_left()
  ignore(edited(editor, width=6))
  editor.move_right()
  editor.move_right()
  editor.move_right()
  // From the end of "klm" (column 3), up lands in column 3 of "fghij".
  assert_true(editor.move_up())
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|fghij
      #|   ^
      #|klm
    ),
  )
}

///|
test "moving up onto a full wrapped row stays on that row" {
  let editor = @editor.Editor(text="abcdefghij\nxxxxx")
  // Rows: "abcde", "fghij", "xxxxx". The cursor starts at column 5.
  ignore(edited(editor, width=6))
  assert_true(editor.move_up())
  // "fghij" ends at a line break, so its end is a place of its own.
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|fghij
      #|     ^
      #|xxxxx
    ),
  )
  assert_true(editor.move_up())
  // The end of "abcde" is where "fghij" starts and where the cursor would be
  // shown, so it stops one glyph short instead of appearing not to move.
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|    ^
      #|fghij
      #|xxxxx
    ),
  )
  // Coming back down returns to column 5.
  assert_true(editor.move_down())
  assert_true(editor.move_down())
  inspect(
    edited(editor, width=6),
    content=(
      #|abcde
      #|fghij
      #|xxxxx
      #|     ^
    ),
  )
}

///|
test "the view scrolls to keep the cursor row visible" {
  let editor = @editor.Editor(text="one\ntwo\nthree\nfour\nfive")
  inspect(
    edited(editor, height=2),
    content=(
      #|four
      #|five
      #|    ^
    ),
  )
  for _ in 0..<3 {
    ignore(editor.move_up())
  }
  inspect(
    edited(editor, height=2),
    content=(
      #|two
      #|   ^
      #|three
    ),
  )
  ignore(editor.move_down())
  // Still in view: no scrolling.
  inspect(
    edited(editor, height=2),
    content=(
      #|two
      #|three
      #|    ^
    ),
  )
  ignore(editor.move_down())
  inspect(
    edited(editor, height=2),
    content=(
      #|three
      #|four
      #|    ^
    ),
  )
  // Deleting text scrolls back rather than leaving blank rows at the bottom.
  editor.set_text("one\ntwo")
  inspect(
    edited(editor, height=2),
    content=(
      #|one
      #|two
      #|   ^
    ),
  )
}

///|
test "inserted text keeps line breaks and drops other control characters" {
  let editor = @editor.Editor()
  editor.insert("a\r\nb\rc\td\u{1b}[0me")
  inspect(
    editor.text(),
    content=(
      #|a
      #|b
      #|c    d[0me
    ),
  )
  inspect(
    edited(editor, width=20),
    content=(
      #|a
      #|b
      #|c    d[0me
      #|          ^
    ),
  )
}

///|
test "set_text and clear replace the text" {
  let editor = @editor.Editor(text="old text")
  editor.move_home()
  editor.set_text("new")
  inspect(
    edited(editor),
    content=(
      #|new
      #|   ^
    ),
  )
  editor.clear()
  assert_true(editor.is_empty())
  inspect(
    edited(editor),
    content=(
      #|
      #|^
    ),
  )
}

///|
test "key bindings" {
  let editor = @editor.Editor(text="hello world")
  assert_true(editor.key(key(Char('a'), ctrl=true)))
  assert_true(editor.key(key(Right)))
  assert_true(editor.key(key(Char('f'), ctrl=true)))
  inspect(
    edited(editor),
    content=(
      #|hello world
      #|  ^
    ),
  )
  assert_true(editor.key(key(Right, alt=true)))
  assert_true(editor.key(key(Char('f'), alt=true)))
  inspect(
    edited(editor),
    content=(
      #|hello world
      #|           ^
    ),
  )
  assert_true(editor.key(key(Char('b'), alt=true)))
  assert_true(editor.key(key(Char('k'), ctrl=true)))
  inspect(
    edited(editor),
    content=(
      #|hello
      #|      ^
    ),
  )
  assert_true(editor.key(key(Backspace)))
  assert_true(editor.key(key(Char('w'), ctrl=true)))
  inspect(
    edited(editor),
    content=(
      #|
      #|^
    ),
  )
  assert_true(editor.key(typed("x")))
  assert_true(editor.key(key(Enter, shift=true)))
  assert_true(editor.key(key(Char('j'), ctrl=true)))
  assert_true(editor.key(typed("y")))
  inspect(
    editor.text(),
    content=(
      #|x
      #|
      #|y
    ),
  )
  assert_true(editor.key(key(Up)))
  assert_true(editor.key(key(Char('p'), ctrl=true)))
  assert_true(editor.key(key(End)))
  assert_true(editor.key(key(Char('u'), ctrl=true)))
  assert_true(editor.key(key(Delete)))
  inspect(
    editor.text(),
    content=(
      #|
      #|y
    ),
  )
}

///|
test "moving to the start and end of the whole text" {
  let editor = @editor.Editor(text="first\nsecond\nthird")
  editor.move_to_start()
  inspect(
    edited(editor),
    content=(
      #|first
      #|^
      #|second
      #|third
    ),
  )
  editor.move_to_end()
  inspect(
    edited(editor),
    content=(
      #|first
      #|second
      #|third
      #|     ^
    ),
  )
  assert_true(editor.key(key(Home, ctrl=true)))
  editor.insert(">")
  assert_true(editor.key(key(End, ctrl=true)))
  editor.insert("<")
  inspect(
    editor.text(),
    content=(
      #|>first
      #|second
      #|third<
    ),
  )
}

///|
test "keys the editor has no use for are reported unused" {
  let editor = @editor.Editor(text="ab")
  // Plain Enter is the application's to interpret.
  assert_true(!editor.key(key(Enter)))
  // Nothing to delete, nowhere to go.
  assert_true(!editor.key(key(Delete)))
  assert_true(!editor.key(key(Char('d'), ctrl=true)))
  assert_true(!editor.key(key(Up)))
  assert_true(!editor.key(key(Down)))
  editor.move_home()
  assert_true(!editor.key(key(Backspace)))
  assert_true(!editor.key(key(Char('h'), ctrl=true)))
  // Chords and keys without text.
  assert_true(!editor.key(key(Char('x'), ctrl=true)))
  assert_true(!editor.key(key(Char('x'), alt=true)))
  assert_true(!editor.key(key(F1)))
  assert_true(!editor.key(key(Escape)))
  assert_true(
    !editor.key(@input.KeyEvent::new(Char('a'), kind=Release, text="a")),
  )
  inspect(
    editor.text(),
    content=(
      #|ab
    ),
  )
}

///|
test "draw paints the visible rows into the area it is given" {
  let editor = @editor.Editor(text="one\ntwo\nthree")
  let frame = @tui.Frame(width=8, height=4)
  editor.draw(frame, @tui.Rect(row=1, col=2, width=5, height=2))
  inspect(
    frame.to_text(),
    content=(
      #|
      #|  thre
      #|  e
      #|
    ),
  )
  // Without focus the text is the same; only the cursor is left out, which a
  // frame's text does not show either way.
  let unfocused = @tui.Frame(width=8, height=4)
  editor.draw(
    unfocused,
    @tui.Rect(row=1, col=2, width=5, height=2),
    focused=false,
  )
  @debug.assert_eq(unfocused.to_text(), frame.to_text())
  // An area with no room draws nothing and does not fail.
  editor.draw(frame, @tui.Rect(row=0, col=0, width=0, height=0))
}
