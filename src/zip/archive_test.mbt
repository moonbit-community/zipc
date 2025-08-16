// Tests for ZIP archive operations

test "empty_archive" {
  let archive = empty()
  @test.eq(is_empty(archive), true)
  @test.eq(member_count(archive), 0)
}

test "add_file_member" {
  let archive = empty()
  
  // Create a file
  let file_data = match @file.stored_of_binary_string("Hello, World!") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  // Create a member
  let member = match @member.make(~path="hello.txt", @types.MemberKind::File(file_data)) {
    Ok(m) => m
    Err(_) => @test.fail("Failed to create member")
  }
  
  // Add to archive
  let archive2 = add(member, archive)
  @test.eq(is_empty(archive2), false)
  @test.eq(member_count(archive2), 1)
  @test.eq(mem("hello.txt", archive2), true)
  @test.eq(mem("nonexistent.txt", archive2), false)
}

test "add_directory_member" {
  let archive = empty()
  
  // Create a directory member
  let member = match @member.make(~path="docs", @types.MemberKind::Dir) {
    Ok(m) => m
    Err(_) => @test.fail("Failed to create directory member")
  }
  
  // Add to archive
  let archive2 = add(member, archive)
  @test.eq(member_count(archive2), 1)
  @test.eq(mem("docs/", archive2), true)  // Should end with /
}

test "find_member" {
  let archive = empty()
  
  let file_data = match @file.stored_of_binary_string("content") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  let member = match @member.make(~path="test.txt", @types.MemberKind::File(file_data)) {
    Ok(m) => m
    Err(_) => @test.fail("Failed to create member")
  }
  
  let archive2 = add(member, archive)
  
  match find("test.txt", archive2) {
    Some(found) => @test.eq(@member.path(found), "test.txt")
    None => @test.fail("Member should be found")
  }
  
  match find("nonexistent.txt", archive2) {
    Some(_) => @test.fail("Member should not be found")
    None => ()
  }
}

test "replace_member" {
  let archive = empty()
  
  // Add first version
  let file1 = match @file.stored_of_binary_string("version 1") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  let member1 = match @member.make(~path="file.txt", @types.MemberKind::File(file1)) {
    Ok(m) => m
    Err(_) => @test.fail("Failed to create member")
  }
  
  let archive2 = add(member1, archive)
  @test.eq(member_count(archive2), 1)
  
  // Add second version (should replace)
  let file2 = match @file.stored_of_binary_string("version 2") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  let member2 = match @member.make(~path="file.txt", @types.MemberKind::File(file2)) {
    Ok(m) => m
    Err(_) => @test.fail("Failed to create member")
  }
  
  let archive3 = add(member2, archive2)
  @test.eq(member_count(archive3), 1)  // Should still be 1 (replaced)
}

test "remove_member" {
  let archive = empty()
  
  let file_data = match @file.stored_of_binary_string("content") {
    Ok(file) => file
    Err(_) => @test.fail("Failed to create file data")
  }
  
  let member = match @member.make(~path="remove_me.txt", @types.MemberKind::File(file_data)) {
    Ok(m) => m
    Err(_) => @test.fail("Failed to create member")
  }
  
  let archive2 = add(member, archive)
  @test.eq(member_count(archive2), 1)
  
  let archive3 = remove("remove_me.txt", archive2)
  @test.eq(member_count(archive3), 0)
  @test.eq(is_empty(archive3), true)
}

test "zip_magic_detection" {
  // Test local file header magic
  let zip_data1 = "PK\x03\x04" + "rest of zip data"
  @test.eq(string_has_magic(zip_data1), true)
  
  // Test end of central directory magic (empty archive)
  let zip_data2 = "PK\x05\x06" + "rest of zip data"
  @test.eq(string_has_magic(zip_data2), true)
  
  // Test non-ZIP data
  let non_zip = "This is not a ZIP file"
  @test.eq(string_has_magic(non_zip), false)
  
  // Test too short data
  let short_data = "PK"
  @test.eq(string_has_magic(short_data), false)
}
