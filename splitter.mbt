///|
/// The arrangement of two panes: side by side, or top to bottom.
pub(all) enum Axis {
  Horizontal
  Vertical
} derive(Eq, Debug)

///|
/// A two-pane split with a one-cell divider and captured left-button dragging.
/// Position is the size of the first pane, in terminal cells. Applications own
/// pane contents and should dispatch mouse events here before other widgets.
struct Splitter {
  axis : Axis
  min_first : Int32
  min_second : Int32
  max_first : Int32?
  mut position : Int32
  mut bounds : Rect
  mut divider : Rect
  mut dragging : Bool
}

///|
/// Negative constraints become zero. When both minima cannot fit, the first
/// pane's minimum takes priority, limited by the total available space.
pub fn Splitter::Splitter(
  axis~ : Axis,
  position~ : Int32,
  min_first~ : Int32 = 0,
  min_second~ : Int32 = 0,
  max_first? : Int32,
) -> Splitter {
  {
    axis,
    position,
    min_first: min_first.max(0),
    min_second: min_second.max(0),
    max_first,
    bounds: Rect(row=0, col=0, width=0, height=0),
    divider: Rect(row=0, col=0, width=0, height=0),
    dragging: false,
  }
}

///|
pub fn Splitter::position(self : Splitter) -> Int32 {
  self.position
}

///|
pub fn Splitter::dragging(self : Splitter) -> Bool {
  self.dragging
}

///|
/// Cancel a captured gesture on focus loss or when hiding the split.
pub fn Splitter::cancel(self : Splitter) -> Unit {
  self.dragging = false
}

///|
fn Splitter::clamp_position(self : Splitter, position : Int32) -> Int32 {
  let available = ((if self.axis is Horizontal {
    self.bounds.width
  } else {
    self.bounds.height
  }) -
  1).max(0)
  let lower = self.min_first.min(available)
  let upper = (available - self.min_second)
    .min(self.max_first.unwrap_or(available))
    .clamp(min=lower, max=available)
  position.clamp(min=lower, max=upper)
}

///|
/// Paint the divider and return the first and second pane areas. The bounds
/// are clipped to the frame. A bounds change cancels any captured gesture;
/// drawing also clamps the stored position after terminal resize.
pub fn Splitter::draw(
  self : Splitter,
  frame : Frame,
  bounds : Rect,
  style~ : Style = Style(),
  active_style~ : Style = style,
) -> (Rect, Rect) {
  let bounds = bounds.intersect(frame.area())
  if self.bounds != bounds {
    self.cancel()
  }
  self.bounds = bounds
  self.position = self.clamp_position(self.position)
  let position = self.position
  let (first, divider, second) = if self.axis is Horizontal {
    let divider_width = bounds.width.min(1)
    (
      Rect(row=bounds.row, col=bounds.col, width=position, height=bounds.height),
      Rect(
        row=bounds.row,
        col=bounds.col + position,
        width=divider_width,
        height=bounds.height,
      ),
      Rect(
        row=bounds.row,
        col=bounds.col + position + divider_width,
        width=bounds.width - position - divider_width,
        height=bounds.height,
      ),
    )
  } else {
    let divider_height = bounds.height.min(1)
    (
      Rect(row=bounds.row, col=bounds.col, width=bounds.width, height=position),
      Rect(
        row=bounds.row + position,
        col=bounds.col,
        width=bounds.width,
        height=divider_height,
      ),
      Rect(
        row=bounds.row + position + divider_height,
        col=bounds.col,
        width=bounds.width,
        height=bounds.height - position - divider_height,
      ),
    )
  }
  self.divider = divider
  let style = if self.dragging { active_style } else { style }
  frame.fill(divider, style~)
  if self.axis is Horizontal {
    for row in divider.row..<(divider.row + divider.height) {
      frame.line(
        Rect(row~, col=divider.col, width=divider.width, height=1),
        Line::from_text("│", style~),
      )
    }
  } else {
    frame.line(divider, Line::from_text("─".repeat(divider.width), style~))
  }
  (first, second)
}

///|
/// Use 1-based terminal mouse coordinates. Once a divider press is accepted,
/// consume the whole gesture, including movement outside its bounds, until
/// the matching release. Return true when the event was consumed.
pub fn Splitter::mouse(self : Splitter, event : @input.MouseEvent) -> Bool {
  if self.dragging && !(event.kind is Press(_)) {
    if event.kind is (Drag(Left) | Release(Left)) {
      let position = if self.axis is Horizontal {
        event.col - 1 - self.bounds.col
      } else {
        event.row - 1 - self.bounds.row
      }
      self.position = self.clamp_position(position)
    }
    if event.kind is Release(Left) {
      self.cancel()
    }
    return true
  }
  self.cancel()
  let row = event.row - 1
  let col = event.col - 1
  if event.kind is Press(Left) &&
    row >= self.divider.row &&
    row < self.divider.row + self.divider.height &&
    col >= self.divider.col &&
    col < self.divider.col + self.divider.width {
    self.dragging = true
    true
  } else {
    false
  }
}

///|
pub extend Axis with Eq::{equal, not_equal}

///|
pub extend Axis with @debug.Debug::{to_repr}
