///|
/// Collect a short burst of wheel steps at the same pointer cell before a draw.
///
/// `as_mouse` classifies the caller's own event type. A non-wheel event, a change
/// of pointer cell, or different modifiers ends the batch. The first such event
/// is returned unchanged: process it after painting the wheel result, before
/// reading the queue again. This preserves hit testing for a following click.
///
/// Apply each returned step in order. Adding opposite scroll deltas loses the
/// clamping that happens when an intermediate step reaches a content boundary.
///
/// The reader has at most `window_ms` to deliver asynchronously decoded input,
/// and a batch contains at most `max_steps` (including `first`). A nonpositive
/// window disables collection; step limits below one behave as one. If `first`
/// is not a wheel event, it is returned alone without reading the queue.
/// Queue errors and cancellation propagate to the caller.
pub async fn[E] wheel_batch(
  first : @input.MouseEvent,
  events : @aqueue.Queue[E],
  as_mouse : (E) -> @input.MouseEvent?,
  window_ms~ : Int32 = 8,
  max_steps~ : Int32 = 32,
) -> (Array[@input.MouseEvent], E?) {
  let batch = [first]
  guard first.kind is Scroll(_) else { return (batch, None) }
  let deadline = @async.now() + window_ms.max(0).to_int64()
  while batch.length() < max_steps.max(1) {
    let remaining = deadline - @async.now()
    guard remaining > 0 else { break }
    let next = if events.try_get() is Some(event) {
      Some(event)
    } else {
      @async.with_timeout_opt(remaining.to_int(), () => events.get())
    }
    guard next is Some(event) else { break }
    if as_mouse(event) is Some(mouse) &&
      mouse.kind is Scroll(_) &&
      mouse.row == first.row &&
      mouse.col == first.col &&
      mouse.modifiers == first.modifiers {
      batch.push(mouse)
    } else {
      return (batch, Some(event))
    }
  }
  (batch, None)
}
