// Huffman coding types and constants for DEFLATE
// RFC 1951: Fixed and Dynamic Huffman codes

// Huffman tree node
///|
pub enum HuffmanNode {
  Leaf(Int) // Symbol value
  Branch(HuffmanNode, HuffmanNode) // Left and right children
} derive(Show)

// Block types for DEFLATE compression
///|
pub enum BlockType {
  Uncompressed // No compression (BTYPE = 00)
  FixedHuffman // Compressed with fixed Huffman codes (BTYPE = 01)  
  DynamicHuffman // Compressed with dynamic Huffman codes (BTYPE = 10)
} derive(Show, Eq)

// Convert block type to BTYPE value
///|
pub fn block_type_to_btype(block_type : BlockType) -> Int {
  match block_type {
    BlockType::Uncompressed => 0
    BlockType::FixedHuffman => 1
    BlockType::DynamicHuffman => 2
  }
}

// Convert BTYPE value to block type
///|
pub fn btype_to_block_type(btype : Int) -> BlockType? {
  match btype {
    0 => Some(BlockType::Uncompressed)
    1 => Some(BlockType::FixedHuffman)
    2 => Some(BlockType::DynamicHuffman)
    _ => None
  }
}

// Helper functions to create block types
///|
pub fn uncompressed_block_type() -> BlockType {
  BlockType::Uncompressed
}

///|
pub fn fixed_huffman_block_type() -> BlockType {
  BlockType::FixedHuffman
}

///|
pub fn dynamic_huffman_block_type() -> BlockType {
  BlockType::DynamicHuffman
}

// Constants for Fixed Huffman implementation
///|
pub let max_literal_length_codes : Int = 288

///|
pub let max_distance_codes : Int = 32

///|
pub let max_code_length : Int = 15

// Error messages
///|
pub let huffman_invalid_symbol : String = "Invalid Huffman symbol"

///|
pub let huffman_invalid_length : String = "Invalid length code"

///|
pub let huffman_invalid_distance : String = "Invalid distance code"

///|
pub let huffman_premature_end : String = "Premature end of Huffman data"
