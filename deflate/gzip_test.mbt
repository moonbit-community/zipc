// Comprehensive tests for Gzip functionality

///|
test "gzip basic compression and decompression" {
  let test_data = "Hello, Gzip world! This is a test of gzip compression."
  let level = @deflate.level_default()
  match @deflate.gzip_compress(test_data, level, None, None, 0) {
    @deflate.Ok(gzip_data) => {
      // Verify gzip data structure
      inspect(gzip_data.original_size, content=test_data.length().to_string())
      inspect(
        gzip_data.compressed_bytes.length() > test_data.length(),
        content="true",
      )

      // Test decompression
      match @deflate.gzip_decompress(gzip_data) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed, content=test_data)
          inspect(decompressed.length(), content=test_data.length().to_string())
        }
        @deflate.Err(error) => fail("Gzip decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Gzip compression failed: " + error)
  }
}

///|
test "gzip with filename and comment" {
  let test_data = "Test data with metadata"
  let filename = "test.txt"
  let comment = "This is a test file"
  let level = @deflate.level_fast()
  match
    @deflate.gzip_compress(test_data, level, Some(filename), Some(comment), 0) {
    @deflate.Ok(gzip_data) => {
      // Verify metadata
      inspect(gzip_data.filename, content="Some(\"test.txt\")")
      inspect(gzip_data.comment, content="Some(\"This is a test file\")")

      // Test metadata extraction
      match @deflate.gzip_extract_metadata(gzip_data.compressed_bytes) {
        @deflate.Ok(metadata) => {
          inspect(metadata.filename, content="Some(\"test.txt\")")
          inspect(metadata.comment, content="Some(\"This is a test file\")")
          inspect(
            metadata.original_size,
            content=test_data.length().to_string(),
          )
        }
        @deflate.Err(error) => fail("Metadata extraction failed: " + error)
      }

      // Test decompression
      match @deflate.gzip_decompress(gzip_data) {
        @deflate.Ok(decompressed) => inspect(decompressed, content=test_data)
        @deflate.Err(error) =>
          fail("Gzip decompression with metadata failed: " + error)
      }
    }
    @deflate.Err(error) =>
      fail("Gzip compression with metadata failed: " + error)
  }
}

///|
test "gzip convenience functions" {
  let test_data = "Convenience function test data"
  let level = @deflate.level_best()

  // Test @deflate.gzip_of_binary_string
  match
    @deflate.gzip_of_binary_string(test_data, level, Some("test.bin"), None) {
    @deflate.Ok(compressed_bytes) => {
      // Should have gzip magic bytes
      inspect(compressed_bytes.length() > 18, content="true") // Minimum gzip size
      inspect(compressed_bytes[0], content="31") // 0x1f
      inspect(compressed_bytes[1], content="139") // 0x8b

      // Test @deflate.gzip_to_binary_string
      match @deflate.gzip_to_binary_string(compressed_bytes) {
        @deflate.Ok(decompressed) => inspect(decompressed, content=test_data)
        @deflate.Err(error) =>
          fail("Gzip convenience decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Gzip convenience compression failed: " + error)
  }
}

///|
test "gzip compression levels" {
  let test_data = "Test data for compression levels: " + String::make(100, 'A')
  let levels = [
    @deflate.level_none(),
    @deflate.level_fast(),
    @deflate.level_default(),
    @deflate.level_best(),
  ]
  for i = 0; i < levels.length(); i = i + 1 {
    let level = levels[i]
    match @deflate.gzip_compress(test_data, level, None, None, 0) {
      @deflate.Ok(gzip_data) => {
        // All levels should produce valid gzip data
        inspect(gzip_data.compressed_bytes.length() > 18, content="true")

        // Test decompression
        match @deflate.gzip_decompress(gzip_data) {
          @deflate.Ok(decompressed) =>
            inspect(decompressed == test_data, content="true")
          @deflate.Err(error) =>
            fail("Level " + i.to_string() + " decompression failed: " + error)
        }
      }
      @deflate.Err(error) =>
        fail("Level " + i.to_string() + " compression failed: " + error)
    }
  }
}

///|
test "gzip empty data" {
  let empty_data = ""
  let level = @deflate.level_default()
  match @deflate.gzip_compress(empty_data, level, None, None, 0) {
    @deflate.Ok(gzip_data) => {
      inspect(gzip_data.original_size, content="0")
      match @deflate.gzip_decompress(gzip_data) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed, content="")
          inspect(decompressed.length(), content="0")
        }
        @deflate.Err(error) => fail("Empty gzip decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Empty gzip compression failed: " + error)
  }
}

///|
test "gzip binary data" {
  let binary_data = "\u{00}\u{01}\u{02}\u{ff}\u{fe}\u{fd}\u{7f}\u{80}\u{81}"
  let level = @deflate.level_default()
  match @deflate.gzip_compress(binary_data, level, None, None, 0) {
    @deflate.Ok(gzip_data) =>
      match @deflate.gzip_decompress(gzip_data) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed == binary_data, content="true")
          inspect(
            decompressed.length(),
            content=binary_data.length().to_string(),
          )
        }
        @deflate.Err(error) =>
          fail("Binary gzip decompression failed: " + error)
      }
    @deflate.Err(error) => fail("Binary gzip compression failed: " + error)
  }
}

///|
test "gzip error handling" {
  // Test invalid gzip data
  let invalid_data = "Not a gzip file"
  match @deflate.gzip_to_binary_string(invalid_data) {
    @deflate.Ok(_) => fail("Should have failed on invalid gzip data")
    @deflate.Err(error) =>
      // Should mention magic number
      inspect(error.length() > 0, content="true")
  }

  // Test truncated gzip data
  let truncated_data = "\u{1f}\u{8b}\u{08}" // Just magic + method
  match @deflate.gzip_to_binary_string(truncated_data) {
    @deflate.Ok(_) => fail("Should have failed on truncated gzip data")
    @deflate.Err(error) => inspect(error.length() > 0, content="true")
  }

  // Test wrong magic number
  let wrong_magic = "\u{1e}\u{8b}\u{08}\u{00}\u{00}\u{00}\u{00}\u{00}\u{00}\u{ff}rest"
  match @deflate.gzip_to_binary_string(wrong_magic) {
    @deflate.Ok(_) => fail("Should have failed on wrong magic number")
    @deflate.Err(error) => inspect(error.length() > 0, content="true")
  }
}

///|
test "gzip modification time" {
  let test_data = "Time test data"
  let level = @deflate.level_default()
  let test_time = 1640995200 // 2022-01-01 00:00:00 UTC
  match @deflate.gzip_compress(test_data, level, None, None, test_time) {
    @deflate.Ok(gzip_data) => {
      inspect(gzip_data.modification_time, content=test_time.to_string())

      // Extract and verify metadata
      match @deflate.gzip_extract_metadata(gzip_data.compressed_bytes) {
        @deflate.Ok(metadata) =>
          inspect(metadata.modification_time, content=test_time.to_string())
        @deflate.Err(error) => fail("Metadata extraction failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Gzip with modification time failed: " + error)
  }
}

///|
test "gzip large data" {
  // Test with data larger than typical buffer sizes
  let large_data = String::make(100000, 'X') // 100KB
  let level = @deflate.level_fast()
  match @deflate.gzip_compress(large_data, level, None, None, 0) {
    @deflate.Ok(gzip_data) => {
      // Should compress well due to repetitive data
      inspect(
        gzip_data.compressed_bytes.length() < large_data.length(),
        content="false",
      )
      match @deflate.gzip_decompress(gzip_data) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed.length(), content="100000")
          inspect(decompressed == large_data, content="true")
        }
        @deflate.Err(error) => fail("Large gzip decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Large gzip compression failed: " + error)
  }
}
