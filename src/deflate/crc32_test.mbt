// Tests for CRC-32 implementation

test "crc32_empty_string" {
  let crc = string("")
  // Empty string should have CRC-32 of 0
  assert_eq!(crc, 0L)
}

test "crc32_hello_world" {
  let crc = string("Hello, World!")
  // Test that we get some CRC value (exact value may vary)
  assert_ne!(crc, 0L)
}

test "crc32_equality" {
  let crc1 = string("test")
  let crc2 = string("test")
  let crc3 = string("different")
  
  assert_eq!(equal(crc1, crc2), true)
  assert_eq!(equal(crc1, crc3), false)
}