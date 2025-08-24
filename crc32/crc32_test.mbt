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
  assert_eq(crc32_equal(crc1, crc2), true)
  assert_eq(crc32_equal(crc1, crc3), false)
}

///|
test "crc32_bytes_consistency" {
  let test_string = "Hello, Bytes!"
  let test_bytes = test_string.to_bytes()
  
  let crc1 = crc32_bytes(test_bytes)
  let crc2 = crc32_bytes(test_string.to_bytes())
  
  // Both should produce the same result
  assert_eq(crc32_equal(crc1, crc2), true)
  assert_true(crc1 != crc32_from_int64(0L))
}

test "crc32_bytes" {
  // Below tests are verified, it should not be changed.
  inspect(crc32_to_int64(crc32_bytes("hello".to_bytes())), content="907060870")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho".to_bytes())), content="1710446219")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx".to_bytes())), content="1526806642")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy".to_bytes())), content="667264221")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz".to_bytes())), content="104365882")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa".to_bytes())), content="671492413")
  inspect(crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb".to_bytes())), content="3001932438")
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc".to_bytes())),
    content="26599636",
  )
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc dd".to_bytes())),
    content="3638140378",
  )
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc dd ee".to_bytes())),
    content="1503706078",
  )
  inspect(
    crc32_to_int64(crc32_bytes("hello world hgoho xx yy zz aa bb cc dd ee ff".to_bytes())),
    content="109730630",
  )
}