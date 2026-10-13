// A small text file editor: one `Editor` filling the screen between a tab bar
// and a status row, with line numbers, syntax highlighting for MoonBit, and
// the mouse.
//
//   moon run examples/text_editor -- examples/text_editor/main.mbt
//
// It is an example of the editor widget, not a tool to trust with files that
// matter: the widget keeps tabs as four spaces and drops other control
// characters, so saving such a file changes it.

///|
struct State {
  editor : @editor.Editor
  // The file being edited, if the editor was started with one.
  path : String?
  // The text as it was last read from or written to the file.
  mut saved : String
  // Shown in the bottom row until the next key press.
  mut message : String?
  // Ctrl+Q was just pressed with unsaved changes; pressing it again quits.
  mut confirm_quit : Bool
}

///|
fn State::modified(self : State) -> Bool {
  self.editor.text() != self.saved
}

///|
/// The file's name without its directories, for the tab.
fn file_name(path : String?) -> String {
  guard path is Some(path) else { return "untitled" }
  if path.rev_find("/") is Some(slash) {
    path[slash + 1:].to_owned()
  } else {
    path
  }
}

///|
/// The whole screen as a function of the state and the terminal size.
fn view(state : State, size : @tui.Size) -> @tui.Frame {
  let frame = @tui.Frame(width=size.width, height=size.height)
  guard! frame.area().split_rows([Fixed(1), Fill, Fixed(1), Fixed(1)])
    is [tabs, body, status, hints]
  // The tab bar: one tab for the open file, in the editor's own background so
  // it reads as attached to the text below it.
  let tab = @tui.Line([
    Span("  \{file_name(state.path)} ", style=tab_style),
    Span(if state.modified() { "● " } else { "  " }, style=modified_style),
  ])
  frame.fill(tabs, style=chrome_style)
  frame.line(tabs, tab)
  // The text. Everything about how it looks is passed to the widget, which
  // does the wrapping, the scrolling and the cursor.
  let language = language(state.path)
  state.editor.draw(
    frame,
    body,
    style=text_style,
    highlight?=language.map(language => language.1),
    line_numbers=line_number_style,
    current_line=current_line_style,
  )
  // The status row: what is open on the left, where the cursor is on the
  // right. The right side takes the columns it needs first, so on a narrow
  // terminal it is the path that gets cut.
  let (line, column) = state.editor.position()
  let lines = state.editor.text().split("\n").count()
  let right = @tui.Line::from_text(
    " \{language.map(language => language.0).unwrap_or("Plain Text")}   Ln \{line + 1}, Col \{column + 1}   \{lines} lines ",
    style=status_style,
  )
  let left = @tui.Line([
    Span(" EDIT ", style=badge_style),
    Span(" \{state.path.unwrap_or("no file")}", style=status_style),
  ])
  frame.fill(status, style=status_style)
  guard! status.split_cols([Fill, Fixed(right.width())])
    is [left_area, right_area]
  frame.line(left_area, left)
  frame.line(right_area, right)
  frame.fill(hints, style=chrome_style)
  frame.line(
    hints,
    @tui.Line::from_text(
      " " +
      state.message.unwrap_or(
        "Ctrl+S save · Ctrl+Q quit · click to move the cursor · wheel to scroll",
      ),
      style=chrome_style,
    ),
  )
  frame
}

///|
/// Write the text to the file and report the outcome in the bottom row.
async fn save(state : State) -> Unit {
  guard state.path is Some(path) else {
    state.message = Some("No file name: start the editor with a path to save.")
    return
  }
  let text = state.editor.text()
  @fs.write_file(path, text, create_mode=CreateOrTruncate) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      state.message = Some("Could not save \{path}: \{error}")
      return
    }
  }
  state.saved = text
  state.message = Some("Saved \{path}")
}

///|
/// Start a new line with the indentation of the one the cursor is on.
fn newline_keeping_indent(editor : @editor.Editor) -> Unit {
  let (line, _) = editor.position()
  let indent = StringBuilder()
  if editor.text().split("\n").drop(line).head() is Some(current) {
    for c in current {
      if c != ' ' {
        break
      }
      indent.write_char(c)
    }
  }
  editor.insert("\n" + indent.to_string())
}

///|
async fn main {
  let command = @argparse.Command(
    "text_editor",
    about="A small text editor, as an example of moonbit-community/tui.",
    positionals=[
      @argparse.PositionArg(
        "path",
        about="The file to edit. It is created on save if it does not exist.",
        num_args=@argparse.ValueRange(lower=0, upper=1),
      ),
    ],
  )
  let path = if command.parse().values.get("path") is Some([path, ..]) {
    Some(path)
  } else {
    None
  }
  let text = if path is Some(path) && @fs.exists(path) {
    @fs.read_file(path).text()
  } else {
    ""
  }
  let state = State::{
    editor: Editor(text~),
    path,
    saved: text,
    message: None,
    confirm_quit: false,
  }
  // A new editor has its cursor at the end; a file is read from the top.
  state.editor.move_to_start()
  @tui.with_terminal(mouse=true, terminal => {
    for ;; {
      terminal.draw(view(state, terminal.size()))
      match terminal.read_event() {
        Input(Key(key)) => {
          let confirmed = state.confirm_quit
          state.confirm_quit = false
          state.message = None
          match key.code {
            Char('q') if key.modifiers.ctrl() =>
              if confirmed || !state.modified() {
                break
              } else {
                state.confirm_quit = true
                state.message = Some(
                  "Unsaved changes. Press Ctrl+Q again to quit without saving.",
                )
              }
            Char('s') if key.modifiers.ctrl() => save(state)
            // The widget leaves a plain Enter to the application. In an input
            // box it would submit; here it is a line break.
            Enter => newline_keeping_indent(state.editor)
            Tab => state.editor.insert("  ")
            _ => ignore(state.editor.key(key))
          }
        }
        Input(Paste(text)) => state.editor.insert(text)
        // The wheel moves the cursor a few rows, and the view follows it.
        Input(Mouse({ kind: Scroll(Up), .. })) =>
          for _ in 0..<3 {
            ignore(state.editor.move_up())
          }
        Input(Mouse({ kind: Scroll(Down), .. })) =>
          for _ in 0..<3 {
            ignore(state.editor.move_down())
          }
        Input(Mouse(mouse)) => ignore(state.editor.mouse(mouse))
        // A resize needs nothing: the next turn draws at the new size.
        _ => ()
      }
    }
  })
}
