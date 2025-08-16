// Archive member operations

// Create a new archive member
pub fn make(path : @types.Fpath, kind : @types.MemberKind) -> @deflate.Result[@types.Member, String] {
  if path.length() > @types.max_path_length {
    return @deflate.err("Path too long")
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
    @types.MemberKind::Dir => 0o755
    @types.MemberKind::File(_) => 0o644
  }
  
  let member_obj = @types.Member::{
    path: final_path,
    mode: final_mode,
    mtime: @types.dos_epoch,
    kind
  }
  
  @deflate.ok(member_obj)
}

// Ensure Unix-style path separators
fn ensure_unix(path : String) -> String {
  // Simple implementation - replace backslashes with forward slashes
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

// Get member path
pub fn path(member_obj : @types.Member) -> @types.Fpath {
  member_obj.path
}

// Get member mode
pub fn mode(member_obj : @types.Member) -> @types.Mode {
  member_obj.mode
}

// Get member modification time
pub fn mtime(member_obj : @types.Member) -> @types.Ptime {
  member_obj.mtime
}

// Get member kind
pub fn kind(member_obj : @types.Member) -> @types.MemberKind {
  member_obj.kind
}