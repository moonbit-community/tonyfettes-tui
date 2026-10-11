///|
/// Everything the screen shows is derived from this.
struct State {
  input : Array[Char]
  submitted : Array[String]
}

///|
/// The whole screen as a function of the state and the terminal size.
fn view(state : State, size : @tui.Size) -> @tui.Frame {
  let frame = @tui.Frame(width=size.width, height=size.height)
  let dim = @tui.Style(fg=Basic(BrightBlack))
  let title = @tui.Style(fg=Basic(Cyan), bold=true)
  guard! frame.area().split_rows([Fixed(1), Fixed(1), Fill, Fixed(1), Fixed(1)])
    is [header, _, body, prompt, footer]
  // The size label takes the columns it needs; the title gets the rest and is
  // cut off rather than overlapping when the terminal is narrow.
  let size_label = @tui.Line::from_text(
    " \{size.width}x\{size.height}",
    style=dim,
  )
  guard! header.split_cols([Fill, Fixed(size_label.width())])
    is [title_area, size_area]
  frame.line(
    title_area,
    @tui.Line::from_text("moonbit-community/tui", style=title),
  )
  frame.line(size_area, size_label)
  // Wrap what was submitted to the body's width and show the tail that fits.
  let history : Array[@tui.Line] = []
  for text in state.submitted {
    history.append(@tui.Line::from_text(text).wrap(body.width))
  }
  let first = (history.length() - body.height).max(0)
  frame.lines(body, history[first:])
  let input = @tui.Line([
    Span("> ", style=dim),
    Span(String::from_array(state.input)),
  ])
  frame.line(prompt, input)
  frame.set_cursor(prompt, col=input.width())
  frame.line(
    footer,
    @tui.Line::from_text("Enter 提交 · Esc 退出", style=dim),
  )
  frame
}

///|
async fn main {
  @tui.with_terminal(terminal => {
    let state = State::{ input: [], submitted: [], }
    for ;; {
      terminal.draw(view(state, terminal.size()))
      match terminal.read_event() {
        Input(Key(key)) =>
          match key.code {
            Escape => break
            Char('c') if key.modifiers.ctrl() => break
            Enter => {
              state.submitted.push(String::from_array(state.input))
              state.input.clear()
            }
            // Good enough for a demo: drops one code point, not one grapheme.
            Backspace => ignore(state.input.pop())
            _ =>
              if key.text is Some(text) {
                state.input.append(text.to_array())
              }
          }
        Input(Paste(text)) => state.input.append(text.to_array())
        _ => ()
      }
    }
  })
}
