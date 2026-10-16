///|
/// A read-only diff between two source snapshots. Alignment, hunk rows and
/// source line numbers are computed when the snapshots change, never on draw.
struct DiffView {
  mut original : String
  mut modified : String
  context : Int32
  mut unified : Array[UnifiedRow]
  mut split : Array[SplitRow]
  mut offset : Int32
  mut height : Int32
  mut count : Int32
  mut area : @tui.Rect
}

///|
pub fn DiffView::DiffView(
  original : String,
  modified : String,
  context~ : Int32 = 3,
) -> DiffView {
  let context = context.max(0)
  let (unified, split) = diff_rows(original, modified, context)
  {
    original,
    modified,
    context,
    unified,
    split,
    offset: 0,
    height: 0,
    count: 0,
    area: @tui.Rect(row=0, col=0, width=0, height=0),
  }
}

///|
/// Replace both snapshots and return to the top. Supplying identical snapshots
/// preserves the cached diff and scroll position.
pub fn DiffView::set_sources(
  self : DiffView,
  original : String,
  modified : String,
) -> Unit {
  if original == self.original && modified == self.modified {
    return
  }
  let (unified, split) = diff_rows(original, modified, self.context)
  self.original = original
  self.modified = modified
  self.unified = unified
  self.split = split
  self.offset = 0
  self.count = 0
}

///|
/// Scroll by displayed rows, clamped to the layout recorded by the last draw.
pub fn DiffView::scroll_by(self : DiffView, rows : Int32) -> Unit {
  self.offset = (self.offset + rows).clamp(
    min=0,
    max=(self.count - self.height).max(0),
  )
}

///|
/// First visible body row in the most recently drawn format.
pub fn DiffView::offset(self : DiffView) -> Int32 {
  self.offset
}

///|
/// Handle a wheel event inside the last drawn body, using tty's one-based
/// screen coordinates. Other events remain available to the caller.
pub fn DiffView::mouse(self : DiffView, event : @input.MouseEvent) -> Bool {
  let row = event.row - 1
  let col = event.col - 1
  guard row >= self.area.row &&
    row < self.area.row + self.area.height &&
    col >= self.area.col &&
    col < self.area.col + self.area.width else {
    return false
  }
  match event.kind {
    Scroll(Up) => self.scroll_by(-3)
    Scroll(Down) => self.scroll_by(3)
    _ => return false
  }
  true
}

///|
/// Handle read-only row/page navigation. Route keys here only while the diff
/// has focus. Editing keys and release events are returned unused.
pub fn DiffView::navigate(self : DiffView, event : @input.KeyEvent) -> Bool {
  if event.kind is Release {
    return false
  }
  match event.code {
    Up => self.scroll_by(-1)
    Down => self.scroll_by(1)
    PageUp => self.scroll_by(-(self.height - 1).max(1))
    PageDown => self.scroll_by((self.height - 1).max(1))
    Home => self.offset = 0
    End => self.offset = (self.count - self.height).max(0)
    _ => return false
  }
  true
}
