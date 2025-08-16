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
  "import": ["zipc/zipc"]
}
```

## Quick Start

```moonbit
// Create a ZIP archive
let archive = @zipc.empty()

// Add a file
let file_data = @zipc.File.stored_of_binary_string("Hello, World!")
let member = @zipc.Member.make(~path="hello.txt", @zipc.Member.File(file_data))
let archive = @zipc.add(member, archive)

// Encode to bytes
let zip_bytes = @zipc.to_binary_string(archive)
```

## License

ISC License - same as the original OCaml zipc library.