# Huffman Coding Package

This package provides Huffman coding functionality for DEFLATE compression as specified in RFC 1951.

## Features

- **Fixed Huffman Trees**: Implementation of RFC 1951 fixed Huffman codes
- **Dynamic Huffman Trees**: Support for custom Huffman trees (placeholder implementation)
- **Bit Manipulation Utilities**: Tools for reading and manipulating bit streams
- **Block Type Management**: DEFLATE block type definitions and conversions

## Usage

```moonbit
test "huffman_usage_example" {
  // Create fixed Huffman trees
  let literal_tree = @huffman.build_fixed_literal_tree()
  let distance_tree = @huffman.build_fixed_distance_tree()

  // Test block type conversion
  let uncompressed = @huffman.uncompressed_block_type()
  let btype = @huffman.block_type_to_btype(uncompressed)
  inspect(btype, content="0")

  // Test length/distance code utilities
  let length = @huffman.get_length_from_code(257, 0)
  let distance = @huffman.get_distance_from_code(0, 0)
  inspect(length, content="3")
  inspect(distance, content="1")
}
```

## Block Types

The package defines DEFLATE block types:

- `Uncompressed`: No compression (BTYPE = 00)
- `FixedHuffman`: Fixed Huffman codes (BTYPE = 01)
- `DynamicHuffman`: Dynamic Huffman codes (BTYPE = 10)

## Implementation Status

- ✅ **Types and Constants**: Complete
- ✅ **Block Type Conversion**: Complete
- 🚧 **Fixed Huffman Trees**: Placeholder implementation
- 🚧 **Dynamic Huffman Trees**: Placeholder implementation
- 🚧 **Bit Stream Processing**: Basic implementation
- ❌ **Full RFC 1951 Compliance**: Not yet implemented

## Future Improvements

1. **Complete Huffman Tree Implementation**: Full canonical Huffman tree construction
2. **Optimized Bit Reading**: Efficient multi-byte bit stream processing
3. **Dynamic Huffman Support**: Complete implementation of dynamic codes
4. **Performance Optimization**: SIMD and lookup table optimizations
5. **Comprehensive Testing**: Full RFC 1951 test suite

## Dependencies

- `moonbitlang/core/bytes`: For binary data handling

## License

This package is part of the MoonBit ZIP library and follows the same license terms.
