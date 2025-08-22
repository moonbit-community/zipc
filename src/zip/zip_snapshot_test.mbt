// Simple snapshot tests for ZIP API

///|
test "empty archive properties" {
  let archive = empty()

  // Snapshot: Empty archive properties
  inspect(member_count(archive), content="0")
  inspect(is_empty(archive), content="true")
  inspect(mem("nonexistent.txt", archive), content="false")
}

///|
test "empty archive encoding" {
  let archive = empty()
  match to_binary_string(archive) {
    @deflate.Ok(zip_data) => {
      // Snapshot: Empty ZIP should be exactly 22 bytes
      inspect(zip_data.length(), content="22")

      // Test roundtrip
      match of_binary_string(zip_data) {
        @deflate.Ok(decoded) => {
          inspect(is_empty(decoded), content="true")
          inspect(member_count(decoded), content="0")
        }
        @deflate.Err(error) => fail("Empty ZIP decoding failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Empty ZIP encoding failed: " + error)
  }
}

///|
test "stored file basic properties" {
  let test_content = "Hello, ZIP world!"
  match stored_of_binary_string(test_content) {
    @deflate.Ok(file_data) => {
      // Snapshot: File properties
      inspect(file_compression(file_data), content="Stored")
      inspect(file_compressed_size(file_data), content="17")
      inspect(file_decompressed_size(file_data), content="17")
      inspect(file_can_extract(file_data), content="true")

      // Test extraction
      match file_to_binary_string(file_data) {
        @deflate.Ok(extracted) => inspect(extracted, content=test_content)
        @deflate.Err(error) => fail("File extraction failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Stored file creation failed: " + error)
  }
}

///|
test "error handling basic" {
  // Test invalid ZIP data
  match of_binary_string("Not a ZIP file") {
    @deflate.Ok(_) => fail("Should have failed on invalid ZIP data")
    @deflate.Err(error) =>
      // Snapshot: Should mention magic bytes - test the error message
      inspect(error, content="Not a valid ZIP archive - missing magic bytes")
  }

  // Test empty data
  match of_binary_string("") {
    @deflate.Ok(_) => fail("Should have failed on empty data")
    @deflate.Err(error) =>
      // Snapshot: Should mention size - test the error message
      inspect(error, content="File too small to be a valid ZIP archive")
  }
}

///|
test "compression levels api" {
  let test_data = "Test data for levels"

  // Test that all level constructors work
  let none_level = @deflate.level_none()
  let fast_level = @deflate.level_fast()
  let default_level = @deflate.level_default()
  let best_level = @deflate.level_best()

  // Test compression with different levels
  match @deflate.deflate_of_binary_string(test_data, none_level) {
    @deflate.Ok(compressed) =>
      // Snapshot: Should produce compressed data
      inspect(compressed.length() > 0, content="true")
    @deflate.Err(error) => fail("Level None compression failed: " + error)
  }
  match @deflate.deflate_of_binary_string(test_data, fast_level) {
    @deflate.Ok(compressed) =>
      // Snapshot: Should produce compressed data
      inspect(compressed.length() > 0, content="true")
    @deflate.Err(error) => fail("Level Fast compression failed: " + error)
  }
}
