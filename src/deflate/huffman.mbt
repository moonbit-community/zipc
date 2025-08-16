// Huffman coding support for deflate decompression

pub struct HuffmanTree {
  // Simple lookup table implementation for fast decoding
  // Maps bit patterns to (symbol, bit_length) pairs
  table : Array[(Int, Int)]  // (symbol, length) pairs, indexed by bit pattern
  max_bits : Int
}

// Create a Huffman tree from code lengths
pub fn from_lengths(lengths : Array[Int]) -> Result[HuffmanTree, String] {
  let max_bits = 15  // Maximum bits in deflate
  let mut bl_count = Array::make(max_bits + 1, 0)
  
  // Count the number of codes for each code length
  for i = 0; i < lengths.length(); i = i + 1 {
    let len = lengths[i]
    if len > 0 && len <= max_bits {
      bl_count[len] = bl_count[len] + 1
    }
  }
  
  // Check if we have any codes
  let mut total_codes = 0
  for i = 1; i <= max_bits; i = i + 1 {
    total_codes = total_codes + bl_count[i]
  }
  if total_codes == 0 {
    return err("No codes in Huffman tree")
  }
  
  // Generate starting codes for each length
  let mut code = 0
  let mut next_code = Array::make(max_bits + 1, 0)
  for bits = 1; bits <= max_bits; bits = bits + 1 {
    code = (code + bl_count[bits - 1]).lsl(1)
    next_code[bits] = code
  }
  
  // Create lookup table (2^max_bits entries)
  let table_size = 1.lsl(max_bits)
  let mut table = Array::make(table_size, (-1, 0))
  
  // Assign codes to symbols
  for symbol = 0; symbol < lengths.length(); symbol = symbol + 1 {
    let len = lengths[symbol]
    if len > 0 {
      let code = next_code[len]
      next_code[len] = code + 1
      
      // Fill all entries that start with this code
      let step = 1.lsl(len)
      let mut i = code
      while i < table_size {
        table[i] = (symbol, len)
        i = i + step
      }
    }
  }
  
  ok({ table, max_bits })
}

// Decode a symbol from the bit reader using the Huffman tree
pub fn decode_symbol(tree : HuffmanTree, reader : BitReader) -> Result[Int, String] {
  // Read up to max_bits and look up in table
  let mut bits = 0
  let mut bit_count = 0
  
  while bit_count < tree.max_bits {
    match @bitreader.read_bit(reader) {
      Ok(bit) => {
        bits = bits.lor(bit.lsl(bit_count))
        bit_count = bit_count + 1
        
        let (symbol, length) = tree.table[bits.land((1.lsl(bit_count)) - 1)]
        if symbol >= 0 && length == bit_count {
          return ok(symbol)
        }
      }
      Err(e) => return err(e)
    }
  }
  
  err("Invalid Huffman code")
}

// Fixed Huffman trees for deflate (used in block type 1)
pub fn fixed_literal_tree() -> HuffmanTree {
  let mut lengths = Array::make(288, 0)
  
  // 0-143: 8 bits
  for i = 0; i <= 143; i = i + 1 {
    lengths[i] = 8
  }
  
  // 144-255: 9 bits  
  for i = 144; i <= 255; i = i + 1 {
    lengths[i] = 9
  }
  
  // 256-279: 7 bits
  for i = 256; i <= 279; i = i + 1 {
    lengths[i] = 7
  }
  
  // 280-287: 8 bits
  for i = 280; i <= 287; i = i + 1 {
    lengths[i] = 8
  }
  
  unwrap(from_lengths(lengths))
}

pub fn fixed_distance_tree() -> HuffmanTree {
  let mut lengths = Array::make(32, 5)  // All 5 bits
  unwrap(from_lengths(lengths))
}

// Dynamic Huffman tree construction (for block type 2)
pub fn decode_dynamic_trees(reader : BitReader) -> Result[(HuffmanTree, HuffmanTree), String] {
  // Read tree parameters
  let hlit = match @bitreader.read_bits(reader, 5) {
    Ok(n) => n + 257
    Err(e) => return err(e)
  }
  
  let hdist = match @bitreader.read_bits(reader, 5) {
    Ok(n) => n + 1
    Err(e) => return err(e)
  }
  
  let hclen = match @bitreader.read_bits(reader, 4) {
    Ok(n) => n + 4
    Err(e) => return err(e)
  }
  
  // Code length alphabet order
  let cl_order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
  
  // Read code lengths for the code length alphabet
  let mut cl_lengths = Array::make(19, 0)
  for i = 0; i < hclen; i = i + 1 {
    match @bitreader.read_bits(reader, 3) {
      Ok(len) => cl_lengths[cl_order[i]] = len
      Err(e) => return err(e)
    }
  }
  
  // Build code length tree
  let cl_tree = match from_lengths(cl_lengths) {
    Ok(tree) => tree
    Err(e) => return err(e)
  }
  
  // Decode literal/length and distance code lengths
  let total_codes = hlit + hdist
  let mut lengths = Array::make(total_codes, 0)
  let mut i = 0
  
  while i < total_codes {
    let symbol = match decode_symbol(cl_tree, reader) {
      Ok(s) => s
      Err(e) => return err(e)
    }
    
    if symbol < 16 {
      // Literal length
      lengths[i] = symbol
      i = i + 1
    } else if symbol == 16 {
      // Repeat previous length 3-6 times
      if i == 0 {
        return err("Cannot repeat previous length at start")
      }
      let repeat_count = match @bitreader.read_bits(reader, 2) {
        Ok(n) => n + 3
        Err(e) => return err(e)
      }
      let prev_len = lengths[i - 1]
      for j = 0; j < repeat_count && i < total_codes; j = j + 1 {
        lengths[i] = prev_len
        i = i + 1
      }
    } else if symbol == 17 {
      // Repeat 0 length 3-10 times
      let repeat_count = match @bitreader.read_bits(reader, 3) {
        Ok(n) => n + 3
        Err(e) => return err(e)
      }
      for j = 0; j < repeat_count && i < total_codes; j = j + 1 {
        lengths[i] = 0
        i = i + 1
      }
    } else if symbol == 18 {
      // Repeat 0 length 11-138 times
      let repeat_count = match @bitreader.read_bits(reader, 7) {
        Ok(n) => n + 11
        Err(e) => return err(e)
      }
      for j = 0; j < repeat_count && i < total_codes; j = j + 1 {
        lengths[i] = 0
        i = i + 1
      }
    } else {
      return err("Invalid code length symbol: \{symbol}")
    }
  }
  
  // Split into literal/length and distance lengths
  let mut lit_lengths = Array::make(hlit, 0)
  let mut dist_lengths = Array::make(hdist, 0)
  
  for i = 0; i < hlit; i = i + 1 {
    lit_lengths[i] = lengths[i]
  }
  
  for i = 0; i < hdist; i = i + 1 {
    dist_lengths[i] = lengths[hlit + i]
  }
  
  // Build trees
  let lit_tree = match from_lengths(lit_lengths) {
    Ok(tree) => tree
    Err(e) => return err(e)
  }
  
  let dist_tree = match from_lengths(dist_lengths) {
    Ok(tree) => tree
    Err(e) => return err(e)
  }
  
  ok((lit_tree, dist_tree))
}
