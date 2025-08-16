// Archive member operations

// Create a new archive member
pub fn make(~path : @types.Fpath, ~mtime : @types.Ptime = @types.dos_epoch, ~mode : @types.Mode = 0o644, kind : @types.MemberKind) -> @deflate.Result[@types.Member, String] {
  if path.length() > @types.max_path_length {
    return @deflate.err("Path too long: \{path.length()} > \{@types.max_path_length}")
  }
  
  // Ensure Unix-style path separators
  let unix_path = ensure_unix(path)
  
  // Ensure directory paths end with '/'
  let final_path = match kind {
    @types.MemberKind::Dir => ensure_directoryness(unix_path)
    @types.MemberKind::File(_) => unix_path
  }
  
  // Set default mode based on kind
  let final_mode = match kind {
    @types.MemberKind::Dir => if mode == 0o644 { 0o755 } else { mode }
    @types.MemberKind::File(_) => mode
  }
  
  let member = @types.Member::{
    path: final_path,
    mode: final_mode,
    mtime,
    kind
  }
  
  @deflate.ok(member)
}

// Ensure Unix-style path separators
fn ensure_unix(path : String) -> String {
  // Replace backslashes with forward slashes
  let mut result = ""
  for i = 0; i < path.length(); i = i + 1 {
    let ch = path[i]
    if ch == '\\' {
      result = result + "/"
    } else {
      result = result + ch.to_string()
    }
  }
  result
}

// Ensure directory path ends with '/'
fn ensure_directoryness(path : String) -> String {
  if path == "" {
    "./"
  } else if path.ends_with("/") {
    path
  } else {
    path + "/"
  }
}

// Sanitize path for safe filesystem use
pub fn sanitize(path : String) -> String {
  let segments = path.split("/")
  let mut clean_segments : Array[String] = []
  
  for segment in segments {
    if segment != "" && segment != "." && segment != ".." {
      clean_segments.push(segment)
    }
  }
  
  if clean_segments.length() == 0 {
    ""
  } else {
    clean_segments.join("/")
  }
}

// Get member path
pub fn path(member : @types.Member) -> @types.Fpath {
  member.path
}

// Get member mode
pub fn mode(member : @types.Member) -> @types.Mode {
  member.mode
}

// Get member modification time
pub fn mtime(member : @types.Member) -> @types.Ptime {
  member.mtime
}

// Get member kind
pub fn kind(member : @types.Member) -> @types.MemberKind {
  member.kind
}
