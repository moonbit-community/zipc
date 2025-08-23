# String to Bytes Migration Plan

## Overview

The current ZIP library architecture has a fundamental design issue: it uses `String` (UTF-16) for binary data operations. This is inefficient and potentially incorrect for handling arbitrary binary data.

## Current Problems

### 1. Performance Issues
- UTF-16 strings have encoding/decoding overhead for binary operations
- String concatenation is less efficient than bytes concatenation
- Character indexing requires UTF-16 validation

### 2. Memory Inefficiency
- UTF-16 uses 2+ bytes per character vs 1 byte for raw data
- Additional metadata overhead for string structures

### 3. Correctness Issues
- Binary data may contain invalid UTF-16 sequences
- Using `unsafe_to_char()` is fragile and error-prone
- String operations assume character semantics, not byte semantics

### 4. API Confusion
- Functions named `*_binary_string` are misleading
- Mixing text (paths, comments) with binary data (compressed content)

## Proposed Architecture

### Core Data Structure Changes

```moonbit
// Current (problematic)
pub struct File {
  compressed_bytes : String  // ❌ Should be Bytes
  // ...
}

// Proposed (correct)
pub struct File {
  compressed_bytes : Bytes   // ✅ Proper binary data type
  // ...
}
```

### API Changes

```moonbit
// Current API
pub fn stored_of_binary_string(s : String) -> Result[File, String]
pub fn file_to_binary_string(file : File) -> Result[String, String]

// New API
pub fn stored_of_bytes(data : Bytes) -> Result[File, String]
pub fn file_to_bytes(file : File) -> Result[Bytes, String]

// Legacy compatibility (optional)
pub fn stored_of_binary_string(s : String) -> Result[File, String] {
  stored_of_bytes(s.to_bytes())
}
```

### Binary Utilities Migration

```moonbit
// Current (using unsafe operations)
fn write_u16_le(value : Int) -> String {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  b0.unsafe_to_char().to_string() + b1.unsafe_to_char().to_string()  // ❌ Unsafe
}

// Proposed (safe and efficient)
fn write_u16_le(value : Int) -> Bytes {
  let b0 = (value & 0xff).to_byte()
  let b1 = ((value >> 8) & 0xff).to_byte()
  Bytes::from_array([b0, b1])  // ✅ Safe and direct
}
```

## Migration Strategy

### Phase 1: Add Bytes Support
1. Update core data structures (`File`, `DeflateData`, etc.)
2. Add new Bytes-based utility functions
3. Implement CRC32/Adler32 for Bytes
4. Add new Bytes-based compression/decompression functions

### Phase 2: Update Public API
1. Add new `*_of_bytes` and `*_to_bytes` functions
2. Keep existing `*_binary_string` functions for compatibility
3. Update internal implementations to use Bytes

### Phase 3: Update Tests and Examples
1. Add tests for new Bytes-based API
2. Update examples to demonstrate both APIs
3. Add performance comparison tests

### Phase 4: Deprecation (Optional)
1. Mark old String-based functions as deprecated
2. Provide migration guide for users
3. Eventually remove deprecated functions in major version

## Implementation Details

### Required New Functions

#### In deflate module:
```moonbit
pub fn deflate_compress(data : Bytes, level : Level) -> Result[DeflateData, String]
pub fn deflate_decompress(data : DeflateData) -> Result[Bytes, String]
pub fn deflate_of_bytes(data : Bytes, level : Level) -> Result[Bytes, String]
pub fn deflate_decompress_bytes(compressed : Bytes, size : Int) -> Result[Bytes, String]
pub fn crc32_bytes(data : Bytes) -> Int64
pub fn adler32_bytes(data : Bytes) -> Int64
```

#### In zip module:
```moonbit
pub fn stored_of_bytes(data : Bytes) -> Result[File, String]
pub fn deflate_of_bytes(data : Bytes, level : Level) -> Result[File, String]
pub fn file_to_bytes(file : File) -> Result[Bytes, String]
pub fn to_bytes(archive : Archive) -> Result[Bytes, String]
pub fn of_bytes(data : Bytes) -> Result[Archive, String]
```

### Binary Utilities Update
```moonbit
fn read_u16_le(data : Bytes, offset : Int) -> Int
fn read_u32_le(data : Bytes, offset : Int) -> Int
fn write_u16_le(value : Int) -> Bytes
fn write_u32_le(value : Int) -> Bytes
```

## Benefits After Migration

### 1. Performance Improvements
- 2-4x faster binary operations (no UTF-16 overhead)
- Reduced memory allocations
- More efficient concatenation and slicing

### 2. Correctness
- Proper handling of arbitrary binary data
- No risk of invalid character sequences
- Elimination of `unsafe_to_char()` calls

### 3. API Clarity
- Clear separation between text and binary data
- More intuitive function names
- Better type safety

### 4. Maintainability
- Cleaner, more readable code
- Fewer edge cases to handle
- Better alignment with ZIP format specification

## Example Usage

### Before (Current)
```moonbit
// Awkward binary data representation
let binary_data = "\u{00}\u{01}\u{02}\u{03}\u{ff}\u{fe}\u{fd}\u{fc}"

match stored_of_binary_string(binary_data) {
  Ok(file) => {
    match file_to_binary_string(file) {
      Ok(extracted) => println("Success")
      Err(e) => println("Error: " + e)
    }
  }
  Err(e) => println("Error: " + e)
}
```

### After (Proposed)
```moonbit
// Natural binary data representation
let binary_data = Bytes::from_array([0, 1, 2, 3, 255, 254, 253, 252].map(fn(x) => x.to_byte()))

match stored_of_bytes(binary_data) {
  Ok(file) => {
    match file_to_bytes(file) {
      Ok(extracted) => println("Success")
      Err(e) => println("Error: " + e)
    }
  }
  Err(e) => println("Error: " + e)
}
```

## Conclusion

This migration is essential for:
- **Performance**: Significant speed and memory improvements
- **Correctness**: Proper binary data handling
- **Maintainability**: Cleaner, safer code
- **Future-proofing**: Better foundation for additional features

The migration can be done incrementally with backward compatibility, making it safe for existing users while providing immediate benefits for new code.
