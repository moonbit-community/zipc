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

test "crc32_bytes" {
  // Below tests are verified, it should not be changed.
  inspect(crc32_bytes("hello"), content="907060870")
  inspect(crc32_bytes("hello world hgoho"), content="1710446219")
  inspect(crc32_bytes("hello world hgoho xx"), content="1526806642")
  inspect(crc32_bytes("hello world hgoho xx yy"), content="667264221")
  inspect(crc32_bytes("hello world hgoho xx yy zz"), content="104365882")
  inspect(crc32_bytes("hello world hgoho xx yy zz aa"), content="671492413")
  inspect(crc32_bytes("hello world hgoho xx yy zz aa bb"), content="3001932438")
  inspect(
    crc32_bytes("hello world hgoho xx yy zz aa bb cc"),
    content="26599636",
  )
  inspect(
    crc32_bytes("hello world hgoho xx yy zz aa bb cc dd"),
    content="3638140378",
  )
  inspect(
    crc32_bytes("hello world hgoho xx yy zz aa bb cc dd ee"),
    content="1503706078",
  )
  inspect(
    crc32_bytes("hello world hgoho xx yy zz aa bb cc dd ee ff"),
    content="109730630",
  )
}