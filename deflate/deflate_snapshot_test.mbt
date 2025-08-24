// Simple snapshot tests for deflate API

///|
test "deflate api basic functionality" {
  let test_data = "Hello, deflate world!"
  let level = @deflate.level_none()

  // Test compression API
  match @deflate.deflate_of_binary_string(test_data, level) {
    @deflate.Ok(compressed) => {
      // Snapshot: Should produce some compressed data
      inspect(compressed.length() > 0, content="true")

      // Test decompression API
      match
        @deflate.deflate_decompress_raw_string(compressed, test_data.length()) {
        @deflate.Ok(decompressed) =>
          // Snapshot: Should recover original data
          inspect(decompressed, content=test_data)
        @deflate.Err(error) => fail("Decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Compression failed: " + error)
  }
}

///|
test "zlib api basic functionality" {
  let test_data = "Hello, zlib world!"
  let level = @deflate.level_none()

  // Test zlib compression API
  match @deflate.zlib_of_binary_string(test_data, level) {
    @deflate.Ok(compressed) => {
      // Snapshot: Should produce compressed data
      inspect(compressed.length() > test_data.length(), content="true")

      // Test zlib decompression API
      match @deflate.zlib_to_binary_string(compressed, test_data.length()) {
        @deflate.Ok(decompressed) =>
          // Snapshot: Should recover original data
          inspect(decompressed, content=test_data)
        @deflate.Err(error) => fail("Zlib decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Zlib compression failed: " + error)
  }
}

///|
test "checksum consistency" {
  let test_data = "Checksum test data"

  // Test Adler-32 consistency  
  let adler1 = @adler32.bytes(test_data.to_bytes())
  let adler2 = @adler32.bytes(test_data.to_bytes())
  inspect(adler1 == adler2, content="true")

  // Snapshot: Known values - let's see what they actually are
  let empty_adler = @adler32.bytes("".to_bytes())
  inspect(empty_adler, content="0x4848484848484849")
}
