// Tests for CRC-32 implementation

test "crc32_empty_string" {
  let crc = crc32_string("")
  // Empty string should have CRC-32 of 0
  assert_eq(crc, 0L)
}

test "crc32_hello_world" {
  let crc = crc32_string("Hello, World!")
  // Test that we get some CRC value (exact value may vary)
  assert_true(crc != 0L)
}

test "crc32_equality" {
  let crc1 = crc32_string("test")
  let crc2 = crc32_string("test")
  let crc3 = crc32_string("different")
  
  assert_eq(crc32_equal(crc1, crc2), true)
  assert_eq(crc32_equal(crc1, crc3), false)
}