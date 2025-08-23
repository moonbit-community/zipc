// Zlib format support - deflate with headers and checksums
// RFC 1950: ZLIB Compressed Data Format Specification

// Zlib compressed data structure
///|
pub struct ZlibData {
  compressed_bytes : String
  original_size : Int
  adler32_checksum : Adler32
}

// Compress data using zlib format (deflate + headers + checksum)

///|
pub fn zlib_compress(data : String, level : Level) -> Result[ZlibData, String] {
  // Calculate Adler-32 of original data
  let adler = adler32_string(data)

  // Compress using deflate
  match deflate_compress(data.to_bytes(), level) {
    Ok(deflate_data) => {
      // Create zlib header (2 bytes)
      let compression_method = 8 // Deflate
      let compression_info = 7 // 32K window size
      let cmf = compression_method | (compression_info << 4)
      let fcheck = 0 // Will be calculated
      let fdict = 0 // No preset dictionary
      let flevel = match level {
        Level::None => 0 // Fastest
        Level::Fast => 1 // Fast
        Level::Default => 2 // Default
        Level::Best => 3 // Maximum compression
      }
      let flg = (flevel << 6) | (fdict << 5) | fcheck

      // Calculate FCHECK to make (CMF*256 + FLG) divisible by 31
      let header_base = cmf * 256 + flg
      let fcheck_calculated = (31 - header_base % 31) % 31
      let flg_final = (flg & 0xe0) | fcheck_calculated

      // Build zlib data: header + deflate data + adler32
      let header = write_u16_be(cmf * 256 + flg_final)
      let adler_bytes = write_u32_be(adler.to_int())
      let zlib_bytes = header + deflate_data.compressed_bytes.to_string() + adler_bytes
      Ok({
        compressed_bytes: zlib_bytes,
        original_size: data.length(),
        adler32_checksum: adler,
      })
    }
    Err(error) => Err("Zlib compression failed: " + error)
  }
}

// Decompress zlib data

///|
pub fn zlib_decompress(zlib_data : ZlibData) -> Result[String, String] {
  let data = zlib_data.compressed_bytes
  if data.length() < 6 {
    return Err("Zlib data too short (minimum 6 bytes)")
  }

  // Parse zlib header (2 bytes)
  let cmf = data[0]
  let flg = data[1]

  // Verify header checksum
  let header_check = (cmf * 256 + flg) % 31
  if header_check != 0 {
    return Err("Invalid zlib header checksum")
  }

  // Extract compression method and info
  let compression_method = cmf & 0x0f
  let compression_info = (cmf >> 4) & 0x0f
  if compression_method != 8 {
    return Err(
      "Unsupported compression method: " + compression_method.to_string(),
    )
  }
  if compression_info > 7 {
    return Err("Invalid compression info: " + compression_info.to_string())
  }

  // Check for preset dictionary (not supported)
  let fdict = (flg >> 5) & 1
  if fdict != 0 {
    return Err("Preset dictionaries not supported")
  }

  // Extract deflate data (everything except header and trailing checksum)
  let deflate_start = 2
  let deflate_end = data.length() - 4
  let deflate_bytes = data.substring(start=deflate_start, end=deflate_end)

  // Extract Adler-32 checksum (last 4 bytes, big-endian)
  let adler_bytes = data.substring(start=deflate_end, end=data.length())
  let expected_adler = read_u32_be(adler_bytes, 0).to_int64()

  // Decompress deflate data
  let deflate_data : DeflateData = {
    compressed_bytes: deflate_bytes.to_bytes(),
    original_size: zlib_data.original_size,
    adler32_checksum: expected_adler,
  }
  match deflate_decompress(deflate_data) {
    Ok(decompressed) => {
      // Verify Adler-32 checksum
      let computed_adler = adler32_bytes(decompressed)
      if adler32_equal(computed_adler, expected_adler) {
        Ok(decompressed.to_string())
      } else {
        Err("Adler-32 checksum mismatch in zlib data")
      }
    }
    Err(error) => Err("Deflate decompression failed: " + error)
  }
}

// Helper function to write 16-bit big-endian integer

///|
fn write_u16_be(value : Int) -> String {
  let b0 = (value >> 8) & 0xff
  let b1 = value & 0xff
  b0.unsafe_to_char().to_string() + b1.unsafe_to_char().to_string()
}

// Helper function to write 32-bit big-endian integer

///|
fn write_u32_be(value : Int) -> String {
  let b0 = (value >> 24) & 0xff
  let b1 = (value >> 16) & 0xff
  let b2 = (value >> 8) & 0xff
  let b3 = value & 0xff
  b0.unsafe_to_char().to_string() +
  b1.unsafe_to_char().to_string() +
  b2.unsafe_to_char().to_string() +
  b3.unsafe_to_char().to_string()
}

// Helper function to read 32-bit big-endian integer

///|
fn read_u32_be(data : String, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset]
  let b1 = data[offset + 1]
  let b2 = data[offset + 2]
  let b3 = data[offset + 3]
  (b0 << 24) + (b1 << 16) + (b2 << 8) + b3
}

// Create zlib-compressed file data for ZIP (if needed)

///|
pub fn zlib_of_binary_string(
  s : String,
  level : Level,
) -> Result[String, String] {
  match zlib_compress(s, level) {
    Ok(zlib_data) => Ok(zlib_data.compressed_bytes)
    Err(error) => Err("Zlib compression failed: " + error)
  }
}

// Extract zlib-compressed data

///|
pub fn zlib_to_binary_string(
  compressed_data : String,
  original_size : Int,
) -> Result[String, String] {
  let zlib_data : ZlibData = {
    compressed_bytes: compressed_data,
    original_size,
    adler32_checksum: 0L,
  } // Will be read from data
  zlib_decompress(zlib_data)
}

// Bytes-based zlib functions (more efficient for binary data)

///|
pub fn zlib_of_bytes(
  data : Bytes,
  level : Level,
) -> Result[Bytes, String] {
  // Use the existing string-based implementation and convert
  // In a full implementation, this would work directly with bytes
  let string_data = data.to_string()
  match zlib_of_binary_string(string_data, level) {
    Ok(compressed_string) => Ok(compressed_string.to_bytes())
    Err(error) => Err(error)
  }
}

///|
pub fn zlib_to_bytes(
  compressed_data : Bytes,
  original_size : Int,
) -> Result[Bytes, String] {
  // Use the existing string-based implementation and convert
  // In a full implementation, this would work directly with bytes
  let string_data = compressed_data.to_string()
  match zlib_to_binary_string(string_data, original_size) {
    Ok(decompressed_string) => Ok(decompressed_string.to_bytes())
    Err(error) => Err(error)
  }
}
