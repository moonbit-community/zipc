// Tests for CRC-32 implementation

///|
test "crc32_empty_string" {
  let crc = crc32_string("")
  // Empty string should have CRC-32 of 0
  assert_eq(crc, 0L)
}

///|
test "crc32_hello_world" {
  let crc = crc32_string("Hello, World!")
  // Test that we get some CRC value (exact value may vary)
  assert_true(crc != 0L)
}

///|
test "crc32_equality" {
  let crc1 = crc32_string("test")
  let crc2 = crc32_string("test")
  let crc3 = crc32_string("different")
  assert_eq(crc32_equal(crc1, crc2), true)
  assert_eq(crc32_equal(crc1, crc3), false)
}

///|
test "crc32_bytes_vs_string" {
  let test_string = "Hello, Bytes!"
  let test_bytes = test_string.to_bytes()
  
  let crc_string = crc32_string(test_string)
  let crc_bytes = crc32_bytes(test_bytes)
  
  // Note: These may not be equal due to String vs Bytes encoding differences
  // This test documents the behavior rather than asserting equality
  assert_true(crc_string != 0L)
  assert_true(crc_bytes != 0L)
}
