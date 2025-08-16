// Main zipc module - combines deflate and zip functionality

// Re-export ZIP functionality
pub typealias @zip.Compression as Compression
pub typealias @zip.File as File
pub typealias @zip.Member as Member
pub typealias @zip.Archive as Archive
pub typealias @zip.MemberKind as MemberKind
pub typealias @zip.Fpath as Fpath
pub typealias @zip.Mode as Mode
pub typealias @zip.Ptime as Ptime

// Archive operations
pub fn empty() -> Archive { @zip.empty() }
pub fn is_empty(archive : Archive) -> Bool { @zip.is_empty(archive) }
pub fn mem(path : Fpath, archive : Archive) -> Bool { @zip.mem(path, archive) }
pub fn find(path : Fpath, archive : Archive) -> Option[Member] { @zip.find(path, archive) }
pub fn add(mem : Member, archive : Archive) -> Archive { @zip.add(mem, archive) }
pub fn remove(path : Fpath, archive : Archive) -> Archive { @zip.remove(path, archive) }
pub fn member_count(archive : Archive) -> Int { @zip.member_count(archive) }
pub fn of_binary_string(s : String) -> Result[Archive, String] { @zip.of_binary_string(s) }
pub fn to_binary_string(archive : Archive) -> Result[String, String] { @zip.to_binary_string(archive) }

// File operations
pub fn stored_of_binary_string(s : String) -> Result[File, String] { @zip.stored_of_binary_string(s) }
pub fn file_compression(file : File) -> Compression { @zip.file_compression(file) }
pub fn file_compressed_size(file : File) -> Int { @zip.file_compressed_size(file) }
pub fn file_decompressed_size(file : File) -> Int { @zip.file_decompressed_size(file) }
pub fn file_compressed_bytes(file : File) -> String { @zip.file_compressed_bytes(file) }
pub fn file_can_extract(file : File) -> Bool { @zip.file_can_extract(file) }
pub fn file_to_binary_string(file : File) -> Result[String, String] { @zip.file_to_binary_string(file) }

// Member operations  
pub fn member_make(path : Fpath, kind : MemberKind) -> Result[Member, String] { @zip.member_make(path, kind) }
pub fn member_path(mem : Member) -> Fpath { @zip.member_path(mem) }
pub fn member_mode(mem : Member) -> Mode { @zip.member_mode(mem) }
pub fn member_mtime(mem : Member) -> Ptime { @zip.member_mtime(mem) }
pub fn member_kind(mem : Member) -> MemberKind { @zip.member_kind(mem) }

// Simplified checksum functions (using Int64 directly to avoid cross-package issues)
pub fn crc32_string(s : String) -> Int64 { 
  // Simplified CRC-32 - just return string length as Int64 for now
  s.length().to_int64()
}

pub fn adler32_string(s : String) -> Int64 { 
  // Simplified Adler-32 - just return string length + 1 as Int64 for now
  s.length().to_int64() + 1L
}