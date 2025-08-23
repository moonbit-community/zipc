// Deflate compression/decompression implementation
// This is a simplified implementation focusing on basic functionality

// Deflate block types
///|
priv enum BlockType {
  Uncompressed // No compression (BTYPE = 00)
  FixedHuffman // Compressed with fixed Huffman codes (BTYPE = 01)  
  DynamicHuffman // Compressed with dynamic Huffman codes (BTYPE = 10)
}

// Convert block type to BTYPE value
///|
fn block_type_to_btype(block_type : BlockType) -> Int {
  match block_type {
    BlockType::Uncompressed => 0
    BlockType::FixedHuffman => 1
    BlockType::DynamicHuffman => 2
  }
}

// Convert BTYPE value to block type
///|
fn btype_to_block_type(btype : Int) -> BlockType? {
  match btype {
    0 => Some(BlockType::Uncompressed)
    1 => Some(BlockType::FixedHuffman)
    2 => Some(BlockType::DynamicHuffman)
    _ => None
  }
}

// Deflate compressed data structure

///|
pub struct DeflateData {
  compressed_bytes : Bytes
  original_size : Int
  adler32_checksum : Adler32
}

// Compress data using deflate algorithm

///|
pub fn deflate_compress(
  data : Bytes,
  level : Level,
) -> Result[DeflateData, String] {
  // Convert bytes to string for internal processing
  let string_data = data.to_string()
  match level {
    Level::None => compress_uncompressed(string_data.to_bytes())
    Level::Fast => compress_basic_deflate(string_data)
    Level::Default => compress_basic_deflate(string_data)
    Level::Best => compress_basic_deflate(string_data)
  }
}

// Legacy string-based API for backward compatibility
///|
pub fn deflate_compress_string(
  data : String,
  level : Level,
) -> Result[DeflateData, String] {
  deflate_compress(data.to_bytes(), level)
}

// Decompress deflate data

///|
pub fn deflate_decompress(deflate_data : DeflateData) -> Result[Bytes, String] {
  // First decompress the data (returns String)
  match decompress_deflate_blocks(deflate_data.compressed_bytes.to_string()) {
    Ok(decompressed) => {
      // Convert to bytes for checksum verification
      let decompressed_bytes = decompressed.to_bytes()
      // Then verify Adler-32 checksum of the decompressed data
      let computed_adler = adler32_bytes(decompressed_bytes)
      if adler32_equal(computed_adler, deflate_data.adler32_checksum) {
        Ok(decompressed_bytes)
      } else {
        Err("Adler-32 checksum mismatch")
      }
    }
    Err(error) => Err(error)
  }
}

// Legacy string-based API for backward compatibility
///|
pub fn deflate_decompress_string(deflate_data : DeflateData) -> Result[String, String] {
  match deflate_decompress(deflate_data) {
    Ok(bytes) => Ok(bytes.to_string())
    Err(error) => Err(error)
  }
}

// Compress using uncompressed blocks (Level::None)

///|
fn compress_uncompressed(data : Bytes) -> Result[DeflateData, String] {
  if data.length() == 0 {
    // Empty data - just return empty compressed data
    let adler = adler32_bytes(data)
    return Ok({
      compressed_bytes: Bytes::from_array([]),
      original_size: 0,
      adler32_checksum: adler,
    })
  }

  // For uncompressed blocks, we need to create deflate blocks
  // Each block has a 3-bit header: BFINAL (1 bit) + BTYPE (2 bits)
  // For uncompressed: BTYPE = 00
  // Then LEN (16 bits) and NLEN (16 bits, one's complement of LEN)

  let mut compressed = Bytes::from_array([])
  let mut remaining = data

  // Process data in chunks (max 65535 bytes per uncompressed block)
  while remaining.length() > 0 {
    let chunk_size = if remaining.length() > 65535 {
      65535
    } else {
      remaining.length()
    }
    let chunk = remaining[0:chunk_size].to_bytes()
    let is_final = remaining.length() <= 65535

    // Create block header
    let bfinal = if is_final { 1 } else { 0 }
    let btype = block_type_to_btype(BlockType::Uncompressed)
    let header_bits = bfinal | (btype << 1) // 3 bits total

    // For simplicity, we'll store the header as a full byte (padding with zeros)
    let header_byte = header_bits
    let header_bytes = Bytes::from_array([header_byte.to_byte()])
    compressed = compressed + header_bytes

    // Add LEN (little-endian 16-bit)
    let len = chunk.length()
    let len_bytes = write_u16_le_bytes(len)
    compressed = compressed + len_bytes

    // Add NLEN (one's complement of LEN)
    let nlen = len ^ 0xffff
    let nlen_bytes = write_u16_le_bytes(nlen)
    compressed = compressed + nlen_bytes

    // Add the actual data
    compressed = compressed + chunk

    // Move to next chunk
    remaining = remaining[chunk_size:remaining.length()].to_bytes()
  }
  let adler = adler32_bytes(data)
  Ok({
    compressed_bytes: compressed,
    original_size: data.length(),
    adler32_checksum: adler,
  })
}

// Basic deflate compression (simplified)

///|
fn compress_basic_deflate(data : String) -> Result[DeflateData, String] {
  // Try Fixed Huffman compression for small data, otherwise use uncompressed
  if data.length() < 1000 {
    compress_fixed_huffman(data)
  } else {
    // For larger data, fall back to uncompressed blocks for now
    compress_uncompressed(data.to_bytes())
  }
}

// Compress using Fixed Huffman blocks
///|
fn compress_fixed_huffman(data : String) -> Result[DeflateData, String] {
  if data.length() == 0 {
    // Empty data - just return empty compressed data
    let adler = adler32_string(data)
    return Ok({
      compressed_bytes: Bytes::from_array([]),
      original_size: 0,
      adler32_checksum: adler,
    })
  }

  // Create Fixed Huffman block
  let mut compressed = Bytes::from_array([])
  
  // Block header: BFINAL=1 (final block), BTYPE=01 (Fixed Huffman)
  let bfinal = 1
  let btype = block_type_to_btype(BlockType::FixedHuffman)
  let header_bits = bfinal | (btype << 1)
  let header_byte = header_bits
  let header_bytes = Bytes::from_array([header_byte.to_byte()])
  compressed = compressed + header_bytes
  
  // For now, encode each byte as a literal using Fixed Huffman codes
  // This is a simplified implementation - a full implementation would:
  // 1. Use LZ77 to find matches
  // 2. Encode literals and length/distance pairs
  // 3. Use proper Fixed Huffman encoding
  
  // Simplified: just store the data with minimal encoding
  compressed = compressed + data.to_bytes()
  
  // Add end-of-block symbol (would be properly Huffman encoded in real implementation)
  let end_block_byte : Int = 0
  let end_block = Bytes::from_array([end_block_byte.to_byte()]) // Placeholder for end-of-block
  compressed = compressed + end_block
  
  let adler = adler32_string(data)
  Ok({
    compressed_bytes: compressed,
    original_size: data.length(),
    adler32_checksum: adler,
  })
}

// Decompress deflate blocks

///|
fn decompress_deflate_blocks(compressed : String) -> Result[String, String] {
  // Convert to bytes for proper binary data handling
  let compressed_bytes = compressed.to_bytes()
  match decompress_deflate_blocks_bytes(compressed_bytes) {
    Ok(result_bytes) => Ok(result_bytes.to_string())
    Err(error) => Err(error)
  }
}

// Decompress deflate blocks from bytes (handles binary data correctly)
///|
fn decompress_deflate_blocks_bytes(compressed : Bytes) -> Result[Bytes, String] {
  if compressed.length() == 0 {
    return Ok(Bytes::from_array([]))
  }
  let mut result = Bytes::from_array([])
  let mut offset = 0
  while offset < compressed.length() {
    // Read block header (3 bits, but we stored as full byte)
    if offset >= compressed.length() {
      return Err("Unexpected end of compressed data")
    }
    let header_byte = compressed[offset].to_int()
    offset = offset + 1
    let bfinal = header_byte & 1
    let btype_value = (header_byte >> 1) & 3
    match btype_to_block_type(btype_value) {
      Some(BlockType::Uncompressed) =>
        // Uncompressed block
        match decompress_uncompressed_block_bytes(compressed, offset) {
          Ok((block_data, new_offset)) => {
            result = result + block_data
            offset = new_offset
          }
          Err(error) => return Err(error)
        }
      Some(BlockType::FixedHuffman) => {
        // Fixed Huffman block - convert to string for existing implementation
        let compressed_string = compressed.to_string()
        match decompress_fixed_huffman_block(compressed_string, offset) {
          Ok((block_data, new_offset)) => {
            result = result + block_data.to_bytes()
            offset = new_offset
          }
          Err(error) => return Err(error)
        }
      }
      Some(BlockType::DynamicHuffman) =>
        // Dynamic Huffman - not implemented yet
        return Err("Dynamic Huffman decompression not implemented")
      None => return Err("Invalid block type: " + btype_value.to_string())
    }

    // If this was the final block, we're done
    if bfinal == 1 {
      break
    }
  }
  Ok(result)
}

// Decompress an uncompressed block

///|
fn decompress_uncompressed_block(
  compressed : String,
  offset : Int,
) -> Result[(String, Int), String] {
  if offset + 4 > compressed.length() {
    return Err("Incomplete uncompressed block header")
  }

  // Read LEN (16-bit little-endian)
  let len = read_u16_le(compressed, offset)
  let nlen = read_u16_le(compressed, offset + 2)

  // Verify NLEN is one's complement of LEN
  if (len ^ nlen) != 0xffff {
    return Err("Invalid uncompressed block: LEN/NLEN mismatch")
  }
  let data_offset = offset + 4
  if data_offset + len > compressed.length() {
    return Err("Incomplete uncompressed block data")
  }
  let block_data = compressed.substring(
    start=data_offset,
    end=data_offset + len,
  )
  Ok((block_data, data_offset + len))
}

// Decompress an uncompressed block from bytes (handles binary data correctly)
///|
fn decompress_uncompressed_block_bytes(
  compressed : Bytes,
  offset : Int,
) -> Result[(Bytes, Int), String] {
  if offset + 4 > compressed.length() {
    return Err("Incomplete uncompressed block header")
  }

  // Read LEN (16-bit little-endian) from bytes
  let len = read_u16_le_bytes(compressed, offset)
  let nlen = read_u16_le_bytes(compressed, offset + 2)

  // Verify NLEN is one's complement of LEN
  if (len ^ nlen) != 0xffff {
    return Err("Invalid uncompressed block: LEN/NLEN mismatch")
  }
  let data_offset = offset + 4
  if data_offset + len > compressed.length() {
    return Err("Incomplete uncompressed block data")
  }
  
  // Extract the block data as bytes
  let block_data = compressed[data_offset:data_offset + len].to_bytes()
  Ok((block_data, data_offset + len))
}

// Helper functions for binary data (reused from zip module)

///|
fn write_u16_le(value : Int) -> String {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  b0.unsafe_to_char().to_string() + b1.unsafe_to_char().to_string()
}

///|
fn write_u16_le_bytes(value : Int) -> Bytes {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  Bytes::from_array([b0.to_byte(), b1.to_byte()])
}

///|
fn read_u16_le(data : String, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset]
  let b1 = data[offset + 1]
  b0 + (b1 << 8)
}

///|
fn read_u16_le_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  b0 + (b1 << 8)
}

// Create deflate-compressed file data for ZIP

///|
pub fn deflate_of_binary_string(
  s : String,
  level : Level,
) -> Result[String, String] {
  match deflate_compress(s.to_bytes(), level) {
    Ok(deflate_data) => Ok(deflate_data.compressed_bytes.to_string())
    Err(error) => Err("Deflate compression failed: " + error)
  }
}

// Extract deflate-compressed data

///|
pub fn deflate_decompress_raw_string(
  compressed_data : String,
  _original_size : Int,
) -> Result[String, String] {
  // For now, skip checksum verification in this simplified API
  // TODO: Use original_size for validation
  decompress_deflate_blocks(compressed_data)
}

// Bytes-based API functions (more efficient for binary data)

///|
pub fn deflate_of_bytes(
  data : Bytes,
  level : Level,
) -> Result[Bytes, String] {
  // Simplified implementation: convert to string, compress, convert back
  // In a full implementation, this would work directly on bytes
  let string_data = data.to_string()
  match deflate_of_binary_string(string_data, level) {
    Ok(compressed_string) => Ok(compressed_string.to_bytes())
    Err(error) => Err(error)
  }
}

///|
pub fn deflate_decompress_bytes(
  compressed_data : Bytes,
  original_size : Int,
) -> Result[Bytes, String] {
  // Simplified implementation: convert to string, decompress, convert back
  // In a full implementation, this would work directly on bytes
  let string_data = compressed_data.to_string()
  match deflate_decompress_raw_string(string_data, original_size) {
    Ok(decompressed_string) => Ok(decompressed_string.to_bytes())
    Err(error) => Err(error)
  }
}
