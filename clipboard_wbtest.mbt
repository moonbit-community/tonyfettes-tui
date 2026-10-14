///|
/// The program and arguments chosen with the environment `vars` on a machine
/// where exactly the files in `files` exist.
async fn chosen(
  vars : Array[(String, String)],
  files : Array[String],
) -> (String, Array[String])? {
  let vars = Map::from_array(vars)
  let found = find_clipboard_command(name => vars.get(name), path => {
    files.contains(path)
  })
  match found {
    Some(command) => Some((command.program, command.args))
    None => None
  }
}

///|
async test "macOS uses pbcopy" {
  debug_inspect(
    chosen([("PATH", "/usr/local/bin:/usr/bin")], ["/usr/bin/pbcopy"]),
    content=(
      #|Some(("pbcopy", []))
    ),
  )
}

///|
async test "Linux uses the program for its display server" {
  let path = ("PATH", "/usr/bin")
  let all = ["/usr/bin/wl-copy", "/usr/bin/xclip", "/usr/bin/xsel"]
  debug_inspect(
    chosen([path, ("WAYLAND_DISPLAY", "wayland-0")], all),
    content=(
      #|Some(("wl-copy", []))
    ),
  )
  debug_inspect(
    chosen([path, ("DISPLAY", ":0")], all),
    content=(
      #|Some(("xclip", ["-selection", "clipboard"]))
    ),
  )
  debug_inspect(
    chosen([path, ("DISPLAY", ":0")], ["/usr/bin/xsel"]),
    content=(
      #|Some(("xsel", ["--clipboard", "--input"]))
    ),
  )
  // A program that is installed but has no display server to talk to is not
  // used.
  debug_inspect(
    chosen([path], all),
    content=(
      #|None
    ),
  )
}

///|
async test "nothing is run over SSH" {
  for name in ["SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY"] {
    debug_inspect(
      chosen([("PATH", "/usr/bin"), (name, "x")], ["/usr/bin/pbcopy"]),
      content=(
        #|None
      ),
    )
  }
}

///|
async test "every directory on the PATH is searched, empty entries skipped" {
  debug_inspect(
    chosen([("PATH", "::/opt/bin:/usr/bin")], ["/usr/bin/pbcopy"]),
    content=(
      #|Some(("pbcopy", []))
    ),
  )
  debug_inspect(
    chosen([], ["/usr/bin/pbcopy"]),
    content=(
      #|None
    ),
  )
}
