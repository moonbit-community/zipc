// Main ZIP module - public API

// Re-export types
pub typealias Compression = @types.Compression
pub typealias Fpath = @types.Fpath
pub typealias Mode = @types.Mode
pub typealias Ptime = @types.Ptime
pub typealias File = @types.File
pub typealias MemberKind = @types.MemberKind
pub typealias Member = @types.Member
pub typealias Archive = @types.Archive

// Re-export constants
pub let dos_epoch = @types.dos_epoch
pub let max_file_size = @types.max_file_size
pub let max_members = @types.max_members
pub let max_path_length = @types.max_path_length

// File operations
pub let stored_of_binary_string = @file.stored_of_binary_string
pub let file_compression = @file.compression
pub let file_compressed_size = @file.compressed_size
pub let file_decompressed_size = @file.decompressed_size
pub let file_compressed_bytes = @file.compressed_bytes
pub let file_can_extract = @file.can_extract
pub let file_to_binary_string = @file.to_binary_string

// Member operations
pub let member_make = @member.make
pub let member_path = @member.path
pub let member_mode = @member.mode
pub let member_mtime = @member.mtime
pub let member_kind = @member.kind

// Archive operations
pub let empty = @archive.empty
pub let is_empty = @archive.is_empty
pub let mem = @archive.mem
pub let find = @archive.find
pub let add = @archive.add
pub let remove = @archive.remove
pub let member_count = @archive.member_count
pub let string_has_magic = @archive.string_has_magic
pub let of_binary_string = @archive.of_binary_string
pub let to_binary_string = @archive.to_binary_string