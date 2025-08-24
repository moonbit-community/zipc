# Zipc – ZIP archive and deflate codec for MoonBit

Zipc is a comprehensive in-memory ZIP archive and deflate compression codec for MoonBit, ported and enhanced from the original [OCaml zipc library](https://github.com/dbuenzli/zipc).

This library provides:
- **Complete DEFLATE compression** with Fixed Huffman coding and uncompressed blocks
- **Gzip format support** (RFC 1952) with metadata and CRC-32 validation
- **ZIP archive manipulation** with full format compliance and metadata support
- **Advanced ZIP features** including extra fields, DOS time conversion, and Unicode support
- **Comprehensive checksums** with CRC-32 and Adler-32 implementations
- **High-quality test suite** with 100+ tests ensuring correctness and compatibility

## Features

### Core Compression
- **DEFLATE algorithm** (RFC 1951) with Fixed Huffman coding
- **Gzip format** (RFC 1952) with full metadata support
- **Zlib format** (RFC 1950) with Adler-32 checksums
- **Uncompressed blocks** for maximum compatibility

### ZIP Archive Support
- **Complete ZIP format** reading and writing
- **DOS time/date conversion** for proper file timestamps
- **Extra fields system** for extended metadata
- **Unicode filename support** with proper encoding
- **Directory entries** with full attribute support
- **Mixed compression modes** in single archives

### Data Integrity
- **CRC-32 checksums** with optimized lookup tables
- **Adler-32 checksums** for zlib format validation
- **Format validation** with comprehensive error reporting
- **Roundtrip testing** ensuring data integrity

### Developer Experience
- **Pure MoonBit implementation** with no external dependencies
- **Functional programming style** with immutable data structures
- **Comprehensive error handling** using Result types
- **Extensive test coverage** with 100+ test cases across 8 test modules

## Installation

Add this to your `moon.pkg.json`:

```json
{
  "import": [
    "bobzhang/zipc",
    "bobzhang/zipc/deflate"
  ]
}
```

The main package provides ZIP archive functionality, while the `deflate` package provides compression algorithms and checksums.

## Quick Start

### Basic ZIP Archive Operations

```moonbit
test {
  // Create an empty ZIP archive
  let archive = @zipc.empty()
  
  // Test basic archive properties
  inspect(@zipc.member_count(archive), content="0")
  inspect(@zipc.is_empty(archive), content="true")
  
  // Test encoding/decoding empty archive
  match @zipc.to_binary_string(archive) {
    @deflate.Ok(zip_data) => {
      inspect(zip_data.length(), content="22") // Empty ZIP is 22 bytes
      
      // Test decoding
      match @zipc.of_binary_string(zip_data) {
        @deflate.Ok(decoded) => {
          inspect(@zipc.is_empty(decoded), content="true")
          inspect(@zipc.member_count(decoded), content="0")
        }
        @deflate.Err(error) => fail("Error decoding archive: " + error)
      }
    }
    @deflate.Err(error) => fail("Error encoding archive: " + error)
  }
}
```

### Working with Checksums

```moonbit
test {
  // CRC-32 checksums
  let data = b"Hello, World!"
  let crc = @crc32.crc32_bytes(data)
  inspect(crc.0 > 0L, content="true") // CRC should be non-zero for non-empty data
  
  // Test CRC equality
  let crc2 = @crc32.crc32_bytes(data)
  inspect(crc == crc2, content="true") // Same data should produce same CRC
}
```

### Gzip Compression

```moonbit
test {
  // Compress data with Gzip
  let data = "MoonBit zipc library example"
  match @deflate.gzip_of_binary_string(data, @deflate.level_default(), None, None) {
    @deflate.Ok(compressed) => {
      // Decompress back
      match @deflate.gzip_to_binary_string(compressed) {
        @deflate.Ok(decompressed) => {
          inspect(decompressed, content=data)
        }
        @deflate.Err(error) => fail("Gzip decompression failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Gzip compression failed: " + error)
  }
}
```

## Current Status

This is a **comprehensive implementation** of ZIP and DEFLATE functionality for MoonBit, significantly enhanced beyond the original OCaml zipc library.

### ✅ Fully Implemented Features

#### Core Compression Algorithms
- **DEFLATE compression** (RFC 1951) with Fixed Huffman coding and uncompressed blocks
- **Gzip format** (RFC 1952) with full metadata support (filename, comment, modification time)
- **Zlib format** (RFC 1950) with proper headers and Adler-32 checksums
- **Intelligent compression selection** - Fixed Huffman for small data, uncompressed for large data

#### ZIP Archive Support
- **Complete ZIP format** reading and writing with proper signatures
- **DOS time/date conversion** for accurate file timestamps
- **Extra fields system** supporting Unix timestamps, Unicode paths, and custom fields
- **Directory entries** with full attribute support and proper mode handling
- **Archive operations** - Add, remove, find, count members with comprehensive API
- **Mixed compression modes** - Stored and deflate files in same archive
- **Format validation** with detailed error reporting

#### Data Integrity & Checksums
- **CRC-32 checksums** with optimized lookup tables and hex formatting
- **Adler-32 checksums** with proper initialization and validation
- **Roundtrip testing** ensuring perfect data integrity
- **Error handling** with comprehensive Result types

#### Advanced Features
- **Unicode filename support** with proper UTF-8 encoding in extra fields
- **Extended metadata** through ZIP extra fields system
- **Multiple compression levels** (None, Fast, Default, Best)
- **Binary I/O utilities** with proper little-endian/big-endian handling

### 🧪 Test Coverage
- **100+ test cases** across 8 comprehensive test modules
- **Snapshot testing** for format compliance
- **Edge case coverage** including empty data, large data, and malformed inputs
- **Roundtrip validation** ensuring data integrity
- **Cross-format compatibility** testing

### 🔄 Partially Implemented
- **Dynamic Huffman coding** - Structure ready, algorithm pending
- **ZIP64 support** - Framework in place for large files

### ❌ Future Enhancements
- **ZIP encryption** - Password protection and advanced security
- **Streaming API** - Non-blocking, memory-efficient processing
- **Advanced compression algorithms** - BZIP2, LZMA support

## API Overview

The library is organized into two main packages:

### Main Package (`@zipc`)
- **Archive operations**: `empty()`, `add()`, `remove()`, `find()`, `mem()`
- **Encoding/Decoding**: `to_binary_string()`, `of_binary_string()`
- **File operations**: `stored_of_binary_string()`, `deflate_of_binary_string()`
- **Member utilities**: `member_make()`, `member_path()`, `member_mode()`, `member_mtime()`
- **DOS time conversion**: `unix_to_dos_datetime()`, `dos_datetime_to_unix()`
- **Extra fields**: `parse_extra_fields()`, `serialize_extra_fields()`, Unicode/Unix timestamp fields

### Deflate Package (`@deflate`)
- **Compression**: `deflate_compress()`, `deflate_decompress()` with multiple levels
- **Gzip format**: `gzip_compress()`, `gzip_decompress()` with metadata support
- **Zlib format**: `zlib_compress()`, `zlib_decompress()` with Adler-32
- **Checksums**: `crc32_string()`, `adler32_string()` with validation utilities
- **Huffman coding**: Fixed Huffman trees and decoding utilities

## Design Principles

- **Functional programming style** with immutable data structures
- **Comprehensive error handling** using `Result[T, E]` types
- **Type safety** with strong typing and validation
- **RFC compliance** following official specifications
- **Memory efficiency** with in-memory processing
- **Extensibility** through modular design

## Performance Characteristics

- **Fixed Huffman compression** provides good compression ratios for small to medium files
- **Optimized checksums** using lookup tables for fast CRC-32/Adler-32 computation
- **Intelligent compression selection** automatically chooses best algorithm based on data size
- **Memory-efficient** operations with minimal allocations
- **Fast roundtrip** encoding/decoding with comprehensive validation

## License

ISC License - same as the original OCaml zipc library.