///|
test "unmatched Ghostty drag is pointer motion, real button gestures stay intact" {
  let state = MouseState()
  let modifiers = @input.KeyModifiers::new(ctrl=true)
  fn mouse(kind : @input.MouseEventKind) -> @tty.Event {
    Input(Mouse(@input.MouseEvent::new(kind, 7, 156, modifiers~)))
  }
  // Replay the user's no-button motion: SGR 34 decodes to Drag(Right).
  assert_eq(state.event(mouse(Drag(Right))), mouse(Move))
  let buttons : Array[@input.MouseButton] = [Left, Middle, Right]
  for button in buttons {
    assert_eq(state.event(mouse(Press(button))), mouse(Press(button)))
    assert_eq(state.event(mouse(Drag(button))), mouse(Drag(button)))
    assert_eq(state.event(mouse(Release(button))), mouse(Release(button)))
    assert_eq(state.event(mouse(Drag(button))), mouse(Move))
  }
  // Buttons are tracked independently; releasing one must not cancel another.
  ignore(state.event(mouse(Press(Left))))
  ignore(state.event(mouse(Press(Right))))
  ignore(state.event(mouse(Release(Right))))
  assert_eq(state.event(mouse(Drag(Left))), mouse(Drag(Left)))
  ignore(state.event(Input(FocusOut)))
  assert_eq(state.event(mouse(Drag(Left))), mouse(Move))
  ignore(state.event(mouse(Press(Left))))
  ignore(state.event(mouse(Move)))
  assert_eq(state.event(mouse(Drag(Left))), mouse(Move))
}
