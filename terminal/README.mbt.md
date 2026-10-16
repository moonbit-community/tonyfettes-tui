# Embedded terminal screen

`moonbit-community/tui/terminal` embeds a VT terminal inside a `Frame` using
[`tonyfettes/ghostty`](https://github.com/tonyfettes/ghostty). It renders process
output, maintains scrollback, and encodes input according to the modes enabled
by the child application. The package supports the native backend.

The screen owns the emulator and parser. The caller owns the process transport:
a local PTY, a remote stream, or a replay of recorded output can all feed the
same interface. `moonbit-community/pty` is used only by the integration test.

## Feed output and paint a pane

```mbt check
///|
test "paint process output inside a larger frame" {
  let screen = @terminal.Screen(cols=20, rows=4)
  defer screen.close()
  screen.feed(b"\x1b[32mhello\x1b[0m\r\nworld")
  let frame = @tui.Frame(width=24, height=6)
  let pane = @tui.Rect(row=1, col=2, width=20, height=4)
  screen.draw(frame, pane)
  assert_true(frame.to_text().contains("hello"))
  assert_true(frame.to_text().contains("world"))
}
```

Feed raw bytes without decoding them first: incomplete UTF-8 and terminal
sequences remain buffered until the next chunk arrives. Call `resize` when the
pane changes size and update the transport's PTY dimensions as well. Dimensions
are clamped to 1–65535 cells. `draw` clips to the supplied rectangle; it does not
resize the screen. Pass `focused=false` to hide the child cursor in an inactive
pane.

## Send input and terminal replies

```mbt check
///|
test "input follows the child application's terminal modes" {
  let screen = @terminal.Screen(cols=20, rows=4)
  defer screen.close()
  screen.feed(b"\x1b[?1h\x1b[?2004h\x1b[?1004h")
  assert_eq(screen.key(@input.KeyEvent::new(Up)), b"\x1bOA")
  assert_eq(screen.paste("hello\n"), b"\x1b[200~hello\n\x1b[201~")
  assert_eq(screen.focus(true), b"\x1b[I")
  screen.feed(b"\x1b[2;4H\x1b[6n")
  assert_eq(screen.take_reply(), b"\x1b[2;4R")
  assert_eq(screen.take_reply(), b"")
}
```

Write the bytes from `key`, `mouse`, `paste`, `focus`, and `take_reply` to the
same transport input channel. Drain `take_reply` after feeding output so
applications waiting for cursor, size, or device reports can continue.

`mouse` expects zero-based coordinates relative to the pane. For a one-based
`tty/input.MouseEvent` and a zero-based pane rectangle, translate with
`row = event.row - 1 - pane.row` and `col = event.col - 1 - pane.col` before
calling it. Only forward events inside the pane. When child mouse reporting is
off, wheel events browse local scrollback; alternate-screen applications can
request wheel-to-cursor-key translation instead. `scroll` and
`scroll_to_bottom` also control local scrollback directly.

## Lifetime

Register `defer screen.close()` immediately after creating a screen and call
`close` once after its final output chunk. It finishes parser state and does not
close a PTY, stop a child process, or flush pending transport writes. Drain and
send any required replies before closing, and do not use the screen afterwards.
The caller also handles process cancellation and waits for process exit.

The renderer maps text and the TUI's available foreground/background, bold,
italic, underline, and reverse attributes. Graphics and attributes absent from
`Style` are not drawn.
