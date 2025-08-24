// Gzip format support - deflate with gzip headers and CRC-32
// RFC 1952: GZIP file format specification

// Gzip compressed data structure

///|
pub struct GzipData {
  compressed_bytes : String
  original_size : Int
  crc32_checksum : @crc32.Crc32
  filename : String?
  comment : String?
  modification_time : Int // Unix timestamp
}

// Gzip header flags

///|
let _ftext_flag : Int = 0x01 // File is probably ASCII text

///|
let fhcrc_flag : Int = 0x02 // Header CRC present

///|
let fextra_flag : Int = 0x04 // Extra fields present

///|
let fname_flag : Int = 0x08 // Original filename present

///|
let fcomment_flag : Int = 0x10 // Comment present

// Compress data using gzip format (deflate + gzip headers + CRC-32)

///|
pub fn gzip_compress(
  data : String,
  level : Level,
  filename : String?,
  comment : String?,
  modification_time : Int,
) -> Result[GzipData, String] {
  // Calculate CRC-32 of original data
  let crc = @crc32.bytes(data.to_bytes())

  // Compress using deflate
  match deflate_compress(data.to_bytes(), level) {
    Ok(deflate_data) => {
      // Build gzip header
      let mut header = ""

      // Magic number (2 bytes): 0x1f, 0x8b
      header = header + "\u{1f}\u{8b}"

      // Compression method (1 byte): 8 for deflate
      header = header + "\u{08}"

      // Flags (1 byte)
      let mut flags = 0
      match filename {
        Some(_) => flags = flags | fname_flag
        None => ()
      }
      match comment {
        Some(_) => flags = flags | fcomment_flag
        None => ()
      }
      header = header + flags.unsafe_to_char().to_string()

      // Modification time (4 bytes, little-endian)
      header = header + write_u32_le(modification_time)

      // Extra flags (1 byte)
      let extra_flags = match level {
        Level::Best => 2 // Maximum compression
        Level::Fast => 4 // Fastest compression
        _ => 0 // Default
      }
      header = header + extra_flags.unsafe_to_char().to_string()

      // Operating system (1 byte): 255 for unknown
      header = header + "\u{ff}"

      // Optional filename (null-terminated)
      match filename {
        Some(name) => header = header + name + "\u{00}"
        None => ()
      }

      // Optional comment (null-terminated)
      match comment {
        Some(comm) => header = header + comm + "\u{00}"
        None => ()
      }

      // Build trailer: CRC-32 (4 bytes) + original size (4 bytes), both little-endian
      let trailer = write_u32_le(crc.0.to_int()) + write_u32_le(data.length())

      // Combine header + deflate data + trailer
      let gzip_bytes = header +
        deflate_data.compressed_bytes.to_string() +
        trailer
      Ok({
        compressed_bytes: gzip_bytes,
        original_size: data.length(),
        crc32_checksum: crc,
        filename,
        comment,
        modification_time,
      })
    }
    Err(error) => Err("Gzip compression failed: " + error)
  }
}

// Decompress gzip data

///|
pub fn gzip_decompress(gzip_data : GzipData) -> Result[String, String] {
  let data = gzip_data.compressed_bytes
  if data.length() < 18 { // Minimum: 10-byte header + 8-byte trailer
    return Err("Gzip data too short (minimum 18 bytes)")
  }

  // Parse gzip header
  let mut offset = 0

  // Check magic number
  if data[offset] != 0x1f || data[offset + 1] != 0x8b {
    return Err("Invalid gzip magic number")
  }
  offset = offset + 2

  // Check compression method
  if data[offset] != 8 {
    return Err("Unsupported compression method: " + data[offset].to_string())
  }
  offset = offset + 1

  // Read flags
  let flags = data[offset]
  offset = offset + 1

  // Skip modification time (4 bytes)
  offset = offset + 4

  // Skip extra flags (1 byte)
  offset = offset + 1

  // Skip operating system (1 byte)
  offset = offset + 1

  // Skip extra fields if present
  if (flags & fextra_flag) != 0 {
    if offset + 2 > data.length() {
      return Err("Truncated gzip extra fields")
    }
    let extra_len = gzip_read_u16_le(data, offset)
    offset = offset + 2 + extra_len
    if offset > data.length() {
      return Err("Truncated gzip extra fields data")
    }
  }

  // Skip filename if present
  if (flags & fname_flag) != 0 {
    while offset < data.length() && data[offset] != 0 {
      offset = offset + 1
    }
    if offset >= data.length() {
      return Err("Truncated gzip filename")
    }
    offset = offset + 1 // Skip null terminator
  }

  // Skip comment if present
  if (flags & fcomment_flag) != 0 {
    while offset < data.length() && data[offset] != 0 {
      offset = offset + 1
    }
    if offset >= data.length() {
      return Err("Truncated gzip comment")
    }
    offset = offset + 1 // Skip null terminator
  }

  // Skip header CRC if present
  if (flags & fhcrc_flag) != 0 {
    offset = offset + 2
    if offset > data.length() {
      return Err("Truncated gzip header CRC")
    }
  }

  // Extract deflate data (everything except trailer)
  if offset + 8 > data.length() {
    return Err("Truncated gzip trailer")
  }
  let deflate_end = data.length() - 8
  let deflate_bytes = data.substring(start=offset, end=deflate_end)

  // Extract trailer: CRC-32 and original size
  let expected_crc = read_u32_le(data, deflate_end).to_int64()
  let expected_size = read_u32_le(data, deflate_end + 4)

  // Decompress deflate data
  let _deflate_data : DeflateData = {
    compressed_bytes: deflate_bytes.to_bytes(),
    original_size: expected_size,
    adler32_checksum: 0L, // Gzip uses CRC-32, not Adler-32
  }

  // Use bytes-based deflate decompression to avoid String conversion corruption
  match decompress_deflate_blocks_bytes(deflate_bytes.to_bytes()) {
    Ok(decompressed_bytes) => {
      let decompressed = decompressed_bytes.to_string()
      // Verify size
      if decompressed.length() != expected_size {
        return Err(
          "Gzip size mismatch: expected " +
          expected_size.to_string() +
          ", got " +
          decompressed.length().to_string(),
        )
      }

      // Verify CRC-32 checksum
      let computed_crc = @crc32.bytes(decompressed.to_bytes())
      if computed_crc != expected_crc {
        return Err("Gzip CRC-32 checksum mismatch")
      }
      Ok(decompressed)
    }
    Err(error) => Err("Deflate decompression failed: " + error)
  }
}

// Helper function to write 32-bit little-endian integer

///|
fn write_u32_le(value : Int) -> String {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  let b2 = (value >> 16) & 0xff
  let b3 = (value >> 24) & 0xff
  b0.unsafe_to_char().to_string() +
  b1.unsafe_to_char().to_string() +
  b2.unsafe_to_char().to_string() +
  b3.unsafe_to_char().to_string()
}

// Helper function to read 16-bit little-endian integer (gzip version)

///|
fn gzip_read_u16_le(data : String, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset]
  let b1 = data[offset + 1]
  b0 + (b1 << 8)
}

// Helper function to read 32-bit little-endian integer

///|
fn read_u32_le(data : String, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset]
  let b1 = data[offset + 1]
  let b2 = data[offset + 2]
  let b3 = data[offset + 3]
  b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
}

// Create gzip-compressed file data (convenience function)

///|
pub fn gzip_of_binary_string(
  s : String,
  level : Level,
  filename : String?,
  comment : String?,
) -> Result[String, String] {
  match gzip_compress(s, level, filename, comment, 0) {
    Ok(gzip_data) => Ok(gzip_data.compressed_bytes)
    Err(error) => Err("Gzip compression failed: " + error)
  }
}

// Extract gzip-compressed data (convenience function)

///|
pub fn gzip_to_binary_string(
  compressed_data : String,
) -> Result[String, String] {
  let gzip_data : GzipData = {
    compressed_bytes: compressed_data,
    original_size: 0, // Will be read from trailer
    crc32_checksum: @crc32.Crc32(0L), // Will be read from trailer
    filename: None,
    comment: None,
    modification_time: 0,
  }
  gzip_decompress(gzip_data)
}

// Bytes-based gzip functions (more efficient for binary data)

///|
pub fn gzip_of_bytes(
  data : Bytes,
  level : Level,
  filename : String?,
  comment : String?,
) -> Result[Bytes, String] {
  // Use the existing string-based implementation and convert
  // In a full implementation, this would work directly with bytes
  let string_data = data.to_string()
  match gzip_of_binary_string(string_data, level, filename, comment) {
    Ok(compressed_string) => Ok(compressed_string.to_bytes())
    Err(error) => Err(error)
  }
}

///|
pub fn gzip_to_bytes(compressed_data : Bytes) -> Result[Bytes, String] {
  // Use the existing string-based implementation and convert
  // In a full implementation, this would work directly with bytes
  let string_data = compressed_data.to_string()
  match gzip_to_binary_string(string_data) {
    Ok(decompressed_string) => Ok(decompressed_string.to_bytes())
    Err(error) => Err(error)
  }
}

// Extract metadata from gzip file

///|
pub fn gzip_extract_metadata(
  compressed_data : String,
) -> Result[GzipData, String] {
  if compressed_data.length() < 18 {
    return Err("Gzip data too short")
  }
  let mut offset = 0

  // Check magic number
  if compressed_data[offset] != 0x1f || compressed_data[offset + 1] != 0x8b {
    return Err("Invalid gzip magic number")
  }
  offset = offset + 2

  // Skip compression method
  offset = offset + 1

  // Read flags
  let flags = compressed_data[offset]
  offset = offset + 1

  // Read modification time
  let mtime = read_u32_le(compressed_data, offset)
  offset = offset + 4

  // Skip extra flags and OS
  offset = offset + 2

  // Skip extra fields if present
  if (flags & fextra_flag) != 0 {
    let extra_len = gzip_read_u16_le(compressed_data, offset)
    offset = offset + 2 + extra_len
  }

  // Read filename if present
  let mut filename : String? = None
  if (flags & fname_flag) != 0 {
    let start = offset
    while offset < compressed_data.length() && compressed_data[offset] != 0 {
      offset = offset + 1
    }
    if offset < compressed_data.length() {
      filename = Some(compressed_data.substring(start~, end=offset))
      offset = offset + 1
    }
  }

  // Read comment if present
  let mut comment : String? = None
  if (flags & fcomment_flag) != 0 {
    let start = offset
    while offset < compressed_data.length() && compressed_data[offset] != 0 {
      offset = offset + 1
    }
    if offset < compressed_data.length() {
      comment = Some(compressed_data.substring(start~, end=offset))
      offset = offset + 1
    }
  }

  // Read trailer
  let trailer_offset = compressed_data.length() - 8
  let crc = read_u32_le(compressed_data, trailer_offset).to_int64()
  let original_size = read_u32_le(compressed_data, trailer_offset + 4)
  Ok({
    compressed_bytes: compressed_data,
    original_size,
    crc32_checksum: crc,
    filename,
    comment,
    modification_time: mtime,
  })
}
