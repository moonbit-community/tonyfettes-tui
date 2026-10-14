///|
/// A program that puts what it reads from standard input on the system
/// clipboard.
priv struct ClipboardCommand {
  program : String
  args : Array[String]
}

///|
/// The clipboard program to use, or `None` when there is none or the program
/// runs over SSH, where it would fill the clipboard of the remote machine
/// instead of the user's. `env` reads an environment variable and `exists`
/// says whether a file exists.
///
/// The first one found on the `PATH` wins: `pbcopy` (macOS), then `wl-copy`
/// under Wayland, then `xclip` or `xsel` under X11.
async fn find_clipboard_command(
  env : (String) -> String?,
  exists : async (String) -> Bool,
) -> ClipboardCommand? {
  for name in ["SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY"] {
    if env(name) is Some(_) {
      return None
    }
  }
  guard env("PATH") is Some(path) else { return None }
  let candidates = [{ program: "pbcopy", args: [], }]
  if env("WAYLAND_DISPLAY") is Some(_) {
    candidates.push({ program: "wl-copy", args: [], })
  }
  if env("DISPLAY") is Some(_) {
    candidates.push({ program: "xclip", args: ["-selection", "clipboard"], })
    candidates.push({ program: "xsel", args: ["--clipboard", "--input"], })
  }
  for candidate in candidates {
    for dir in path.split(":") {
      if !dir.is_empty() && exists("\{dir}/\{candidate.program}") {
        return Some(candidate)
      }
    }
  }
  None
}

///|
/// Run the clipboard program with `text` as its input. Its output is thrown
/// away so it cannot draw over the screen, and it is killed if it takes more
/// than two seconds. Failures are ignored: the clipboard simply keeps what it
/// had.
async fn ClipboardCommand::copy(
  self : ClipboardCommand,
  text : StringView,
) -> Unit {
  let finished = @async.with_timeout_opt(2000, () => {
    @async.with_task_group(group => {
      let (input, writer) = @process.write_to_process()
      let output = @process.redirect_to_file("/dev/null")
      group.spawn_bg(() => {
        defer writer.close()
        writer.write(text)
      })
      ignore(
        @process.run(
          self.program,
          self.args,
          stdin=input,
          stdout=output,
          stderr=output,
          cancel_handler=@process.hard_cancel(),
        ),
      )
    })
  }) catch {
    _ => None
  }
  ignore(finished)
}
