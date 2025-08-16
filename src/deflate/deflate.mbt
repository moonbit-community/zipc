// Main deflate module - public API

// Re-export types
pub typealias UInt16 = @types.UInt16
pub typealias UInt32 = @types.UInt32
pub typealias Level = @types.Level
pub typealias Result[T, E] = @types.Result[T, E]

// Re-export checksum types
pub typealias Crc32 = @crc32.Crc32
pub typealias Adler32 = @adler32.Adler32

// CRC-32 functions
pub let crc32_new = @crc32.new_crc32
pub let crc32_string = @crc32.string
pub let crc32_equal = @crc32.equal
pub let crc32_check = @crc32.check
pub let crc32_to_hex = @crc32.to_hex

// Adler-32 functions  
pub let adler32_new = @adler32.new_adler32
pub let adler32_string = @adler32.string
pub let adler32_equal = @adler32.equal
pub let adler32_check = @adler32.check
pub let adler32_to_hex = @adler32.to_hex

// Helper functions
pub fn[T, E] ok(value : T) -> Result[T, E] {
  @types.ok(value)
}

pub fn[T, E] err(error : E) -> Result[T, E] {
  @types.err(error)
}

pub fn[T, E] unwrap(result : Result[T, E]) -> T {
  @types.unwrap(result)
}

pub fn[T, E] unwrap_or(result : Result[T, E], default : T) -> T {
  @types.unwrap_or(result, default)
}

// Placeholder for inflate function - to be implemented
pub fn inflate(data : String, ~decompressed_size : Int = -1, ~start : Int = 0, ~len : Int = -1) -> Result[String, String] {
  // For now, return an error indicating not implemented
  err("Deflate decompression not yet implemented")
}