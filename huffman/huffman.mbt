// Huffman coding implementation for DEFLATE
// RFC 1951: Fixed and Dynamic Huffman codes

// Bit stream reader for efficient bit operations
pub struct BitReader {
  data : Bytes
  mut bit_offset : Int  // Current bit position
} derive(Show)

// Create a new bit reader
pub fn new_bit_reader(data : Bytes) -> BitReader {
  { data, bit_offset: 0 }
}

// Read bits from the stream (LSB first, as per RFC 1951)
pub fn read_bits(self : BitReader, num_bits : Int) -> Int {
  if num_bits <= 0 || num_bits > 32 {
    return 0
  }
  
  let mut result = 0
  let mut bits_read = 0
  
  while bits_read < num_bits {
    let byte_offset = self.bit_offset / 8
    let bit_in_byte = self.bit_offset % 8
    
    if byte_offset >= self.data.length() {
      break  // End of data
    }
    
    let byte_val = self.data[byte_offset].to_int()
    // Extract bit at position bit_in_byte (0 = LSB)
    let bit = (byte_val >> bit_in_byte) & 1
    // Place bit at position bits_read in result (LSB first)
    result = result | (bit << bits_read)
    
    self.bit_offset += 1
    bits_read += 1
  }
  
  result
}

// Check if we're at the end of data
pub fn is_at_end(self : BitReader) -> Bool {
  self.bit_offset >= self.data.length() * 8
}





// Build proper RFC 1951 Fixed Huffman tree from code lengths
fn build_canonical_huffman_tree(code_lengths : Array[Int]) -> HuffmanNode? {
  let num_symbols = code_lengths.length()
  if num_symbols == 0 {
    return None
  }
  
  // Count codes by length
  let bl_count = Array::make(max_code_length + 1, 0)
  for i = 0; i < num_symbols; i = i + 1 {
    let length = code_lengths[i]
    if length > 0 && length <= max_code_length {
      bl_count[length] += 1
    }
  }
  
  // Check if we have any codes
  let mut total_codes = 0
  for i = 1; i <= max_code_length; i = i + 1 {
    total_codes += bl_count[i]
  }
  if total_codes == 0 {
    return None
  }
  
  // Handle single symbol case
  if total_codes == 1 {
    for i = 0; i < num_symbols; i = i + 1 {
      if code_lengths[i] > 0 {
        return Some(HuffmanNode::Leaf(i))
      }
    }
  }
  
  // Calculate first code for each length (RFC 1951 algorithm)
  let next_code = Array::make(max_code_length + 1, 0)
  let mut code = 0
  for bits = 1; bits <= max_code_length; bits = bits + 1 {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }
  
  // Build the tree by inserting each symbol
  let root = HuffmanNode::Branch(HuffmanNode::Leaf(-1), HuffmanNode::Leaf(-1))
  
  for symbol = 0; symbol < num_symbols; symbol = symbol + 1 {
    let length = code_lengths[symbol]
    if length > 0 {
      let code = next_code[length]
      next_code[length] += 1
      // For now, use a simplified insertion - we'll implement proper tree building later
    }
  }
  
  Some(root)
}



// Create RFC 1951 Fixed Huffman tree for literals/lengths (simplified)
pub fn create_fixed_huffman_tree() -> HuffmanNode {
  // For now, create a simple tree that can decode basic symbols
  // This is a placeholder until we implement full canonical Huffman tree construction
  
  // Create a tree that can handle end-of-block (256) and some literals
  let end_of_block = HuffmanNode::Leaf(256)
  let literal_a = HuffmanNode::Leaf(65)  // 'A'
  
  HuffmanNode::Branch(end_of_block, literal_a)
}

// Create RFC 1951 Fixed distance tree (simplified)
pub fn create_fixed_distance_tree() -> HuffmanNode {
  // For now, create a simple distance tree
  let distance_1 = HuffmanNode::Leaf(0)  // Distance code 0 = distance 1
  let distance_2 = HuffmanNode::Leaf(1)  // Distance code 1 = distance 2
  
  HuffmanNode::Branch(distance_1, distance_2)
}

// Decode a symbol from the bit stream using a Huffman tree
pub fn decode_symbol(reader : BitReader, tree : HuffmanNode) -> Int? {
  let mut current = tree
  
  // Traverse the tree following bits from the stream
  while true {
    match current {
      HuffmanNode::Leaf(symbol) => {
        if symbol >= 0 {
          return Some(symbol)
        } else {
          return None  // Invalid symbol
        }
      }
      HuffmanNode::Branch(left, right) => {
        if reader.is_at_end() {
          return None  // Premature end of data
        }
        
        // Read next bit (LSB first as per RFC 1951)
        let bit = reader.read_bits(1)
        current = if bit == 0 { left } else { right }
      }
    }
  }
  
  None
}

// Get length from length code (RFC 1951 Section 3.2.5)
pub fn get_length_from_code(reader : BitReader, code : Int) -> Int? {
  if code < 257 {
    return Some(code)  // Literal
  }
  if code == 256 {
    return Some(-1)    // End of block
  }
  if code > 285 {
    return None        // Invalid
  }
  
  let index = code - 257
  if index >= length_base.length() {
    return None
  }
  
  let base = length_base[index]
  let extra_bits = length_extra_bits[index]
  let extra = if extra_bits > 0 { reader.read_bits(extra_bits) } else { 0 }
  
  Some(base + extra)
}

// Get distance from distance code (RFC 1951 Section 3.2.5)
pub fn get_distance_from_code(reader : BitReader, code : Int) -> Int? {
  if code >= distance_base.length() {
    return None
  }
  
  let base = distance_base[code]
  let extra_bits = distance_extra_bits[code]
  let extra = if extra_bits > 0 { reader.read_bits(extra_bits) } else { 0 }
  
  Some(base + extra)
}

// Build Fixed Huffman trees (RFC 1951 Section 3.2.6)
pub fn build_fixed_literal_tree() -> HuffmanNode? {
  // For now, return a simplified tree
  Some(create_fixed_huffman_tree())
}

pub fn build_fixed_distance_tree() -> HuffmanNode? {
  // For now, return a simplified distance tree
  Some(create_fixed_distance_tree())
}

// Decompress Fixed Huffman block from bytes (no String conversion)
///|
pub fn decompress_fixed_huffman_block_bytes(
  compressed : Bytes,
  offset : Int,
) -> (Bytes, Int) raise {
  if offset >= compressed.length() {
    fail("Unexpected end of Fixed Huffman block")
  }

  // Create bit reader starting from the offset
  let remaining_length = compressed.length() - offset
  let block_data = @buffer.new()
  for i = 0; i < remaining_length; i = i + 1 {
    block_data.write_byte(compressed[offset + i])
  }
  let reader = new_bit_reader(block_data.to_bytes())
  
  // Build Fixed Huffman trees
  let literal_tree = match build_fixed_literal_tree() {
    Some(tree) => tree
    None => fail("Failed to build fixed literal tree")
  }
  
  let distance_tree = match build_fixed_distance_tree() {
    Some(tree) => tree
    None => fail("Failed to build fixed distance tree")
  }
  
  // Decompress the block
  let output = @buffer.new()
  
  while not(reader.is_at_end()) {
    // Decode literal/length symbol
    let symbol = match decode_symbol(reader, literal_tree) {
      Some(s) => s
      None => fail("Failed to decode literal/length symbol")
    }
    
    if symbol < 256 {
      // Literal byte
      output.write_byte(symbol.to_byte())
    } else if symbol == 256 {
      // End of block
      break
    } else {
      // Length/distance pair
      let length = match get_length_from_code(reader, symbol) {
        Some(l) => l
        None => fail("Invalid length code: " + symbol.to_string())
      }
      
      if length < 0 {
        break  // End of block
      }
      
      // Decode distance
      let distance_symbol = match decode_symbol(reader, distance_tree) {
        Some(s) => s
        None => fail("Failed to decode distance symbol")
      }
      
      let distance = match get_distance_from_code(reader, distance_symbol) {
        Some(d) => d
        None => fail("Invalid distance code: " + distance_symbol.to_string())
      }
      
      // Copy previous data
      let output_bytes = output.to_bytes()
      let start_pos = output_bytes.length() - distance
      
      if start_pos < 0 {
        fail("Invalid distance: " + distance.to_string())
      }
      
      for i = 0; i < length; i = i + 1 {
        let copy_pos = start_pos + (i % distance)
        if copy_pos < output_bytes.length() {
          output.write_byte(output_bytes[copy_pos])
        }
      }
    }
  }
  
  // Calculate how many bytes we consumed
  let bits_consumed = reader.bit_offset
  let bytes_consumed = (bits_consumed + 7) / 8  // Round up to next byte
  
  (output.to_bytes(), offset + bytes_consumed)
}


