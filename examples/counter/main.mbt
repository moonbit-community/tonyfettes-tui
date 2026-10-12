///|
struct State {
  mut count : Int32
}

///|
fn view(state : State, size : @tui.Size) -> @tui.Frame {
  let frame = @tui.Frame(width=size.width, height=size.height)
  let dim = @tui.Style(fg=Basic(BrightBlack))
  // Two rows at the top; the rest of the screen stays blank.
  guard! frame.area().split_rows([Fixed(1), Fixed(1), Fill]) is [count, help, _]
  frame.line(count, @tui.Line([Span("count: "), Span("\{state.count}")]))
  frame.line(help, @tui.Line::from_text("space: +1 · Esc: quit", style=dim))
  frame
}

///|
async fn main {
  @tui.with_terminal(terminal => {
    let state = State::{ count: 0, }
    for ;; {
      terminal.draw(view(state, terminal.size()))
      match terminal.read_event() {
        Input(Key(key)) =>
          match key.code {
            Escape => break
            Char(' ') => state.count += 1
            _ => ()
          }
        // A resize needs nothing special: the next turn paints a frame of
        // the new size.
        _ => ()
      }
    }
  })
}
