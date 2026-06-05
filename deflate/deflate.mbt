// Deflate compression/decompression implementation
// This is a simplified implementation focusing on basic functionality

// Deflate compressed data structure

///|
pub struct DeflateData {
  compressed_bytes : Bytes
  original_size : Int
  adler32_checksum : @adler32.Adler32
}

// Compress data using deflate algorithm

///|
pub fn deflate_compress(data : Bytes, level : Level) -> DeflateData {
  // Work directly with bytes to avoid corruption
  match level {
    None => compress_uncompressed(data)
    Fast => compress_basic_deflate_bytes(data)
    Default => compress_basic_deflate_bytes(data)
    Best => compress_basic_deflate_bytes(data)
  }
}

// Decompress deflate data

///|
pub fn deflate_decompress(deflate_data : DeflateData) -> Bytes raise {
  // Decompress using bytes-based function to avoid String conversion corruption
  let decompressed_bytes = decompress_deflate_blocks_bytes(
    deflate_data.compressed_bytes,
  )
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

  let compressed = Buffer()
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
    let btype = @huffman.block_type_to_btype(@huffman.uncompressed_block_type())
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
fn compress_basic_deflate_bytes(data : Bytes) -> DeflateData {
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
fn compress_fixed_huffman_bytes(data : Bytes) -> DeflateData {
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
  let btype = @huffman.block_type_to_btype(@huffman.fixed_huffman_block_type())
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

// ---------------------------------------------------------------------------
// Correct RFC 1951 DEFLATE decompression (inflate)
//
// This is a puff.c-style canonical Huffman decoder: instead of building a tree,
// we keep per-length code counts plus a list of symbols sorted by
// (length, symbol) and decode one bit at a time.  The bit stream is read via
// @huffman.BitReader (LSB-first, per RFC 1951).
// ---------------------------------------------------------------------------

// RFC 1951 Section 3.2.5 tables.

///|
let length_base_tbl : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra_tbl : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let dist_base_tbl : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let dist_extra_tbl : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

// Order in which code-length code lengths are read for dynamic blocks.

///|
let cl_order : Array[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

// A canonical Huffman decoder: counts[len] = number of codes of that length
// (len in 1..=15), and symbols[] = symbols sorted by (length, symbol).

///|
priv struct HuffmanDecoder {
  counts : Array[Int]
  symbols : Array[Int]
}

///|
fn build_huffman_decoder(code_lengths : Array[Int]) -> HuffmanDecoder {
  let counts = Array::make(16, 0)
  for i = 0; i < code_lengths.length(); i = i + 1 {
    let l = code_lengths[i]
    if l > 0 && l <= 15 {
      counts[l] += 1
    }
  }
  // Offsets into symbols[] for each length (sorted by length, then symbol).
  let offsets = Array::make(16, 0)
  for len = 1; len < 15; len = len + 1 {
    offsets[len + 1] = offsets[len] + counts[len]
  }
  let total = offsets[15] + counts[15]
  let symbols = Array::make(if total > 0 { total } else { 1 }, 0)
  for sym = 0; sym < code_lengths.length(); sym = sym + 1 {
    let l = code_lengths[sym]
    if l > 0 && l <= 15 {
      symbols[offsets[l]] = sym
      offsets[l] += 1
    }
  }
  { counts, symbols }
}

///|
fn decode_symbol_canonical(
  reader : @huffman.BitReader,
  dec : HuffmanDecoder,
) -> Int raise {
  let mut code = 0
  let mut first = 0
  let mut index = 0
  for len = 1; len <= 15; len = len + 1 {
    code = code | reader.read_bits(1)
    let count = dec.counts[len]
    if code - first < count {
      return dec.symbols[index + (code - first)]
    }
    index = index + count
    first = (first + count) << 1
    code = code << 1
  }
  fail("invalid Huffman code")
}

// Decompress deflate blocks from raw deflate bytes (RFC 1951).

///|
fn decompress_deflate_blocks_bytes(compressed : Bytes) -> Bytes raise {
  if compressed.length() == 0 {
    return Bytes::from_array([])
  }
  let reader = @huffman.new_bit_reader(compressed)
  let out : Array[Byte] = []
  let mut done = false
  while !done {
    let bfinal = reader.read_bits(1)
    let btype = reader.read_bits(2)
    if btype == 0 {
      inflate_stored_block(reader, out)
    } else if btype == 1 {
      inflate_fixed_block(reader, out)
    } else if btype == 2 {
      inflate_dynamic_block(reader, out)
    } else {
      fail("invalid btype 3")
    }
    if bfinal == 1 {
      done = true
    }
  }
  Bytes::from_array(out)
}

// Stored (uncompressed) block, btype = 0.

///|
fn inflate_stored_block(
  reader : @huffman.BitReader,
  out : Array[Byte],
) -> Unit raise {
  // Align to next byte boundary.
  reader.align_to_byte()
  let len = reader.read_bits(16)
  let nlen = reader.read_bits(16)
  if len != ((nlen ^ 0xFFFF) & 0xFFFF) {
    fail("stored block LEN/NLEN mismatch")
  }
  for i = 0; i < len; i = i + 1 {
    out.push(reader.read_bits(8).to_byte())
  }
}

// Fixed Huffman block, btype = 1.

///|
fn inflate_fixed_block(
  reader : @huffman.BitReader,
  out : Array[Byte],
) -> Unit raise {
  let lit_lengths = Array::make(288, 0)
  for i = 0; i <= 143; i = i + 1 {
    lit_lengths[i] = 8
  }
  for i = 144; i <= 255; i = i + 1 {
    lit_lengths[i] = 9
  }
  for i = 256; i <= 279; i = i + 1 {
    lit_lengths[i] = 7
  }
  for i = 280; i <= 287; i = i + 1 {
    lit_lengths[i] = 8
  }
  let dist_lengths = Array::make(30, 5)
  let lit_dec = build_huffman_decoder(lit_lengths)
  let dist_dec = build_huffman_decoder(dist_lengths)
  inflate_symbols(reader, out, lit_dec, dist_dec)
}

// Dynamic Huffman block, btype = 2.

///|
fn inflate_dynamic_block(
  reader : @huffman.BitReader,
  out : Array[Byte],
) -> Unit raise {
  let hlit = reader.read_bits(5) + 257
  let hdist = reader.read_bits(5) + 1
  let hclen = reader.read_bits(4) + 4

  // Read the code-length code lengths in the prescribed order.
  let cl_lengths = Array::make(19, 0)
  for i = 0; i < hclen; i = i + 1 {
    cl_lengths[cl_order[i]] = reader.read_bits(3)
  }
  let cl_dec = build_huffman_decoder(cl_lengths)

  // Decode HLIT + HDIST code lengths.
  let all : Array[Int] = []
  let needed = hlit + hdist
  while all.length() < needed {
    let sym = decode_symbol_canonical(reader, cl_dec)
    if sym < 16 {
      all.push(sym)
    } else if sym == 16 {
      if all.length() == 0 {
        fail("repeat with no previous length")
      }
      let prev = all[all.length() - 1]
      let rep = reader.read_bits(2) + 3
      for j = 0; j < rep; j = j + 1 {
        all.push(prev)
      }
    } else if sym == 17 {
      let rep = reader.read_bits(3) + 3
      for j = 0; j < rep; j = j + 1 {
        all.push(0)
      }
    } else if sym == 18 {
      let rep = reader.read_bits(7) + 11
      for j = 0; j < rep; j = j + 1 {
        all.push(0)
      }
    } else {
      fail("invalid code-length symbol")
    }
  }
  if all.length() != needed {
    fail("code length overrun")
  }
  let lit_lengths = Array::make(hlit, 0)
  for i = 0; i < hlit; i = i + 1 {
    lit_lengths[i] = all[i]
  }
  let dist_lengths = Array::make(hdist, 0)
  for i = 0; i < hdist; i = i + 1 {
    dist_lengths[i] = all[hlit + i]
  }
  let lit_dec = build_huffman_decoder(lit_lengths)
  let dist_dec = build_huffman_decoder(dist_lengths)
  inflate_symbols(reader, out, lit_dec, dist_dec)
}

// Shared literal/length/distance symbol loop for fixed & dynamic blocks.

///|
fn inflate_symbols(
  reader : @huffman.BitReader,
  out : Array[Byte],
  lit_dec : HuffmanDecoder,
  dist_dec : HuffmanDecoder,
) -> Unit raise {
  let mut done = false
  while !done {
    let sym = decode_symbol_canonical(reader, lit_dec)
    if sym < 256 {
      out.push(sym.to_byte())
    } else if sym == 256 {
      done = true
    } else if sym <= 285 {
      let idx = sym - 257
      let length = length_base_tbl[idx] + reader.read_bits(length_extra_tbl[idx])
      let dsym = decode_symbol_canonical(reader, dist_dec)
      if dsym >= 30 {
        fail("invalid distance symbol")
      }
      let dist = dist_base_tbl[dsym] + reader.read_bits(dist_extra_tbl[dsym])
      let start = out.length() - dist
      if start < 0 {
        fail("bad distance")
      }
      // Byte-by-byte copy to support overlapping back-references.
      for i = 0; i < length; i = i + 1 {
        out.push(out[start + i])
      }
    } else {
      fail("invalid length symbol")
    }
  }
}

// Helper functions for binary data (reused from zip module)

///|
fn write_u16_le_bytes(value : Int) -> Bytes {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  Bytes::from_array([b0.to_byte(), b1.to_byte()])
}

// Create deflate-compressed file data for ZIP (DEPRECATED - use deflate_of_bytes)

///|
pub fn deflate_of_bytes(data : Bytes, level : Level) -> Bytes {
  match deflate_compress(data, level) {
    deflate_data => deflate_data.compressed_bytes
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
