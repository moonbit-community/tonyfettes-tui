# moonbit-community/tui

An immediate-mode terminal UI library for MoonBit native targets, built on
[`moonbit-community/tty`](https://github.com/moonbit-community/tty).

> Early work in progress. The API is small and will change.

## The model

The screen is a function of your state. Each time something changes you paint
one complete `Frame` and hand it to the terminal; the library compares it with
the frame already on screen and sends only the cells that differ.

- A `Frame` is a grid of styled cells that starts blank.
- You lay it out top-down: split the frame's area into smaller areas, then
  paint a `Line` into each. You never compute a column by hand.
- The loop is yours: read an event, update your state, draw. There are no
  callbacks, message types, or widget trees.
- A `Terminal` is a full-screen session. It owns raw mode, the alternate
  screen, and restoring the terminal when your code returns, raises, or is
  cancelled.

```moonbit
///|
struct State {
  mut count : Int
}

///|
fn view(state : State, size : @tui.Size) -> @tui.Frame {
  let frame = @tui.Frame(width=size.width, height=size.height)
  let dim = @tui.Style(fg=Basic(BrightBlack))
  // Two rows at the top; the rest of the screen stays blank.
  guard! frame.area().split_rows([Fixed(1), Fixed(1), Fill]) is [count, help, _]
  frame.line(count, @tui.Line([Span("count: "), Span("\{state.count}")]))
  frame.line(help, @tui.Line::from_text("space: +1 · Esc: quit", style=dim))
  frame
}

///|
async fn main {
  @tui.with_terminal(terminal => {
    let state = State::{ count: 0, }
    for ;; {
      terminal.draw(view(state, terminal.size()))
      match terminal.read_event() {
        Input(Key(key)) =>
          match key.code {
            Escape => break
            Char(' ') => state.count += 1
            _ => ()
          }
        // A resize needs nothing special: the next turn paints a frame of
        // the new size.
        _ => ()
      }
    }
  })
}
```

`view` never touches the terminal, so it can be tested directly:
`view(state, size).to_text()` returns what the screen would show.

## Layout

There are two layers, and neither involves coordinates.

**Areas** say where things go. `frame.area()` is the whole frame;
`split_rows` and `split_cols` cut an area into pieces that are either
`Fixed(n)` or `Fill` (an equal share of what is left). Destructure the result
to name the pieces:

```moonbit
guard! frame.area().split_rows([Fixed(1), Fill, Fixed(1)])
  is [header, body, footer]
guard! header.split_cols([Fill, Fixed(8)]) is [title, clock]
```

A split always returns one area per length, so the pattern matches as long as
it lists the same number of names. `guard!` panics if it does not; write
`guard ... is [...] else { ... }` to handle that case instead.

**Lines** say what goes there. A `Line` is a row of `Span`s, each with its own
style. A line knows its `width()` in display columns and can `wrap(width)`
itself into several lines.

```moonbit
let prompt = @tui.Line([Span("> ", style=dim), Span(input)])
frame.line(area, prompt)                    // clipped to the area
frame.line(area, status, align=Right)
frame.lines(body, long_line.wrap(body.width))
frame.set_cursor(area, col=prompt.width())  // relative to the area
```

Painting is clipped to the area it is given, so a line that is too long is cut
off instead of spilling into its neighbour.

## What is here

- `Style`: foreground, background, bold, italic, underline, reverse.
- `Span`, `Line`: styled text with `width`, `wrap`, and `to_text`. Text is
  measured in display columns, so CJK and other wide graphemes take two cells.
  Wrapping breaks at spaces, and anywhere for text without spaces.
- `Rect`, `Length`: areas and `split_rows` / `split_cols`.
- `Frame`: `area`, `line`, `lines`, `fill`, `set_cursor`, `to_text`, and `text`
  for painting at an exact cell. Control characters never become cell content.
- `with_terminal`, `Terminal::size`, `Terminal::draw`, `Terminal::read_event`.
  Each draw is one write, wrapped in a synchronized update.

Run the examples:

```sh
moon run examples/counter   # the snippet above
moon run examples/hello     # text input, wrapping, wide characters, resize
```

## What is not here yet

- Scrolling views over content longer than the screen.
- Mouse input, text selection, and copy to the clipboard.
- Widgets such as a text editor.
- Padding, borders, and constraint-based layout. Areas only split into fixed
  and fill pieces.
- An inline (non-full-screen) mode. Full-screen is the only mode.

## Development

The library uses `tty` APIs that are merged but not yet published
(`Command` deriving `Eq`/`Debug`, cursor save/restore, clipboard write). Until
`tty` 0.5.0 is released, `moon.work` builds against a local checkout:

```sh
git clone --depth 1 https://github.com/moonbit-community/tty.git .deps/tty
```

`.deps/` is ignored by git. Once the release is out, bump the `tty` version in
`moon.mod` and delete `moon.work`.

```sh
moon fmt
moon check --deny-warn
moon test .
moon info
```

`moon test` without the `.` also runs the tests of the `tty` checkout.
