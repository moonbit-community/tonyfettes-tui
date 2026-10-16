///|
/// The scroll position of a list of lines that may be longer than the area
/// showing it.
///
/// Keep one `Scroll` in your state per scrollable region, pass it to
/// `Frame::lines` when drawing, and move it from your event handling. Drawing
/// records how many lines there are and how tall the area is, so the position
/// always stays within the content and `page_up`/`page_down` know what a page
/// is.
struct Scroll {
  stick_to_bottom : Bool
  mut hold_position : Bool
  // Index of the first visible line.
  mut offset : Int32
  // The largest valid offset and the area height, as of the last draw.
  mut max_offset : Int32
  mut height : Int32
}

///|
/// Build a scroll position at the top.
///
/// With `stick_to_bottom`, the view starts at the end and stays there as
/// lines are added, until the user scrolls up; scrolling back to the end
/// resumes following. This is the behaviour a chat log or a live output wants.
pub fn Scroll::Scroll(stick_to_bottom~ : Bool = false) -> Scroll {
  {
    stick_to_bottom,
    hold_position: false,
    offset: 0,
    max_offset: 0,
    height: 0,
  }
}

///|
/// Record the content and area sizes of this draw, bring the position within
/// range, and return the index of the first visible line.
fn Scroll::fit(self : Scroll, content~ : Int32, height~ : Int32) -> Int32 {
  let max_offset = (content - height).max(0)
  // At the end before this draw means following the content as it grows.
  if self.stick_to_bottom &&
    !self.hold_position &&
    self.offset >= self.max_offset {
    self.offset = max_offset
  }
  self.offset = self.offset.clamp(min=0, max=max_offset)
  self.hold_position = false
  self.max_offset = max_offset
  self.height = height
  self.offset
}

///|
/// Scroll by `rows` lines: positive moves down, towards the end; negative
/// moves up. The position stops at either end.
pub fn Scroll::scroll_by(self : Scroll, rows : Int32) -> Unit {
  self.offset = (self.offset + rows).clamp(min=0, max=self.max_offset)
}

///|
/// A page is the area's height less one line, so a line of context carries
/// over between pages.
fn Scroll::page(self : Scroll) -> Int32 {
  (self.height - 1).max(1)
}

///|
/// Scroll up by one page.
pub fn Scroll::page_up(self : Scroll) -> Unit {
  self.scroll_by(-self.page())
}

///|
/// Scroll down by one page.
pub fn Scroll::page_down(self : Scroll) -> Unit {
  self.scroll_by(self.page())
}

///|
/// Scroll to the first line.
pub fn Scroll::to_top(self : Scroll) -> Unit {
  self.offset = 0
}

///|
/// Scroll to the last line.
pub fn Scroll::to_bottom(self : Scroll) -> Unit {
  self.offset = self.max_offset
}

///|
/// The index of the first visible line, as of the last draw or scroll.
pub fn Scroll::offset(self : Scroll) -> Int32 {
  self.offset
}

///|
/// Whether the last line is visible, as of the last draw or scroll. Useful for
/// showing a "more below" hint.
pub fn Scroll::at_bottom(self : Scroll) -> Bool {
  self.offset >= self.max_offset
}

///|
/// Preserve the current position on the next draw when expanding or folding
/// content in place. Later draws can resume following the bottom as usual.
pub fn Scroll::hold(self : Scroll) -> Unit {
  self.hold_position = true
}
