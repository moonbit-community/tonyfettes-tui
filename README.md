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
  let rows = @tui.Layout::vertical([Length(1), Length(1), Fill(1)])
  guard! rows.split(frame.area()) is [count, help, _]
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
`view(state, size).to_text()` returns what the screen would show, `.cursor()`
where the cursor is, and `.style_at(row~, col~)` the style of a cell.

## Layout

There are two layers, and neither involves coordinates.

**Areas** say where things go. `frame.area()` is the whole frame, and a
`Layout` divides an area into smaller ones: `Layout::vertical` stacks them top
to bottom, `Layout::horizontal` puts them side by side. Each piece has a
constraint, and splitting an area returns one area per constraint.
Destructure the result to name them:

```moonbit
let rows = @tui.Layout::vertical([Length(1), Fill(1), Length(1)])
guard! rows.split(frame.area()) is [header, body, footer]
let columns = @tui.Layout::horizontal([Fill(1), Length(8)], spacing=1)
guard! columns.split(header) is [title, clock]
```

The pattern matches as long as it lists as many names as there are
constraints. `guard!` panics if it does not; write
`guard ... is [...] else { ... }` to handle that case instead.

| Constraint | Size |
| --- | --- |
| `Length(n)` | exactly `n` |
| `Percentage(p)` | `p` percent of the space |
| `Ratio(a, b)` | `a / b` of the space |
| `Min(n)` | at least `n`; grows when no `Fill` claims the leftover space |
| `Max(n)` | at most `n`; takes `n` when there is room |
| `Fill(w)` | a share of the leftover space, in proportion to its weight `w` |

The sizes are worked out in order, and the rule is short enough to predict.
Each piece asks for a size: its number, its share, or nothing for a `Fill`. The
pieces are served first to last, so when the space runs out it is the later
ones that shrink. What is left over goes to the `Fill` pieces by weight; if
there are none, to the `Min` pieces equally; and if there are none of those
either it stays empty.

`spacing` puts gaps between the pieces and `margin` a border of empty cells
around them. `flex` says where the pieces go when space stays empty: `Start`,
`Center`, `End`, or `SpaceBetween`. That is how to center a dialog:

```moonbit
let rows = @tui.Layout::vertical([Length(5)], flex=Center)
guard! rows.split(frame.area()) is [band]
let columns = @tui.Layout::horizontal([Length(40)], flex=Center)
guard! columns.split(band) is [dialog]
```

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
  (OSC 52), which also works over SSH. Some terminals ignore that request, so
  when the program runs on the user's own machine the text is also handed to
  `pbcopy` (macOS) or `wl-copy`, `xclip`, or `xsel` (Linux). Over SSH only the
  terminal can reach the user's clipboard, and there is no way to tell whether
  it did.

## Text input

The `moonbit-community/tui/editor` package is a multi-line text editor. It is
a separate package built only on the public API above, so it is also the
pattern for writing your own widgets: a value in your state that knows how to
draw itself into an area and how to take events.

```moonbit
// In view. The input grows with its text, so measure it before splitting.
let rows = state.editor.height(width=size.width - 2, max=4)
let layout = @tui.Layout::vertical([Fill(1), Length(rows)])
guard! layout.split(frame.area()) is [body, input]
let layout = @tui.Layout::horizontal([Length(2), Fill(1)])
guard! layout.split(input) is [marker, text]
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

`key` applies the usual terminal bindings: arrows, Home/End (with Ctrl, to the
start or end of the whole text), Backspace and Delete, the Emacs chords
(Ctrl+A/E/B/F/P/N/H/D/U/K/W), and word movement with Alt or Ctrl. It returns
whether it used the key. It leaves a plain Enter alone, so the application
decides what submitting means; Shift+Enter, Alt+Enter, and Ctrl+J insert a line
break. Up on the first row and Down on the last are also left alone, which is
where an application can recall history.

Long lines wrap at the area's width, character by character. When the text has
more rows than the area, the editor scrolls to keep the cursor in view.

The same widget can be dressed up as a code editor. `draw` takes the pieces as
optional arguments, and `examples/text_editor` uses all of them:

```moonbit
state.editor.draw(
  frame,
  body,
  style=text_style,                // the text, and the area behind it
  highlight=highlight_moonbit,     // (String) -> Array[Span], one line at a time
  line_numbers=line_number_style,  // a number column on the left
  current_line=current_line_style, // laid over the cursor's line
)
```

`highlight` is given the text of a line and returns that text cut into styled
spans; the editor maps the styles onto the wrapped rows. `position()` returns
the cursor's line and column for a status row, and `mouse(event)` moves the
cursor to where the left button was pressed.

## What is here

- `Style`: foreground, background, bold, italic, underline, reverse.
- `Span`, `Line`: styled text with `width`, `wrap`, and `to_text`. Text is
  measured in display columns, so CJK and other wide graphemes take two cells.
  Wrapping breaks at spaces, and anywhere for text without spaces.
- `Rect`, `Layout`, `Constraint`, `Flex`: areas, and dividing them along one
  direction with spacing, a margin, and a choice of where unused space goes.
- `Frame`: `area`, `line`, `lines`, `fill`, `set_cursor`, and `text` for
  painting at an exact cell; `to_text`, `cursor`, and `style_at` for reading a
  frame back in tests. Control characters never become cell content.
- `Scroll`: a scroll position with `scroll_by`, `page_up`, `page_down`,
  `to_top`, `to_bottom`, and optional following of the end.
- `Selection`: a mouse selection over an area's lines, with `mouse`, `text`,
  and `clear`.
- `with_terminal`, `Terminal::size`, `Terminal::draw`, `Terminal::read_event`,
  `Terminal::set_clipboard`. Each draw is one write, wrapped in a synchronized
  update. Mouse reporting is opt-in.
- `editor` package: `Editor`, a multi-line text input with `draw`, `key`,
  `mouse`, `insert`, `text`, `set_text`, `clear`, `height`, `position`, and
  the individual movement and deletion operations. Drawing can add syntax
  highlighting, line numbers, and a highlight for the current line; `layout`
  returns the visible rows and the cursor instead, for an application that
  draws the text itself.

Run the examples:

```sh
moon run examples/counter                   # the snippet above
moon run examples/hello                     # an input box, scrolling, selection and copy
moon run examples/text_editor -- frame.mbt  # a code editor: highlighting, line numbers, mouse
```

## What is not here yet

- Double-click to select a word, and keyboard-driven selection.
- More than one selectable area sharing a selection, or a selection that
  spans areas.
- Telling which area a mouse event landed in, apart from `Selection`. Events
  carry a row and column; matching them to an area is up to you.
- Keeping the same text in view when a resize re-wraps the lines. A `Scroll`
  counts lines, so the view can shift after the width changes.
- In the editor: undo, selecting text, word wrapping, and horizontal
  scrolling.
- Other widgets, such as lists and menus.
- Padding and borders as part of drawing, and layouts that size a piece from
  its content. A piece whose size depends on what is in it is measured first
  and given a `Length`.
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

## Draggable pane splits

`Splitter(axis~, position~, min_first~, min_second~, max_first?)` divides an
area horizontally or vertically with a one-cell divider. `draw(frame, area)`
returns the two pane areas for application-owned content. Position is the size
of the first pane; drawing clamps it to the available space and constraints.
If both minima cannot fit, the first minimum takes priority.

Dispatch mouse events to `mouse` before other widgets. A left press on the
divider captures the entire gesture until release, even outside the pane, so
dragging never activates content underneath. `position()` can be persisted;
`dragging()` can drive pointer hints. Bounds changes cancel capture, and the
application should call `cancel()` on focus loss or when hiding the split.
