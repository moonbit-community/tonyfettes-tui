///|
/// Render CommonMark and table/task-list extensions as terminal cells.
/// Width is measured in display columns, including CJK and emoji graphemes.
pub fn render(
  text : String,
  width : Int32,
  dim~ : Bool = false,
  theme~ : Theme = Theme(),
) -> Array[@tui.Line] {
  let doc = @cmark.Doc::from_string(text, strict=false)
  let renderer = Renderer::{ defs: doc.defs, dim, theme, }
  renderer.block(doc.block, width.max(1))
}

///|
priv struct Renderer {
  defs : Map[String, @cmark.LabelDef]
  dim : Bool
  theme : Theme
}

///|
fn Renderer::base(self : Renderer) -> @tui.Style {
  if self.dim {
    self.muted()
  } else {
    self.theme.text
  }
}

///|
fn Renderer::muted(self : Renderer) -> @tui.Style {
  styled(self.theme.text, self.theme.muted)
}

///|
fn Renderer::heading(self : Renderer) -> @tui.Style {
  styled(self.base(), self.theme.heading)
}

///|
fn Renderer::code_style(self : Renderer, style : @tui.Style) -> @tui.Style {
  let code = styled(style, self.theme.code)
  if self.dim {
    restyle(code, fg=self.muted().fg)
  } else {
    code
  }
}

///|
fn Renderer::inline(
  self : Renderer,
  inline : @cmark.Inline,
  style : @tui.Style,
  lines : Array[Array[@tui.Span]],
) -> Unit {
  let push = fn(text : String, style : @tui.Style) {
    lines[lines.length() - 1].push(@tui.Span(text, style~))
  }
  match inline {
    Text(node) => push(node.v, style)
    Inlines(node) =>
      for child in node.v.iter() {
        self.inline(child, style, lines)
      }
    StrongEmphasis(node) =>
      self.inline(node.v.inline, restyle(style, bold=true), lines)
    Emphasis(node) =>
      self.inline(node.v.inline, restyle(style, italic=true), lines)
    CodeSpan(node) => push(node.v.code(), self.code_style(style))
    Break(node) =>
      if node.v.ty is Hard {
        lines.push([])
      } else {
        push(" ", style)
      }
    Link(node) | Image(node) => {
      if inline is Image(_) {
        push("Image: ", self.muted())
      }
      self.inline(node.v.text, styled(style, self.theme.link), lines)
      if node.v.reference_definition(self.defs) is Some(LinkDef(def)) &&
        def.v.dest is Some(dest) {
        let label = node.v.text
          .to_plain_text(break_on_soft=false)
          .iter()
          .flat_map(parts => parts.iter())
          .collect()
          .join("")
        if dest.v != label && !dest.v.is_empty() {
          push(" (\{dest.v})", self.muted())
        }
      }
    }
    Autolink(node) => push(node.v.link.v, styled(style, self.theme.link))
    ExtStrikethrough(node) =>
      self.inline(node.v.0, restyle(style, fg=self.muted().fg), lines)
    ExtMathSpan(node) => push(node.v.tex(), self.code_style(style))
    RawHtml(node) =>
      for tight in node.v.0.iter() {
        push(tight.to_string(), style)
      }
  }
}

///|
fn Renderer::inline_lines(
  self : Renderer,
  inline : @cmark.Inline,
  style : @tui.Style,
) -> Array[@tui.Line] {
  let lines : Array[Array[@tui.Span]] = [[]]
  self.inline(inline, style, lines)
  lines.map(spans => @tui.Line(spans))
}

///|
fn Renderer::prefixed(
  self : Renderer,
  lines : Array[@tui.Line],
  first : String,
  rest : String,
  width : Int32,
) -> Array[@tui.Line] {
  lines.mapi((i, line) => {
    let prefix = @tui.Line::from_text(
      if i == 0 {
        first
      } else {
        rest
      },
      style=self.muted(),
    )
    if prefix.width() >= width {
      line
    } else {
      prefix.concat(line)
    }
  })
}

///|
fn inset(width : Int32, prefix : String) -> Int32 {
  let size = @tui.Line::from_text(prefix).width()
  if size >= width {
    width
  } else {
    width - size
  }
}

///|
fn Renderer::block(
  self : Renderer,
  block : @cmark.Block,
  width : Int32,
) -> Array[@tui.Line] {
  match block {
    Blocks(node) => {
      let lines : Array[@tui.Line] = []
      for child in node.v.iter() {
        let rendered = self.block(child, width)
        if !rendered.is_empty() {
          if !lines.is_empty() {
            lines.push(@tui.Line([]))
          }
          lines.append(rendered)
        }
      }
      lines
    }
    Paragraph(node) =>
      self
      .inline_lines(node.v.inline, self.base())
      .iter()
      .flat_map(line => line.wrap(width).iter())
      .collect()
    Heading(node) =>
      self
      .inline_lines(node.v.inline, self.heading())
      .iter()
      .flat_map(line => line.wrap(width).iter())
      .collect()
    BlockQuote(node) =>
      self.prefixed(
        self.block(node.v.block, inset(width, "│ ")),
        "│ ",
        "│ ",
        width,
      )
    List(node) => {
      let lines : Array[@tui.Line] = []
      let mut number = match node.v.ty {
        Unordered(_) => 0
        Ordered(start, _) => start
      }
      for item in node.v.items.iter() {
        let marker = if item.v.ext_task_marker is Some(task) {
          if task.v == ' ' {
            "☐ "
          } else {
            "☑ "
          }
        } else if node.v.ty is Ordered(_, _) {
          "\{number}. "
        } else {
          "• "
        }
        number += 1
        let content = self.block(item.v.block, inset(width, marker))
        if !node.v.tight && !lines.is_empty() {
          lines.push(@tui.Line([]))
        }
        lines.append(
          self.prefixed(
            content,
            marker,
            " ".repeat(@tui.Line::from_text(marker).width()),
            width,
          ),
        )
      }
      lines
    }
    CodeBlock(node) | ExtMathBlock(node) => {
      let lines : Array[@tui.Line] = []
      if node.v.info_string is Some(info) && !info.v.is_empty() {
        lines.append(
          @tui.Line::from_text(info.v, style=self.muted()).wrap(width),
        )
      }
      for code in node.v.code.iter() {
        let line = @tui.Line::from_text(
          code.v.replace(old="\t", new="    "),
          style=self.code_style(self.base()),
        )
        lines.append(
          self.prefixed(line.wrap(inset(width, "│ ")), "│ ", "│ ", width),
        )
      }
      lines
    }
    ExtTable(node) => self.table(node.v, width)
    ThematicBreak(_) =>
      [@tui.Line::from_text("─".repeat(width.min(40)), style=self.muted())]
    HtmlBlock(node) =>
      node.v.0
      .iter()
      .flat_map(line => {
        @tui.Line::from_text(line.v, style=self.base()).wrap(width).iter()
      })
      .collect()
    ExtFootnoteDefinition(node) =>
      self.prefixed(
        self.block(node.v.block, inset(width, "↳ ")),
        "↳ ",
        "  ",
        width,
      )
    BlankLine(_) | LinkRefDefinition(_) => []
  }
}

///|
fn restyle(
  style : @tui.Style,
  fg~ : @color.Color = style.fg,
  bg~ : @color.Color = style.bg,
  bold~ : Bool = style.bold,
  italic~ : Bool = style.italic,
  underline~ : Bool = style.underline,
) -> @tui.Style {
  @tui.Style(fg~, bg~, bold~, italic~, underline~, reverse=style.reverse)
}
