// ZIP archive types and structures

// Compression formats supported by ZIP
pub enum Compression {
  Bzip2
  Deflate     // Via deflate module
  Lzma
  Stored      // No compression
  Xz
  Zstd
  Other(Int)  // Unknown compression method
}

// File paths and modes
pub typealias String as Fpath
pub typealias Int as Mode

// POSIX time (seconds since Unix epoch)
pub typealias Int as Ptime

// File data structure
pub struct File {
  compression : Compression
  start : Int
  compressed_size : Int
  compressed_bytes : String
  decompressed_size : Int
  decompressed_crc32 : Int64  // Using Int64 directly for now
  version_made_by : Int
  version_needed_to_extract : Int
  gp_flags : Int
}

// Member kinds
pub enum MemberKind {
  Dir                 // Directory member
  File(File)         // File member
}

// Archive member
pub struct Member {
  path : Fpath
  mode : Mode
  mtime : Ptime
  kind : MemberKind
}

// ZIP archive
pub struct Archive {
  members : Array[Member]
}

// Constants
pub let dos_epoch : Ptime = 315532800  // 1980-01-01 00:00:00 UTC
pub let max_file_size : Int = 2147483647  // Use max int instead of 4GB
pub let max_members : Int = 65535  // ZIP32 limit
pub let max_path_length : Int = 65535