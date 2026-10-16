///|
enum Event {
  Pointer(@input.MouseEvent)
  Key(String)
  Update
} derive(Eq, @debug.Debug)

///|
fn as_mouse(event : Event) -> @input.MouseEvent? {
  if event is Pointer(mouse) {
    Some(mouse)
  } else {
    None
  }
}

///|
async test "asynchronously decoded wheel steps share a frame and preserve a following key" {
  @async.with_task_group(group => {
    let events : @aqueue.Queue[Event] = Queue(kind=Blocking(8))
    let up = @input.MouseEvent::new(Scroll(Up), 10, 40)
    let down = @input.MouseEvent::new(Scroll(Down), 10, 40)
    group.spawn_bg(no_wait=true, () => {
      @async.pause()
      events.put(Pointer(down))
      @async.pause()
      events.put(Pointer(down))
      events.put(Key("after scroll"))
      events.put(Update)
    })
    let (steps, pending) = @events.wheel_batch(up, events, as_mouse)
    assert_eq(steps, [up, down, down])
    assert_eq(pending, Some(Key("after scroll")))
    assert_eq(events.get(), Update)
  })
}

///|
async test "different cells, pointer presses and application updates are returned intact" {
  let down = @input.MouseEvent::new(Scroll(Down), 10, 40)
  for
    boundary in [
      Event::Pointer(@input.MouseEvent::new(Scroll(Down), 10, 41)),
      Event::Pointer(@input.MouseEvent::new(Press(Left), 10, 40)),
      Event::Update,
    ] {
    let events : @aqueue.Queue[Event] = Queue(kind=Blocking(8))
    events.put(boundary)
    events.put(Key("tail"))
    let (steps, pending) = @events.wheel_batch(down, events, as_mouse)
    assert_eq(steps, [down])
    assert_eq(pending, Some(boundary))
    assert_eq(events.get(), Key("tail"))
  }
}

///|
async test "a sustained stream has a step bound and an idle reader has a time bound" {
  let events : @aqueue.Queue[Event] = Queue(kind=Blocking(8))
  let wheel = @input.MouseEvent::new(Scroll(Down), 10, 40)
  for _ in 0..<4 {
    events.put(Pointer(wheel))
  }
  let (steps, pending) = @events.wheel_batch(
    wheel,
    events,
    as_mouse,
    max_steps=3,
  )
  assert_eq(steps.length(), 3)
  assert_true(pending is None)
  assert_eq(events.get(), Pointer(wheel))
  assert_eq(events.get(), Pointer(wheel))
  let (idle, pending) = @async.with_timeout(500, () => {
    @events.wheel_batch(wheel, events, as_mouse, window_ms=1)
  })
  assert_eq(idle, [wheel])
  assert_true(pending is None)
}

///|
async test "disabled batching and a non-wheel first event do not consume input" {
  let events : @aqueue.Queue[Event] = Queue(kind=Blocking(8))
  let wheel = @input.MouseEvent::new(Scroll(Down), 10, 40)
  events.put(Update)
  let (steps, _) = @events.wheel_batch(wheel, events, as_mouse, window_ms=0)
  assert_eq(steps, [wheel])
  let press = @input.MouseEvent::new(Press(Left), 10, 40)
  let (steps, _) = @events.wheel_batch(press, events, as_mouse)
  assert_eq(steps, [press])
  assert_eq(events.get(), Update)
}
