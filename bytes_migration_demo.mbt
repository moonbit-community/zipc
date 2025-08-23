// Demonstration of Bytes-based API migration
// This file shows how the architecture should be migrated from String to Bytes

// New Bytes-based data structures
///|
pub struct BytesFile {
  compression : Compression
  start : Int
  compressed_size : Int
  compressed_bytes : Bytes  // ✅ Using Bytes instead of String
  decompressed_size : Int
  decompressed_crc32 : Int64
  version_made_by : Int
  version_needed_to_extract : Int
  gp_flags : Int
}

// New Bytes-based binary utilities
///|
fn bytes_read_u16_le(data : Bytes, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  b0 + (b1 << 8)
}

///|
fn bytes_read_u32_le(data : Bytes, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
}

///|
fn bytes_write_u16_le(value : Int) -> Bytes {
  let b0 = (value & 0xff).to_byte()
  let b1 = ((value >> 8) & 0xff).to_byte()
  Bytes::from_array([b0, b1])
}

///|
fn bytes_write_u32_le(value : Int) -> Bytes {
  let b0 = (value & 0xff).to_byte()
  let b1 = ((value >> 8) & 0xff).to_byte()
  let b2 = ((value >> 16) & 0xff).to_byte()
  let b3 = ((value >> 24) & 0xff).to_byte()
  Bytes::from_array([b0, b1, b2, b3])
}

// New Bytes-based API functions
///|
pub fn stored_of_bytes(data : Bytes) -> @deflate.Result[BytesFile, String] {
  let len = data.length()
  if len > max_file_size {
    return @deflate.err(
      "File size exceeds maximum allowed (" +
      max_file_size.to_string() +
      " bytes)",
    )
  }

  // Calculate actual CRC-32 checksum on bytes
  let crc = crc32_bytes(data)  // This would need to be implemented
  @deflate.ok({
    compression: Compression::Stored,
    start: 0,
    compressed_size: len,
    compressed_bytes: data,  // ✅ Direct Bytes storage
    decompressed_size: len,
    decompressed_crc32: crc,
    version_made_by: 0x314,
    version_needed_to_extract: 20,
    gp_flags: 0x800,
  })
}

///|
pub fn deflate_of_bytes(
  data : Bytes,
  level : @deflate.Level,
) -> @deflate.Result[BytesFile, String] {
  let len = data.length()
  if len > max_file_size {
    return @deflate.err(
      "File size exceeds maximum allowed (" +
      max_file_size.to_string() +
      " bytes)",
    )
  }

  // Compress using deflate on bytes
  match deflate_compress_bytes(data, level) {  // This would need to be implemented
    @deflate.Ok(compressed_data) => {
      let crc = crc32_bytes(data)
      @deflate.ok({
        compression: Compression::Deflate,
        start: 0,
        compressed_size: compressed_data.length(),
        compressed_bytes: compressed_data,  // ✅ Direct Bytes storage
        decompressed_size: len,
        decompressed_crc32: crc,
        version_made_by: 0x314,
        version_needed_to_extract: 20,
        gp_flags: 0x800,
      })
    }
    @deflate.Err(error) => @deflate.err("Deflate compression failed: " + error)
  }
}

///|
pub fn file_to_bytes(file : BytesFile) -> @deflate.Result[Bytes, String] {
  if not(file_can_extract_bytes(file)) {
    return @deflate.err("Unsupported compression format")
  }
  match file.compression {
    Compression::Stored => {
      // ✅ Direct bytes slicing - much cleaner than string operations
      // let data = file.compressed_bytes.sub_bytes(
      //   start=file.start,
      //   end=file.start + file.compressed_size,
      // )
      // For now, just return the full compressed bytes as placeholder
      let data = file.compressed_bytes
      @deflate.ok(data)
    }
    Compression::Deflate =>
      // ✅ Direct bytes decompression
      deflate_decompress_bytes(
        file.compressed_bytes,
        file.decompressed_size,
      )
    _ => @deflate.err("Unsupported compression format")
  }
}

// Helper functions that would need to be implemented
fn file_can_extract_bytes(file : BytesFile) -> Bool {
  match file.compression {
    Compression::Stored => true
    Compression::Deflate => true
    _ => false
  }
}

// Placeholder functions that would need to be implemented in deflate module
fn crc32_bytes(data : Bytes) -> Int64 {
  // This would replace crc32_string and work directly on bytes
  // Much more efficient - no UTF-16 overhead
  0L  // Placeholder
}

fn deflate_compress_bytes(data : Bytes, level : @deflate.Level) -> @deflate.Result[Bytes, String] {
  // This would replace deflate_of_binary_string
  // Direct bytes-to-bytes compression - no string conversion overhead
  @deflate.err("Not implemented yet")  // Placeholder
}

fn deflate_decompress_bytes(
  compressed_data : Bytes,
  original_size : Int,
) -> @deflate.Result[Bytes, String] {
  // This would replace deflate_decompress_string
  // Direct bytes-to-bytes decompression - no string conversion overhead
  @deflate.err("Not implemented yet")  // Placeholder
}

// Migration benefits demonstration
///|
pub fn demonstrate_migration_benefits() -> String {
  let benefits = [
    "1. Performance: No UTF-16 encoding/decoding overhead",
    "2. Memory: Direct byte operations use less memory",
    "3. Correctness: Proper handling of arbitrary binary data",
    "4. API Clarity: Clear distinction between text and binary data",
    "5. Safety: No risk of invalid UTF-16 sequences in binary data"
  ]
  
  let mut result = "Migration Benefits:\n"
  for benefit in benefits {
    result = result + benefit + "\n"
  }
  result
}

// Example usage comparison
///|
pub fn usage_comparison_example() -> String {
  // OLD WAY (current):
  // let binary_data = "\u{00}\u{01}\u{02}\u{03}\u{ff}\u{fe}\u{fd}\u{fc}"  // Awkward
  // match stored_of_binary_string(binary_data) { ... }  // String-based, inefficient
  
  // NEW WAY (proposed):
  // let binary_data = Bytes::from_array([0, 1, 2, 3, 255, 254, 253, 252].map(fn(x) => x.to_byte()))  // Natural
  // match stored_of_bytes(binary_data) { ... }  // Bytes-based, efficient
  
  "See function comments for usage comparison"
}
