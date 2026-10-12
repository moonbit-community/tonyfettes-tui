///|
/// The terminal's size in columns and rows.
pub struct Size {
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub extend Size with Eq::{equal, not_equal}

///|
pub extend Size with @debug.Debug::{to_repr}

///|
/// A full-screen terminal session.
///
/// A `Terminal` exists only inside `with_terminal`. Draw complete frames to it
/// with `draw` and read what the user did with `read_event`.
struct Terminal {
  tty : @tty.Tty
  mut size : Size
  // The frame currently on screen, or `None` when the screen content is
  // unknown (before the first draw and after a resize).
  mut shown : Frame?
}

///|
/// Run `f` with the terminal in full-screen mode, and restore it afterwards
/// whether `f` returns, raises, or is cancelled.
///
/// Opens the controlling terminal, switches to raw mode and the alternate
/// screen, requests the kitty keyboard "disambiguate" level, and enables
/// bracketed paste. Raises if the process has no terminal.
///
/// With `mouse`, clicks, drags, and the scroll wheel arrive as `Mouse` events
/// from `read_event`. The terminal then stops handling the mouse itself, so
/// its own text selection no longer works while the session runs; use a
/// `Selection` to provide one.
pub async fn[T] with_terminal(
  mouse~ : Bool = false,
  f : async (Terminal) -> T,
) -> T {
  let tty = @tty.Tty::open()
  defer tty.close()
  let window = tty.window_size()
  let terminal = Terminal::{
    tty,
    size: { width: window.cols, height: window.rows, },
    shown: None,
  }
  let keyboard = @tty.KeyboardEnhancementFlags::disambiguate()
  tty.with_raw_mode(() => {
    tty.with_alt_screen(() => {
      tty.with_keyboard_enhancements(keyboard, () => {
        tty.with_bracketed_paste(() => {
          tty.hide_cursor()
          defer @async.protect_from_cancel(() => {
            tty.execute([ResetStyle, ShowCursor])
          })
          if mouse {
            tty.with_mouse(Drag, () => f(terminal))
          } else {
            f(terminal)
          }
        })
      })
    })
  })
}

///|
/// The terminal's current size. It changes when `read_event` returns a
/// `Resize` event.
pub fn Terminal::size(self : Terminal) -> Size {
  self.size
}

///|
/// Make the screen show `frame`.
///
/// Only the cells that differ from the frame already on screen are sent to the
/// terminal, in one write. A frame larger than the terminal is clipped. `frame`
/// is copied, so it can be reused or dropped after the call.
pub async fn Terminal::draw(self : Terminal, frame : Frame) -> Unit {
  let frame = frame.clipped(width=self.size.width, height=self.size.height)
  let commands = diff(self.shown, frame)
  self.shown = Some(frame)
  if commands.is_empty() {
    return
  }
  self.tty.execute([BeginSynchronizedUpdate, ..commands, EndSynchronizedUpdate])
}

///|
/// Wait for the next terminal event: a key, a paste, a resize, or, when the
/// session was started with `mouse`, a mouse action.
///
/// After a `Resize` event `size` reports the new size, and the next `draw`
/// repaints the whole screen.
pub async fn Terminal::read_event(self : Terminal) -> @tty.Event {
  let event = self.tty.read_event()
  if event is Resize(window) {
    self.size = { width: window.cols, height: window.rows, }
    self.shown = None
  }
  event
}

///|
/// Put `text` on the system clipboard, replacing what was there.
///
/// This asks the terminal to do it (OSC 52), so it also works over SSH.
/// Terminals that do not support the request, or have clipboard access turned
/// off, ignore it, and there is no way to tell whether it worked.
pub async fn Terminal::set_clipboard(
  self : Terminal,
  text : StringView,
) -> Unit {
  self.tty.set_clipboard(text)
}
