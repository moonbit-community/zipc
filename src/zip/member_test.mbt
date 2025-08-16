// Tests for ZIP member operations

test "create_file_member" {
  let file_data = match @file.stored_of_binary_string("content") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  match make(~path="test.txt", @types.MemberKind::File(file_data)) {
    Ok(member) => {
      @test.eq(path(member), "test.txt")
      @test.eq(mode(member), 0o644)  // Default file mode
      @test.eq(mtime(member), @types.dos_epoch)  // Default time
      match kind(member) {
        @types.MemberKind::File(_) => ()
        @types.MemberKind::Dir => @test.fail("Should be file member")
      }
    }
    Err(msg) => @test.fail("Failed to create member: \{msg}")
  }
}

test "create_directory_member" {
  match make(~path="docs", @types.MemberKind::Dir) {
    Ok(member) => {
      @test.eq(path(member), "docs/")  // Should end with /
      @test.eq(mode(member), 0o755)  // Default directory mode
      match kind(member) {
        @types.MemberKind::Dir => ()
        @types.MemberKind::File(_) => @test.fail("Should be directory member")
      }
    }
    Err(msg) => @test.fail("Failed to create directory member: \{msg}")
  }
}

test "custom_member_properties" {
  let file_data = match @file.stored_of_binary_string("content") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  let custom_time = 1234567890
  let custom_mode = 0o755
  
  match make(~path="custom.txt", ~mtime=custom_time, ~mode=custom_mode, @types.MemberKind::File(file_data)) {
    Ok(member) => {
      @test.eq(path(member), "custom.txt")
      @test.eq(mode(member), custom_mode)
      @test.eq(mtime(member), custom_time)
    }
    Err(msg) => @test.fail("Failed to create custom member: \{msg}")
  }
}

test "path_normalization" {
  let file_data = match @file.stored_of_binary_string("content") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  // Test backslash to forward slash conversion
  match make(~path="folder\\file.txt", @types.MemberKind::File(file_data)) {
    Ok(member) => {
      @test.eq(path(member), "folder/file.txt")
    }
    Err(msg) => @test.fail("Failed to create member with backslashes: \{msg}")
  }
  
  // Test directory path normalization
  match make(~path="folder", @types.MemberKind::Dir) {
    Ok(member) => {
      @test.eq(path(member), "folder/")
    }
    Err(msg) => @test.fail("Failed to create directory member: \{msg}")
  }
}

test "path_sanitization" {
  // Test removing dangerous path components
  @test.eq(sanitize("../../../etc/passwd"), "etc/passwd")
  @test.eq(sanitize("./file.txt"), "file.txt")
  @test.eq(sanitize("folder/../file.txt"), "folder/file.txt")
  @test.eq(sanitize("normal/path/file.txt"), "normal/path/file.txt")
  @test.eq(sanitize(""), "")
  @test.eq(sanitize("..."), "...")  // Not a relative segment
}

test "path_too_long" {
  let long_path = String::make(@types.max_path_length + 1, 'a')
  let file_data = match @file.stored_of_binary_string("content") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  match make(~path=long_path, @types.MemberKind::File(file_data)) {
    Ok(_) => @test.fail("Should reject path that's too long")
    Err(_) => ()  // Expected error
  }
}

test "empty_directory_path" {
  match make(~path="", @types.MemberKind::Dir) {
    Ok(member) => {
      @test.eq(path(member), "./")  // Empty path becomes "./"
    }
    Err(msg) => @test.fail("Failed to create member with empty path: \{msg}")
  }
}
