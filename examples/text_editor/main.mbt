// A small text file editor: one `Editor` filling the screen between a title
// bar and a status row.
//
//   moon run examples/text_editor -- notes.txt
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
  // Shown in the status row until the next key press.
  mut message : String?
  // Ctrl+Q was just pressed with unsaved changes; pressing it again quits.
  mut confirm_quit : Bool
}

///|
fn State::modified(self : State) -> Bool {
  self.editor.text() != self.saved
}

///|
/// The whole screen as a function of the state and the terminal size.
fn view(state : State, size : @tui.Size) -> @tui.Frame {
  let frame = @tui.Frame(width=size.width, height=size.height)
  let bar = @tui.Style(reverse=true)
  let dim = @tui.Style(fg=Basic(BrightBlack))
  guard! frame.area().split_rows([Fixed(1), Fill, Fixed(1)])
    is [title, body, status]
  // Fill first so the bar spans the full width, then write the name over it.
  frame.fill(title, style=bar)
  let name = state.path.unwrap_or("[no file]")
  let mark = if state.modified() { " (modified)" } else { "" }
  frame.line(title, @tui.Line::from_text(" \{name}\{mark}", style=bar))
  state.editor.draw(frame, body)
  frame.line(
    status,
    @tui.Line::from_text(
      state.message.unwrap_or("Ctrl+S save · Ctrl+Q quit"),
      style=dim,
    ),
  )
  frame
}

///|
/// Write the text to the file and report the outcome in the status row.
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
  @tui.with_terminal(terminal => {
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
            // box it would submit; here it is just a line break.
            Enter => state.editor.insert("\n")
            _ => ignore(state.editor.key(key))
          }
        }
        Input(Paste(text)) => state.editor.insert(text)
        // A resize needs nothing: the next turn draws at the new size.
        _ => ()
      }
    }
  })
}
