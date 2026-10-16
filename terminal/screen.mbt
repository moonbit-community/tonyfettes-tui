///|
/// A failure to resize the terminal emulator.
pub suberror ScreenError {
  ResizeFailed(Int32)
}

///|
/// An embeddable VT terminal screen. Feed process output, draw into a frame,
/// and send encoded input and terminal replies to the process transport.
struct Screen {
  terminal : @vt.StreamTerminal
  render : @vt.RenderState
  keyboard : @key_encoder.KeyEncoder
  mouse_encoder : @mouse_encoder.MouseEncoder
  replies : Buffer
}

///|
/// Create a screen. Empty layout dimensions are treated as one cell.
pub fn Screen::Screen(cols~ : Int32, rows~ : Int32) -> Screen raise ScreenError {
  let replies = Buffer()
  let terminal = @vt.StreamTerminal::new(write_pty=bytes => {
    replies.write_bytes(bytes)
  })
  let screen : Screen = {
    terminal,
    render: @vt.RenderState::new(),
    keyboard: @key_encoder.KeyEncoder::new(),
    mouse_encoder: @mouse_encoder.MouseEncoder::new(),
    replies,
  }
  screen.resize(cols~, rows~)
  screen
}

///|
/// Update the grid after the containing terminal changes size. Return a typed
/// error if the emulator cannot allocate or accept the requested dimensions.
pub fn Screen::resize(
  self : Screen,
  cols~ : Int32,
  rows~ : Int32,
) -> Unit raise ScreenError {
  let cols = cols.clamp(min=1, max=65535)
  let rows = rows.clamp(min=1, max=65535)
  // Input coordinates use one virtual pixel per terminal cell. These arguments
  // are per-cell dimensions, not the total grid size.
  let code = self.terminal.resize(cols.to_uint16(), rows.to_uint16(), 1U, 1U)
  if code.code() != 0 {
    raise ResizeFailed(code.code())
  }
  self.terminal.set_size(() => {
    Some(@size_report.Size::new(rows.to_uint16(), cols.to_uint16(), 0U, 0U))
  })
  if @mouse_encoder.MouseEncoderSize::new(
      cols.reinterpret_as_uint(),
      rows.reinterpret_as_uint(),
      1U,
      1U,
    )
    is Some(size) {
    self.mouse_encoder.set_size(size)
  }
}

///|
/// The current terminal grid width.
pub fn Screen::cols(self : Screen) -> Int32 {
  self.terminal.columns().to_int()
}

///|
/// The current terminal grid height.
pub fn Screen::rows(self : Screen) -> Int32 {
  self.terminal.rows().to_int()
}

///|
/// Feed a chunk of PTY output. Partial UTF-8 and escape sequences are retained
/// by the emulator until the next chunk arrives.
pub fn Screen::feed(self : Screen, bytes : Bytes) -> Unit {
  self.terminal.next_slice(bytes)
}

///|
/// Drain responses to terminal queries such as cursor-position requests.
/// The caller sends the returned bytes through the same PTY input channel.
pub fn Screen::take_reply(self : Screen) -> Bytes {
  let bytes = self.replies.to_bytes()
  self.replies.reset()
  bytes
}

///|
/// The OSC window title supplied by the process, when present.
pub fn Screen::title(self : Screen) -> String? {
  self.terminal.title()
}

///|
/// Move through scrollback by rows; negative values move toward older output.
pub fn Screen::scroll(self : Screen, delta : Int32) -> Unit {
  self.terminal.scroll_viewport_delta(delta)
}

///|
/// Return to the live output viewport.
pub fn Screen::scroll_to_bottom(self : Screen) -> Unit {
  self.terminal.scroll_viewport_bottom()
}

///|
/// Finish parser state when detaching the screen. Call once after the final
/// output chunk, normally with `defer screen.close()`. This does not close the
/// process transport or stop a child process; those remain caller-owned.
/// Do not use the screen after closing it.
pub fn Screen::close(self : Screen) -> Unit {
  self.terminal.deinit()
}

///|
/// Paint the visible screen into an arbitrary frame rectangle. Cursor display
/// follows the child application's visibility mode and the pane's focus.
pub fn Screen::draw(
  self : Screen,
  frame : @tui.Frame,
  area : @tui.Rect,
  focused~ : Bool = true,
) -> Unit {
  self.render.update(self.terminal)
  let default_fg = rgb(self.render.foreground_color())
  let default_bg = rgb(self.render.background_color())
  let reversed = self.terminal.mode_get(ReverseColors)
  frame.fill(
    area,
    style=@tui.Style(fg=default_fg, bg=default_bg, reverse=reversed),
  )
  let rows = self.render.row_iterator()
  while rows.next() {
    guard rows.y() is Some(y) && y.to_int() < area.height else { continue }
    guard rows.cells() is Some(cells) else { continue }
    while cells.next() {
      guard cells.x() is Some(x) && x.to_int() < area.width else { continue }
      guard cells.cell() is Some(cell) else { continue }
      // A wide glyph is painted once at its leading cell. Painting a spacer
      // tail would erase that glyph in the frame's grapheme-aware grid.
      if cell.wide() is (@page.SpacerTail | @page.SpacerHead) {
        continue
      }
      let style = if cells.cell_style() is Some(style) {
        @tui.Style(
          fg=if style.invisible() {
            cells.background_color().map(rgb).unwrap_or(default_bg)
          } else {
            cells.foreground_color().map(rgb).unwrap_or(default_fg)
          },
          bg=cells.background_color().map(rgb).unwrap_or(default_bg),
          bold=style.bold(),
          italic=style.italic(),
          underline=style.underline() != @sgr.None,
          reverse=style.inverse() != reversed,
        )
      } else {
        @tui.Style(fg=default_fg, bg=default_bg, reverse=reversed)
      }
      let text = StringBuilder()
      if cell.has_text() {
        text.write_char(
          cell.codepoint().reinterpret_as_int().to_char().unwrap_or('\uFFFD'),
        )
        for cp in cells.cell_grapheme_codepoints() {
          text.write_char(cp.reinterpret_as_int().to_char().unwrap_or('\uFFFD'))
        }
      } else {
        text.write_char(' ')
      }
      frame.line(
        @tui.Rect(
          row=area.row + y.to_int(),
          col=area.col + x.to_int(),
          width=area.width - x.to_int(),
          height=1,
        ),
        @tui.Line::from_text(text.to_string(), style~),
      )
    }
  }
  if focused &&
    self.render.cursor_visible() &&
    self.render.cursor_viewport() is Some(cursor) {
    let y = cursor.y().reinterpret_as_int()
    let x = cursor.x().to_int()
    let row = area.row + y
    let col = area.col + x
    if y < area.height &&
      x < area.width &&
      row >= 0 &&
      row < frame.height() &&
      col >= 0 &&
      col < frame.width() {
      frame.set_cursor(frame.area(), row~, col~)
    }
  }
}

///|
fn rgb(color : @vt_color.RGB) -> @color.Color {
  @color.Rgb(color.r().to_int(), color.g().to_int(), color.b().to_int())
}
