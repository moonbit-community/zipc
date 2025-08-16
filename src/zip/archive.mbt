// ZIP archive operations

// Create an empty archive
pub fn empty() -> @types.Archive {
  @types.Archive::{ members: [] }
}

// Check if archive is empty
pub fn is_empty(archive : @types.Archive) -> Bool {
  archive.members.length() == 0
}

// Check if archive contains a member with given path
pub fn mem(path : @types.Fpath, archive : @types.Archive) -> Bool {
  for member_obj in archive.members {
    if @member.path(member_obj) == path {
      return true
    }
  }
  false
}

// Find member by path
pub fn find(path : @types.Fpath, archive : @types.Archive) -> Option[@types.Member] {
  for member_obj in archive.members {
    if @member.path(member_obj) == path {
      return Some(member_obj)
    }
  }
  None
}

// Add member to archive (replaces existing member with same path)
pub fn add(member_obj : @types.Member, archive : @types.Archive) -> @types.Archive {
  let mut new_members : Array[@types.Member] = []
  let member_path = @member.path(member_obj)
  let mut found = false
  
  // Copy existing members, replacing if path matches
  for existing in archive.members {
    if @member.path(existing) == member_path {
      new_members.push(member_obj)
      found = true
    } else {
      new_members.push(existing)
    }
  }
  
  // Add new member if not replacing
  if not(found) {
    new_members.push(member_obj)
  }
  
  @types.Archive::{ members: new_members }
}

// Remove member by path
pub fn remove(path : @types.Fpath, archive : @types.Archive) -> @types.Archive {
  let mut new_members : Array[@types.Member] = []
  
  for member_obj in archive.members {
    if @member.path(member_obj) != path {
      new_members.push(member_obj)
    }
  }
  
  @types.Archive::{ members: new_members }
}

// Get member count
pub fn member_count(archive : @types.Archive) -> Int {
  archive.members.length()
}

// Check if string has ZIP magic bytes
pub fn string_has_magic(s : String) -> Bool {
  if s.length() < 4 {
    return false
  }
  
  // Check for local file header signature (PK\x03\x04)
  if s[0].to_int() == 0x50 && s[1].to_int() == 0x4b && 
     s[2].to_int() == 0x03 && s[3].to_int() == 0x04 {
    return true
  }
  
  // Check for end of central directory signature (PK\x05\x06) - empty archive
  if s[0].to_int() == 0x50 && s[1].to_int() == 0x4b && 
     s[2].to_int() == 0x05 && s[3].to_int() == 0x06 {
    return true
  }
  
  false
}

// Decode ZIP archive from binary string (placeholder)
pub fn of_binary_string(s : String) -> @deflate.Result[@types.Archive, String] {
  if not(string_has_magic(s)) {
    return @deflate.err("Not a valid ZIP archive")
  }
  
  // For now, return empty archive
  @deflate.ok(empty())
}

// Encode archive to binary string (placeholder)
pub fn to_binary_string(archive : @types.Archive) -> @deflate.Result[String, String] {
  if member_count(archive) > @types.max_members {
    return @deflate.err("Too many members")
  }
  
  // For now, return minimal empty ZIP archive
  let empty_zip = "PK\x05\x06" + String::make(18, '\x00')
  @deflate.ok(empty_zip)
}