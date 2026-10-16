///|
test "file editors preserve exact source text across load and edits" {
  let source = "\tfn main {\r\n\t  println(\"你好\")\r\n}\r\n"
  let editor = @editor.Editor(text=source, preserve_text=true)
  assert_eq(editor.text(), source)
  editor.insert("\tmore\r\n")
  assert_eq(editor.text(), source + "\tmore\r\n")
  editor.set_text(source)
  let frame = @tui.Frame(width=40, height=5)
  editor.draw(frame, frame.area())
  assert_eq(editor.text(), source)
  assert_true(frame.to_text().contains("fn main"))
}

///|
test "source CRLF is one editable line break" {
  let editor = @editor.Editor(text="first\r\nsecond", preserve_text=true)
  editor.move_home()
  assert_eq(editor.position(), (1, 0))
  editor.delete_before()
  assert_eq(editor.text(), "firstsecond")
  editor.set_text("first\r\nsecond")
  editor.move_to_start()
  editor.move_end()
  editor.delete_after()
  assert_eq(editor.text(), "firstsecond")
}

///|
test "edits that form CRLF keep the resulting line break atomic" {
  let editor = @editor.Editor(text="first\nsecond", preserve_text=true)
  editor.move_to_start()
  editor.move_end()
  editor.insert("\r")
  assert_eq(editor.text(), "first\r\nsecond")
  editor.goto_source(line=1, character=0)
  editor.delete_before()
  assert_eq(editor.text(), "firstsecond")
  editor.set_text("first\rsecond")
  editor.goto_source(line=0, character=6)
  editor.insert("\n")
  assert_eq(editor.text(), "first\r\nsecond")
  editor.goto_source(line=1, character=0)
  editor.delete_before()
  assert_eq(editor.text(), "firstsecond")
}
