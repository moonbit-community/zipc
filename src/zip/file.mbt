// File operations for ZIP archives

// Create file data from stored (uncompressed) string
pub fn stored_of_binary_string(s : String, ~start : Int = 0, ~len : Int = -1) -> @deflate.Result[@types.File, String] {
  let actual_len = if len == -1 { s.length() - start } else { len }
  
  if actual_len > @types.max_file_size {
    return @deflate.err("File size exceeds maximum: \{actual_len}")
  }
  
  let data = s.substring(~start, ~end=start + actual_len)
  let crc32 = @deflate.crc32_string(data)
  
  let file = @types.File::{
    compression: @types.Compression::Stored,
    start: 0,
    compressed_size: actual_len,
    compressed_bytes: data,
    decompressed_size: actual_len,
    decompressed_crc32: crc32,
    version_made_by: 0x314,  // UNIX + PKZIP 2.0
    version_needed_to_extract: 20,  // PKZIP 2.0
    gp_flags: 0x800  // UTF-8 filenames
  }
  
  @deflate.ok(file)
}

// Create file data with deflate compression (placeholder)
pub fn deflate_of_binary_string(s : String, ~level : @deflate.Level = @deflate.Level::Default, ~start : Int = 0, ~len : Int = -1) -> @deflate.Result[@types.File, String] {
  // For now, fall back to stored format
  stored_of_binary_string(s, ~start, ~len)
}

// Get compression format of file
pub fn compression(file : @types.File) -> @types.Compression {
  file.compression
}

// Get compressed size
pub fn compressed_size(file : @types.File) -> Int {
  file.compressed_size
}

// Get decompressed size
pub fn decompressed_size(file : @types.File) -> Int {
  file.decompressed_size
}

// Get compressed bytes
pub fn compressed_bytes(file : @types.File) -> String {
  file.compressed_bytes
}

// Check if file can be extracted
pub fn can_extract(file : @types.File) -> Bool {
  match file.compression {
    @types.Compression::Stored => true
    @types.Compression::Deflate => true
    _ => false
  }
}

// Extract file to binary string
pub fn to_binary_string(file : @types.File) -> @deflate.Result[String, String] {
  match file.compression {
    @types.Compression::Stored => {
      // Verify CRC32
      let computed_crc = @deflate.crc32_string(file.compressed_bytes)
      if not(@deflate.crc32_equal(computed_crc, file.decompressed_crc32)) {
        return @deflate.err("CRC-32 mismatch")
      }
      @deflate.ok(file.compressed_bytes)
    }
    @types.Compression::Deflate => {
      // Placeholder - would use deflate decompression
      @deflate.err("Deflate decompression not yet implemented")
    }
    _ => @deflate.err("Unsupported compression format")
  }
}
