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
  adler32_checksum : @adler32.Adler32
}

// Compress data using deflate algorithm

///|
pub fn deflate_compress(
  data : Bytes,
  level : Level,
) -> DeflateData {
  // Work directly with bytes to avoid corruption
  match level {
    Level::None => compress_uncompressed(data)
    Level::Fast => compress_basic_deflate_bytes(data)
    Level::Default => compress_basic_deflate_bytes(data)
    Level::Best => compress_basic_deflate_bytes(data)
  }
}



// Decompress deflate data

///|
pub fn deflate_decompress(deflate_data : DeflateData) -> Bytes raise {
  // Decompress using bytes-based function to avoid String conversion corruption
  let decompressed_bytes = decompress_deflate_blocks_bytes(deflate_data.compressed_bytes)
  // Verify Adler-32 checksum of the decompressed data
  let computed_adler = @adler32.bytes(decompressed_bytes)
  if computed_adler == deflate_data.adler32_checksum {
    decompressed_bytes
  } else {
    fail("Adler-32 checksum mismatch")
  }
}



// Compress using uncompressed blocks (Level::None)

///|
fn compress_uncompressed(data : Bytes) -> DeflateData {
  if data.length() == 0 {
    // Empty data - just return empty compressed data
    let adler = @adler32.bytes(data)
    return {
      compressed_bytes: Bytes::from_array([]),
      original_size: 0,
      adler32_checksum: adler,
      }
  }

  // For uncompressed blocks, we need to create deflate blocks
  // Each block has a 3-bit header: BFINAL (1 bit) + BTYPE (2 bits)
  // For uncompressed: BTYPE = 00
  // Then LEN (16 bits) and NLEN (16 bits, one's complement of LEN)

  let compressed = @buffer.new()
  let mut remaining = data[:]

  // Process data in chunks (max 65535 bytes per uncompressed block)
  while remaining.length() > 0 {
    let chunk_size = if remaining.length() > 65535 {
      65535
    } else {
      remaining.length()
    }
    let chunk = remaining[0:chunk_size]
    let is_final = remaining.length() <= 65535

    // Create block header
    let bfinal = if is_final { 1 } else { 0 }
    let btype = block_type_to_btype(BlockType::Uncompressed)
    let header_bits = bfinal | (btype << 1) // 3 bits total

    // For simplicity, we'll store the header as a full byte (padding with zeros)
    let header_byte = header_bits
    // let header_bytes = Bytes::from_array([header_byte.to_byte()])
    // compressed = compressed + header_bytes
    compressed.write_byte(header_byte.to_byte())

    // Add LEN (little-endian 16-bit)
    let len = chunk.length()
    let len_bytes = write_u16_le_bytes(len)
    // compressed = compressed + len_bytes
    compressed.write_bytes(len_bytes)
    // Add NLEN (one's complement of LEN)
    let nlen = len ^ 0xffff
    let nlen_bytes = write_u16_le_bytes(nlen)
    // compressed = compressed + nlen_bytes
    compressed.write_bytes(nlen_bytes)

    // Add the actual data
    // compressed = compressed + chunk
    compressed.write_bytesview(chunk)

    // Move to next chunk
    remaining = remaining[chunk_size:remaining.length()]
  }
  let adler = @adler32.bytes(data)
  {
    compressed_bytes: compressed.to_bytes(),
    original_size: data.length(),
    adler32_checksum: adler,
  }
}

// Bytes-based basic deflate compression (no String conversion)

///|
fn compress_basic_deflate_bytes(data : Bytes) -> DeflateData{
  // Try Fixed Huffman compression for small data, otherwise use uncompressed
  if data.length() < 1000 {
    compress_fixed_huffman_bytes(data)
  } else {
    // For larger data, fall back to uncompressed blocks for now
    compress_uncompressed(data)
  }
}



// Bytes-based Fixed Huffman compression (no String conversion)

///|
fn compress_fixed_huffman_bytes(data : Bytes) -> DeflateData  {
  if data.length() == 0 {
    // Empty data - just return empty compressed data
    let adler = @adler32.bytes(data)
    return {
      compressed_bytes: Bytes::from_array([]),
      original_size: 0,
      adler32_checksum: adler,
    }
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
  compressed = compressed + data

  // Add end-of-block symbol (would be properly Huffman encoded in real implementation)
  let end_block_byte : Int = 0
  let end_block = Bytes::from_array([end_block_byte.to_byte()]) // Placeholder for end-of-block
  compressed = compressed + end_block
  let adler = @adler32.bytes(data)
  {
    compressed_bytes: compressed,
    original_size: data.length(),
    adler32_checksum: adler,
  }
}



// Decompress deflate blocks from bytes (handles binary data correctly)

///|
fn decompress_deflate_blocks_bytes(compressed : Bytes) -> Bytes raise {
  if compressed.length() == 0 {
    return Bytes::from_array([])
  }
  let mut result = Bytes::from_array([])
  let mut offset = 0
  while offset < compressed.length() {
    // Read block header (3 bits, but we stored as full byte)
    if offset >= compressed.length() {
      fail("Unexpected end of compressed data")
    }
    let header_byte = compressed[offset].to_int()
    offset = offset + 1
    let bfinal = header_byte & 1
    let btype_value = (header_byte >> 1) & 3
    match btype_to_block_type(btype_value) {
      Some(BlockType::Uncompressed) => {
        // Uncompressed block
        let (block_data, new_offset) = decompress_uncompressed_block_bytes(compressed, offset)
        result = result + block_data
        offset = new_offset
      }
      Some(BlockType::FixedHuffman) => {
        // Fixed Huffman block - use bytes-based decompression
        let (block_data, new_offset) = decompress_fixed_huffman_block_bytes(compressed, offset)
        result = result + block_data
        offset = new_offset
      }
      Some(BlockType::DynamicHuffman) =>
        // Dynamic Huffman - not implemented yet
        fail("Dynamic Huffman decompression not implemented")
      None => fail("Invalid block type: " + btype_value.to_string())
    }

    // If this was the final block, we're done
    if bfinal == 1 {
      break
    }
  }
  result
}



// Decompress an uncompressed block from bytes (handles binary data correctly)

///|
fn decompress_uncompressed_block_bytes(
  compressed : Bytes,
  offset : Int,
) -> (Bytes, Int) raise {
  if offset + 4 > compressed.length() {
    fail("Incomplete uncompressed block header")
  }

  // Read LEN (16-bit little-endian) from bytes
  let len = read_u16_le_bytes(compressed, offset)
  let nlen = read_u16_le_bytes(compressed, offset + 2)

  // Verify NLEN is one's complement of LEN
  if (len ^ nlen) != 0xffff {
    fail("Invalid uncompressed block: LEN/NLEN mismatch")
  }
  let data_offset = offset + 4
  if data_offset + len > compressed.length() {
    fail("Incomplete uncompressed block data")
  }

  // Extract the block data as bytes
  let block_data = compressed[data_offset:data_offset + len].to_bytes()
  (block_data, data_offset + len)
}

// Decompress Fixed Huffman block from bytes (no String conversion)

///|
fn decompress_fixed_huffman_block_bytes(
  compressed : Bytes,
  offset : Int,
) -> (Bytes, Int) raise {
  // This is a simplified implementation that matches the String version
  // but works directly with bytes to avoid corruption

  if offset >= compressed.length() {
    fail("Unexpected end of Fixed Huffman block")
  }

  // For now, return a simple placeholder that copies some data
  let remaining = compressed.length() - offset
  let block_size = if remaining > 100 { 100 } else { remaining }

  // In a real implementation, this would be the decompressed output
  // For now, use a placeholder that matches the String version
  let decompressed = "Fixed Huffman decompressed data placeholder".to_bytes()
  (decompressed, offset + block_size)
}

// Helper functions for binary data (reused from zip module)

///|
fn write_u16_le_bytes(value : Int) -> Bytes {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  Bytes::from_array([b0.to_byte(), b1.to_byte()])
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

// Create deflate-compressed file data for ZIP (DEPRECATED - use deflate_of_bytes)

///|
pub fn deflate_of_bytes(
  data : Bytes,
  level : Level,
) -> Bytes {
  match deflate_compress(data, level) {
    (deflate_data) => deflate_data.compressed_bytes
  }
}





// Bytes-based API functions (more efficient for binary data)

///|
pub fn deflate_decompress_bytes(
  compressed_data : Bytes,
  _original_size : Int,
) -> Bytes raise {
  // Use bytes-based decompression to avoid String conversion corruption
  decompress_deflate_blocks_bytes(compressed_data)
}

// Raw deflate decompression from bytes (modern API)

///|
pub fn deflate_decompress_raw_bytes(
  compressed_data : Bytes,
  _original_size : Int,
) -> Bytes raise {
  // Use bytes-based decompression to avoid String conversion corruption
  decompress_deflate_blocks_bytes(compressed_data)
}
