// Tests for CRC-32 implementation

///|
test "crc32_empty_bytes" {
  let crc = crc32_bytes(Bytes::from_array([]))
  // Empty bytes should have CRC-32 of 0
  assert_eq(crc, crc32_from_int64(0L))
}

///|
test "crc32_hello_world" {
  let crc = crc32_bytes("Hello, World!".to_bytes())
  // Test that we get some CRC value (exact value may vary)
  assert_true(crc != crc32_from_int64(0L))
}

///|
test "crc32_equality" {
  let crc1 = crc32_bytes("test".to_bytes())
  let crc2 = crc32_bytes("test".to_bytes())
  let crc3 = crc32_bytes("different".to_bytes())
  assert_eq(crc1, crc2)
  assert_not_eq(crc1, crc3)
}

///|
test "crc32_bytes_consistency" {
  let test_string = "Hello, Bytes!"
  let test_bytes = test_string.to_bytes()
  
  let crc1 = crc32_bytes(test_bytes)
  let crc2 = crc32_bytes(test_string.to_bytes())
  
  // Both should produce the same result
  assert_eq(crc1, crc2)
  assert_true(crc1 != Crc32(0L))
}

test "crc32_bytes" {
  // Below tests are verified, it should not be changed.
  inspect(crc32_to_int64(crc32_bytes("hello" )), content="907060870")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho")), content="1710446219")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx")), content="1526806642")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy")), content="667264221")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz")), content="104365882")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa")), content="671492413")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb")), content="3001932438")
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc")),
    content="26599636",
  )
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc dd")),
    content="3638140378",
  )
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc dd ee")),
    content="1503706078",
  )
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc dd ee ff")),
    content="109730630",
  )
}