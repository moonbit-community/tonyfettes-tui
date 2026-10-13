///|
/// Everything the screen shows is derived from this.
struct State {
  editor : @editor.Editor
  submitted : Array[String]
  // Where the submitted lines are scrolled to. It follows new lines until the
  // user scrolls up.
  scroll : @tui.Scroll
  // The mouse selection over the submitted lines.
  selection : @tui.Selection
  // Shown on the right of the bottom row until the next key press.
  mut notice : String
}

///|
/// The whole screen as a function of the state and the terminal size.
fn view(state : State, size : @tui.Size) -> @tui.Frame {
  let frame = @tui.Frame(width=size.width, height=size.height)
  let dim = @tui.Style(fg=Basic(BrightBlack))
  let title = @tui.Style(fg=Basic(Cyan), bold=true)
  // The input grows with what is typed, up to four rows. Its height has to be
  // known before the screen is split, so measure it at the width it will get.
  let marker = @tui.Line::from_text("> ", style=dim)
  let editor_rows = state.editor.height(
    width=size.width - marker.width(),
    max=4,
  )
  let rows = @tui.Layout::vertical([
    Length(1),
    Length(1),
    Fill(1),
    Length(editor_rows),
    Length(1),
  ])
  guard! rows.split(frame.area()) is [header, _, body, prompt, footer]
  // The size label takes the columns it needs; the title gets the rest and is
  // cut off rather than overlapping when the terminal is narrow.
  let size_label = @tui.Line::from_text(
    " \{size.width}x\{size.height}",
    style=dim,
  )
  let columns = @tui.Layout::horizontal([Fill(1), Length(size_label.width())])
  guard! columns.split(header) is [title_area, size_area]
  frame.line(
    title_area,
    @tui.Line::from_text("moonbit-community/tui", style=title),
  )
  frame.line(size_area, size_label)
  // Wrap what was submitted to the body's width; the body is a scrolling
  // window onto the result.
  let history : Array[@tui.Line] = []
  for text in state.submitted {
    for line in text.split("\n") {
      history.append(@tui.Line::from_text(line).wrap(body.width))
    }
  }
  frame.lines(body, history, scroll=state.scroll, selection=state.selection)
  let columns = @tui.Layout::horizontal([Length(marker.width()), Fill(1)])
  guard! columns.split(prompt) is [marker_area, editor_area]
  frame.line(marker_area, marker)
  state.editor.draw(frame, editor_area)
  // The hint on the right takes its columns first, so the help text is cut
  // off rather than overlapped on a narrow terminal.
  let more = if state.notice != "" {
    " " + state.notice
  } else if state.scroll.at_bottom() {
    ""
  } else {
    " ↓ 下面还有"
  }
  let more = @tui.Line::from_text(more, style=dim)
  let columns = @tui.Layout::horizontal([Fill(1), Length(more.width())])
  guard! columns.split(footer) is [help, more_area]
  frame.line(
    help,
    @tui.Line::from_text(
      "Enter 提交 · Shift+Enter 换行 · PgUp/PgDn 滚动 · 拖动复制 · Esc 退出",
      style=dim,
    ),
  )
  frame.line(more_area, more)
  frame
}

///|
async fn main {
  @tui.with_terminal(mouse=true, terminal => {
    let state = State::{
      editor: Editor(),
      submitted: [],
      scroll: Scroll(stick_to_bottom=true),
      selection: Selection(),
      notice: "",
    }
    for ;; {
      terminal.draw(view(state, terminal.size()))
      match terminal.read_event() {
        Input(Key(key)) => {
          state.notice = ""
          match key.code {
            Escape => break
            Char('c') if key.modifiers.ctrl() => break
            PageUp => state.scroll.page_up()
            PageDown => state.scroll.page_down()
            // Everything else goes to the editor first. It leaves a plain
            // Enter alone, which is what submits.
            _ =>
              if !state.editor.key(key) &&
                key.code is Enter &&
                !state.editor.is_empty() {
                state.submitted.push(state.editor.text())
                state.editor.clear()
                state.scroll.to_bottom()
              }
          }
        }
        Input(Paste(text)) => state.editor.insert(text)
        Input(Mouse({ kind: Scroll(Up), .. })) => state.scroll.scroll_by(-3)
        Input(Mouse({ kind: Scroll(Down), .. })) => state.scroll.scroll_by(3)
        Input(Mouse(mouse)) => {
          state.selection.mouse(mouse)
          // Copy as soon as the button is released, like a terminal that
          // copies on select.
          if mouse.kind is Release(Left) && state.selection.text() is Some(text) {
            terminal.set_clipboard(text)
            state.notice = "已复制 \{text.char_length()} 个字符"
          }
        }
        _ => ()
      }
    }
  })
}
