// Main zipc module - combines deflate and zip functionality

// Re-export deflate functionality
pub typealias Crc32 = @deflate.Crc32
pub typealias Adler32 = @deflate.Adler32
pub typealias Level = @deflate.Level
pub typealias Result[T, E] = @deflate.Result[T, E]

// Re-export ZIP functionality
pub typealias Compression = @zip.Compression
pub typealias File = @zip.File
pub typealias Member = @zip.Member
pub typealias Archive = @zip.Archive

// Archive operations
pub let empty = @zip.empty
pub let is_empty = @zip.is_empty
pub let mem = @zip.mem
pub let find = @zip.find
pub let add = @zip.add
pub let remove = @zip.remove
pub let member_count = @zip.member_count
pub let of_binary_string = @zip.of_binary_string
pub let to_binary_string = @zip.to_binary_string

// File operations
pub let stored_of_binary_string = @zip.stored_of_binary_string

// Member operations  
pub let member_make = @zip.member_make

// Utility functions
pub fn[T, E] ok(value : T) -> Result[T, E] {
  @deflate.ok(value)
}

pub fn[T, E] err(error : E) -> Result[T, E] {
  @deflate.err(error)
}