// Basic usage examples for the zipc library

// Example 1: Create a simple ZIP archive with one file
pub fn create_simple_archive() -> Unit {
  println("Creating a simple ZIP archive...")
  
  // Create an empty archive
  let archive = @zipc.empty()
  
  // Create file data
  match @zipc.stored_of_binary_string("Hello from MoonBit zipc!") {
    Ok(file_data) => {
      // Create a member
      match @zipc.member_make("greeting.txt", @zipc.MemberKind::File(file_data)) {
        Ok(member) => {
          // Add to archive
          let archive_with_file = @zipc.add(member, archive)
          
          println("Archive created with \{@zipc.member_count(archive_with_file)} member(s)")
          
          // Check if file exists
          if @zipc.mem("greeting.txt", archive_with_file) {
            println("✓ File 'greeting.txt' found in archive")
          }
        }
        Err(error) => println("Error creating member: \{error}")
      }
    }
    Err(error) => println("Error creating file data: \{error}")
  }
}

// Example 2: Working with CRC-32 checksums
pub fn checksum_example() -> Unit {
  println("CRC-32 checksum examples...")
  
  let data1 = "Hello, World!"
  let data2 = "Hello, World!"
  let data3 = "Different data"
  
  let crc1 = @zipc.crc32_string(data1)
  let crc2 = @zipc.crc32_string(data2)
  let crc3 = @zipc.crc32_string(data3)
  
  println("CRC-32 of '\{data1}': \{@zipc.crc32_to_hex(crc1)}")
  println("CRC-32 of '\{data2}': \{@zipc.crc32_to_hex(crc2)}")
  println("CRC-32 of '\{data3}': \{@zipc.crc32_to_hex(crc3)}")
  
  if @zipc.crc32_equal(crc1, crc2) {
    println("✓ CRC-32 values for identical data match")
  }
  
  if not(@zipc.crc32_equal(crc1, crc3)) {
    println("✓ CRC-32 values for different data don't match")
  }
}

// Example 3: Working with Adler-32 checksums
pub fn adler32_example() -> Unit {
  println("Adler-32 checksum examples...")
  
  let data = "MoonBit zipc library"
  let adler = @zipc.adler32_string(data)
  
  println("Adler-32 of '\{data}': \{@zipc.adler32_to_hex(adler)}")
  
  // Empty string should have Adler-32 of 1
  let empty_adler = @zipc.adler32_string("")
  if @zipc.adler32_equal(empty_adler, 1L) {
    println("✓ Empty string has correct Adler-32 value (1)")
  }
}

// Main function to run all examples
pub fn main() -> Unit {
  println("=== MoonBit zipc Library Examples ===\n")
  
  create_simple_archive()
  println("")
  
  checksum_example()
  println("")
  
  adler32_example()
  
  println("\n=== Examples completed ===")
}
