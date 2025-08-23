// Basic usage examples for the zipc library

// Example 1: Create a simple ZIP archive
pub fn create_simple_archive() -> Unit {
  println("Creating a simple ZIP archive...")
  
  // Create an empty archive
  let archive = @zipc.empty()
  println("✓ Created empty archive with \{@zipc.member_count(archive)} members")
  
  // Test basic archive properties
  if @zipc.is_empty(archive) {
    println("✓ Archive is empty as expected")
  }
  
  // Test encoding/decoding empty archive
  match @zipc.to_binary_string(archive) {
    @deflate.Ok(zip_data) => {
      println("✓ Encoded empty archive to \{zip_data.length()} bytes")
      
      // Test decoding
      match @zipc.of_binary_string(zip_data) {
        @deflate.Ok(decoded) => {
          if @zipc.is_empty(decoded) {
            println("✓ Successfully decoded empty archive")
          }
        }
        @deflate.Err(error) => println("✗ Error decoding archive: \{error}")
      }
    }
    @deflate.Err(error) => println("✗ Error encoding archive: \{error}")
  }
}

// Example 2: Working with CRC-32 checksums
pub fn checksum_example() -> Unit {
  println("CRC-32 checksum examples...")
  
  let data1 = "Hello, World!"
  let data2 = "Hello, World!"
  let data3 = "Different data"
  
  let crc1 = @deflate.crc32_string(data1)
  let crc2 = @deflate.crc32_string(data2)
  let crc3 = @deflate.crc32_string(data3)
  
  println("CRC-32 of '\{data1}': \{@deflate.crc32_to_hex(crc1)}")
  println("CRC-32 of '\{data2}': \{@deflate.crc32_to_hex(crc2)}")
  println("CRC-32 of '\{data3}': \{@deflate.crc32_to_hex(crc3)}")
  
  if @deflate.crc32_equal(crc1, crc2) {
    println("✓ CRC-32 values for identical data match")
  }
  
  if not(@deflate.crc32_equal(crc1, crc3)) {
    println("✓ CRC-32 values for different data don't match")
  }
}

// Example 3: Working with Adler-32 checksums
pub fn adler32_example() -> Unit {
  println("Adler-32 checksum examples...")
  
  let data = "MoonBit zipc library"
  let adler = @deflate.adler32_string(data)
  
  println("Adler-32 of '\{data}': \{@deflate.adler32_to_hex(adler)}")
  
  // Empty string should have Adler-32 of 1
  let empty_adler = @deflate.adler32_string("")
  if @deflate.adler32_equal(empty_adler, 1) {
    println("✓ Empty string has correct Adler-32 value (1)")
  }
}

// Main function to run all examples
fn main {
  println("=== MoonBit zipc Library Examples ===\n")
  
  create_simple_archive()
  println("")
  
  checksum_example()
  println("")
  
  adler32_example()
  
  println("\n=== Examples completed ===")
}
