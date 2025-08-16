// File operations for ZIP archives

// Create file data from stored (uncompressed) string
pub fn stored_of_binary_string(s : String) -> @deflate.Result[@types.File, String] {
  let actual_len = s.length()
  
  if actual_len > @types.max_file_size {
    return @deflate.err("File size exceeds maximum")
  }
  
  let crc32 = @deflate.crc32_string(s)
  
  let file = @types.File::{
    compression: @types.Compression::Stored,
    start: 0,
    compressed_size: actual_len,
    compressed_bytes: s,
    decompressed_size: actual_len,
    decompressed_crc32: crc32,
    version_made_by: 0x314,  // UNIX + PKZIP 2.0
    version_needed_to_extract: 20,  // PKZIP 2.0
    gp_flags: 0x800  // UTF-8 filenames
  }
  
  @deflate.ok(file)
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
      @deflate.err("Deflate decompression not yet implemented")
    }
    _ => @deflate.err("Unsupported compression format")
  }
}