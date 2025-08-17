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
pub fn of_binary_string(s : String) -> @deflate.Result[Archive, String] { @zip.of_binary_string(s) }
pub fn to_binary_string(archive : Archive) -> @deflate.Result[String, String] { @zip.to_binary_string(archive) }

// File operations
pub fn stored_of_binary_string(s : String) -> @deflate.Result[File, String] { @zip.stored_of_binary_string(s) }
pub fn file_compression(file : File) -> Compression { @zip.file_compression(file) }
pub fn file_compressed_size(file : File) -> Int { @zip.file_compressed_size(file) }
pub fn file_decompressed_size(file : File) -> Int { @zip.file_decompressed_size(file) }
pub fn file_compressed_bytes(file : File) -> String { @zip.file_compressed_bytes(file) }
pub fn file_can_extract(file : File) -> Bool { @zip.file_can_extract(file) }
pub fn file_to_binary_string(file : File) -> @deflate.Result[String, String] { @zip.file_to_binary_string(file) }

// Member operations  
pub fn member_make(path : Fpath, kind : MemberKind) -> @deflate.Result[Member, String] { @zip.member_make(path, kind) }
pub fn member_path(mem : Member) -> Fpath { @zip.member_path(mem) }
pub fn member_mode(mem : Member) -> Mode { @zip.member_mode(mem) }
pub fn member_mtime(mem : Member) -> Ptime { @zip.member_mtime(mem) }
pub fn member_kind(mem : Member) -> MemberKind { @zip.member_kind(mem) }

// Re-export deflate functionality
pub typealias @deflate.Crc32 as Crc32
pub typealias @deflate.Adler32 as Adler32
pub typealias @deflate.Level as Level

// Checksum functions
pub fn crc32_string(s : String) -> Crc32 { @deflate.crc32_string(s) }
pub fn crc32_equal(c1 : Crc32, c2 : Crc32) -> Bool { @deflate.crc32_equal(c1, c2) }
pub fn crc32_to_hex(crc : Crc32) -> String { @deflate.crc32_to_hex(crc) }
pub fn crc32_check(expect : Crc32, found : Crc32) -> @deflate.Result[Unit, String] { @deflate.crc32_check(expect, found) }

pub fn adler32_string(s : String) -> Adler32 { @deflate.adler32_string(s) }
pub fn adler32_equal(a1 : Adler32, a2 : Adler32) -> Bool { @deflate.adler32_equal(a1, a2) }
pub fn adler32_to_hex(adler : Adler32) -> String { @deflate.adler32_to_hex(adler) }
pub fn adler32_check(expect : Adler32, found : Adler32) -> @deflate.Result[Unit, String] { @deflate.adler32_check(expect, found) }