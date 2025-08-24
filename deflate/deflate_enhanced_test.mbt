// Enhanced tests for deflate functionality including new BlockType features

///|
test "block type conversion functions" {
  // Test block_type_to_btype function (internal)
  // We can't directly test the private functions, but we can test their effects
  // through the compression/decompression process
  
  let test_data = "Block type test data"
  let level = @deflate.level_none() // Uses Uncompressed blocks
  
  match @deflate.deflate_of_binary_string(test_data, level) {
    @deflate.Ok(compressed) => {
      // Verify we can decompress data that was compressed with Uncompressed blocks
      match @deflate.deflate_decompress_raw_string(compressed, test_data.length()) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed, content=test_data)
          // Snapshot: Uncompressed blocks should work correctly
          inspect(decompressed == test_data, content="true")
        }
        @deflate.Err(error) => fail("Decompression of uncompressed blocks failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Compression with uncompressed blocks failed: " + error)
  }
}

///|
test "deflate error handling edge cases" {
  // Test empty data compression
  match @deflate.deflate_of_binary_string("", @deflate.level_none()) {
    @deflate.Ok(compressed) => {
      // Empty data should compress to empty
      inspect(compressed.length(), content="0")
      
      // And decompress back to empty
      match @deflate.deflate_decompress_raw_string(compressed, 0) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed, content="")
          inspect(decompressed.length(), content="0")
        }
        @deflate.Err(error) => fail("Empty data decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Empty data compression failed: " + error)
  }
  
  // Test decompression with invalid data
  match @deflate.deflate_decompress_raw_string("invalid_deflate_data", 10) {
    @deflate.Ok(_) => fail("Should have failed on invalid deflate data")
    @deflate.Err(error) => {
      // Should get a meaningful error message
      inspect(error.length() > 0, content="true")
    }
  }
}

///|
test "large data handling" {
  // Test with data larger than a single block (65535 bytes)
  let large_data = String::make(70000, 'A') // 70KB of 'A' characters
  
  match @deflate.deflate_of_binary_string(large_data, @deflate.level_none()) {
    @deflate.Ok(compressed) => {
      // Large data should be split into multiple blocks
      inspect(compressed.length() > 0, content="true")
      
      // Should decompress correctly
      match @deflate.deflate_decompress_raw_string(compressed, large_data.length()) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed.length(), content="70000")
          inspect(decompressed == large_data, content="true")
        }
        @deflate.Err(error) => fail("Large data decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Large data compression failed: " + error)
  }
}

///|
test "compression level consistency" {
  let test_data = "Compression level test data with some repeated patterns patterns patterns"
  
  // Test all compression levels produce valid output
  let levels = [
    @deflate.level_none(),
    @deflate.level_fast(), 
    @deflate.level_default(),
    @deflate.level_best()
  ]
  
  for i = 0; i < levels.length(); i = i + 1 {
    let level = levels[i]
    match @deflate.deflate_of_binary_string(test_data, level) {
      @deflate.Ok(compressed) => {
        // All levels should produce some output
        inspect(compressed.length() >= 0, content="true")
        
        // All should decompress correctly
        match @deflate.deflate_decompress_raw_string(compressed, test_data.length()) {
          @deflate.Ok(decompressed) => {
            inspect(decompressed == test_data, content="true")
          }
          @deflate.Err(error) => fail("Level " + i.to_string() + " decompression failed: " + error)
        }
      }
      @deflate.Err(error) => fail("Level " + i.to_string() + " compression failed: " + error)
    }
  }
}

///|
test "deflate data structure integrity" {
  let test_data = "Data structure test"
  let level = @deflate.level_none()
  
  // Test the full deflate_compress -> deflate_decompress cycle
  match @deflate.deflate_compress(test_data.to_bytes(), level) {
    @deflate.Ok(deflate_data) => {
      // Verify the structure has the expected fields
      // Note: original_size should be the byte length, not string length
      inspect(deflate_data.original_size, content=test_data.to_bytes().length().to_string())
      inspect(deflate_data.compressed_bytes.length() >= 0, content="true")
      
      // Test decompression with the full structure
      match @deflate.deflate_decompress(deflate_data) {
        @deflate.Ok(decompressed) => {
          // Compare bytes directly since String<->Bytes conversion is not lossless
          let original_bytes = test_data.to_bytes()
          inspect(decompressed.length(), content=original_bytes.length().to_string())
          inspect(decompressed == original_bytes, content="true")
        }
        @deflate.Err(error) => fail("Full deflate decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Full deflate compression failed: " + error)
  }
}

///|
test "binary data handling" {
  // Test with binary data (non-text)
  let binary_data = "\u{00}\u{01}\u{02}\u{03}\u{ff}\u{fe}\u{fd}\u{fc}"
  
  match @deflate.deflate_of_binary_string(binary_data, @deflate.level_none()) {
    @deflate.Ok(compressed) => {
      match @deflate.deflate_decompress_raw_string(compressed, binary_data.length()) {
        @deflate.Ok(decompressed) => {
          // Binary data should be preserved exactly
          inspect(decompressed == binary_data, content="true")
          inspect(decompressed.length(), content=binary_data.length().to_string())
        }
        @deflate.Err(error) => fail("Binary data decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Binary data compression failed: " + error)
  }
}
