# Zipc – ZIP archive and deflate codec for MoonBit

Zipc is an in-memory ZIP archive and deflate compression codec for MoonBit, ported from the original [OCaml zipc library](https://github.com/dbuenzli/zipc).

This library provides:
- **Deflate compression/decompression** with CRC-32 and Adler-32 checksums
- **ZIP archive reading/writing** with support for stored and deflate compression
- **High-quality test suite** ensuring correctness and compatibility

## Features

- Pure MoonBit implementation with no external dependencies
- Support for deflate and stored (no compression) formats
- CRC-32 and Adler-32 checksum validation
- In-memory ZIP archive manipulation
- Comprehensive test coverage

## Installation

Add this to your `moon.pkg.json`:

```json
{
  "import": ["bobzhang/zipc"]
}
```

## Quick Start

```moonbit
// Create a ZIP archive
let archive = @zipc.empty()

// Create file data (stored format - no compression)
match @zipc.stored_of_binary_string("Hello, World!") {
  Ok(file_data) => {
    // Create a member
    match @zipc.member_make("hello.txt", @zipc.MemberKind::File(file_data)) {
      Ok(member) => {
        // Add to archive
        let archive = @zipc.add(member, archive)
        
        // Encode to bytes
        match @zipc.to_binary_string(archive) {
          Ok(zip_bytes) => println("ZIP archive created successfully!")
          Err(error) => println("Error encoding archive: \{error}")
        }
      }
      Err(error) => println("Error creating member: \{error}")
    }
  }
  Err(error) => println("Error creating file data: \{error}")
}
```

## Current Status

This is a **work-in-progress** port of the OCaml zipc library to MoonBit. Currently implemented:

### ✅ Working Features
- **CRC-32 checksums** - Full implementation with lookup table
- **Adler-32 checksums** - Complete implementation for zlib format
- **ZIP archive structure** - Types and basic operations
- **Stored format files** - Uncompressed file support
- **Archive operations** - Add, remove, find members
- **Comprehensive tests** - Test suite for checksums and basic operations

### 🚧 Planned Features
- **Deflate compression/decompression** - Core compression algorithm
- **Full ZIP parsing** - Read existing ZIP files
- **ZIP encoding** - Write complete ZIP archives
- **Zlib format support** - Deflate with headers and checksums
- **Advanced ZIP features** - Directory entries, file attributes

### 📋 API Compatibility

The API closely follows the original OCaml zipc library structure:
- `Result[T, E]` type for error handling
- Functional programming style with immutable data structures
- Comprehensive type safety

## License

ISC License - same as the original OCaml zipc library.