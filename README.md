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
  mut count : Int32
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

## Scrolling

An area becomes a window onto a longer list of lines when you draw it with a
`Scroll`. The scroll position is part of your state, like everything else:

```moonbit
struct State {
  log : Array[String]
  scroll : @tui.Scroll // Scroll(stick_to_bottom=true) for a chat or a log
}

// In view: wrap to the area's width, then draw through the scroll position.
frame.lines(body, lines, scroll=state.scroll)

// In the event loop:
PageUp => state.scroll.page_up()
PageDown => state.scroll.page_down()
Input(Mouse({ kind: Scroll(Up), .. })) => state.scroll.scroll_by(-3)
```

Drawing tells the `Scroll` how many lines there are and how tall the area is.
That is what keeps the position inside the content when lines are removed or
the terminal is resized, and what lets `page_up` know the size of a page. With
`stick_to_bottom`, the view follows new lines until the user scrolls up, and
follows again once they return to the end. `at_bottom()` is there for a "more
below" hint.

Mouse events, including the wheel, arrive only when the session is started with
`with_terminal(mouse=true, ...)`. The terminal then stops handling the mouse
itself, so its own text selection does not work while the session runs.

## Selection and copy

Since the terminal no longer selects text once mouse reporting is on, the
application does it. A `Selection` is the selection over the lines of one area:

```moonbit
// In view:
frame.lines(body, lines, scroll=state.scroll, selection=state.selection)

// In the event loop:
Input(Mouse(mouse)) => {
  state.selection.mouse(mouse)
  if mouse.kind is Release(Left) && state.selection.text() is Some(text) {
    terminal.set_clipboard(text)
  }
}
```

Dragging with the left button selects, and the selected text is drawn in
reverse video. A click without a drag removes the selection. When to copy is
your choice: the snippet copies as soon as the button is released, but
`text()` can just as well be read on a key press.

- The selection is tied to the lines, not to screen cells. It stays on the same
  text while the area scrolls, and it can be longer than the screen: dragging
  past the top or bottom edge scrolls the area.
- Lines made by `Line::wrap` are copied as the text was before wrapping. Only
  real line ends become newlines.
- A selection is dropped when the area's width changes or when the lines it
  covers are gone.
- `Terminal::set_clipboard` asks the terminal to set the system clipboard
  (OSC 52). A terminal that does not support it ignores the request, and there
  is no way to tell.

## Text input

The `moonbit-community/tui/editor` package is a multi-line text editor. It is
a separate package built only on the public API above, so it is also the
pattern for writing your own widgets: a value in your state that knows how to
draw itself into an area and how to take events.

```moonbit
// In view. The input grows with its text, so measure it before splitting.
let rows = state.editor.height(width=size.width - 2, max=4)
guard! frame.area().split_rows([Fill, Fixed(rows)]) is [body, input]
guard! input.split_cols([Fixed(2), Fill]) is [marker, text]
frame.line(marker, @tui.Line::from_text("> "))
state.editor.draw(frame, text)

// In the event loop.
Input(Key(key)) =>
  if !state.editor.key(key) && key.code is Enter {
    submit(state.editor.text())
    state.editor.clear()
  }
Input(Paste(text)) => state.editor.insert(text)
```

`key` applies the usual terminal bindings: arrows, Home/End, Backspace and
Delete, the Emacs chords (Ctrl+A/E/B/F/P/N/H/D/U/K/W), and word movement with
Alt or Ctrl. It returns whether it used the key. It leaves a plain Enter alone,
so the application decides what submitting means; Shift+Enter, Alt+Enter, and
Ctrl+J insert a line break. Up on the first row and Down on the last are also
left alone, which is where an application can recall history.

Long lines wrap at the area's width, character by character. When the text has
more rows than the area, the editor scrolls to keep the cursor in view.

## What is here

- `Style`: foreground, background, bold, italic, underline, reverse.
- `Span`, `Line`: styled text with `width`, `wrap`, and `to_text`. Text is
  measured in display columns, so CJK and other wide graphemes take two cells.
  Wrapping breaks at spaces, and anywhere for text without spaces.
- `Rect`, `Length`: areas and `split_rows` / `split_cols`.
- `Frame`: `area`, `line`, `lines`, `fill`, `set_cursor`, `to_text`, and `text`
  for painting at an exact cell. Control characters never become cell content.
- `Scroll`: a scroll position with `scroll_by`, `page_up`, `page_down`,
  `to_top`, `to_bottom`, and optional following of the end.
- `Selection`: a mouse selection over an area's lines, with `mouse`, `text`,
  and `clear`.
- `with_terminal`, `Terminal::size`, `Terminal::draw`, `Terminal::read_event`,
  `Terminal::set_clipboard`. Each draw is one write, wrapped in a synchronized
  update. Mouse reporting is opt-in.
- `editor` package: `Editor`, a multi-line text input with `draw`, `key`,
  `insert`, `text`, `set_text`, `clear`, `height`, and the individual movement
  and deletion operations.

Run the examples:

```sh
moon run examples/counter   # the snippet above
moon run examples/hello     # an editor, scrolling, selection and copy
```

## What is not here yet

- Double-click to select a word, and keyboard-driven selection.
- More than one selectable area sharing a selection, or a selection that
  spans areas.
- Telling which area a mouse event landed in, apart from `Selection`. Events
  carry a row and column; matching them to an area is up to you.
- Keeping the same text in view when a resize re-wraps the lines. A `Scroll`
  counts lines, so the view can shift after the width changes.
- In the editor: undo, selecting text, placing the cursor with the mouse, and
  word wrapping.
- Other widgets, such as lists and menus.
- Padding, borders, and constraint-based layout. Areas only split into fixed
  and fill pieces.
- An inline (non-full-screen) mode. Full-screen is the only mode.

## Development

The library builds against the released `moonbit-community/tty` on mooncakes,
so a checkout is enough:

```sh
moon fmt
moon check --deny-warn
moon test
moon info
```
