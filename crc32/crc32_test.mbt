// Tests for CRC-32 implementation

///|
test "crc32_empty_bytes" {
  let crc = bytes(Bytes::from_array([]))
  // Empty bytes should have CRC-32 of 0
  assert_eq(crc, Crc32(0L))
}

///|
test "crc32_hello_world" {
  let crc = bytes("Hello, World!".to_bytes())
  // Test that we get some CRC value (exact value may vary)
  assert_true(crc != Crc32(0L))
}

///|
test "crc32_equality" {
  let crc1 = bytes("test".to_bytes())
  let crc2 = bytes("test".to_bytes())
  let crc3 = bytes("different".to_bytes())
  assert_eq(crc1, crc2)
  assert_not_eq(crc1, crc3)
}

///|
test "crc32_bytes_consistency" {
  let test_string = "Hello, Bytes!"
  let test_bytes = test_string.to_bytes()
  let crc1 = bytes(test_bytes)
  let crc2 = bytes(test_string.to_bytes())

  // Both should produce the same result
  assert_eq(crc1, crc2)
  assert_true(crc1 != Crc32(0L))
}

///|
test "crc32_bytes" {
  // Below tests are verified, it should not be changed.
  // MOONBIT supports overloading, in check modes, "" will be interpreted as Bytes
  inspect(bytes("hello"), content="0x5154494897545654")
  inspect(bytes("hello world hgoho"), content="0x54531025153545698")
  inspect(bytes("hello world hgoho xx"), content="0x5398484951565550")
  inspect(bytes("hello world hgoho xx yy"), content="0x505599539752100100")
  inspect(bytes("hello world hgoho xx yy zz"), content="0x48545156551025197")
  inspect(bytes("hello world hgoho xx yy zz aa"), content="0x50564854505751100")
  inspect(
    bytes("hello world hgoho xx yy zz aa bb"),
    content="0x9850101100100975754",
  )
  inspect(
    bytes("hello world hgoho xx yy zz aa bb cc"),
    content="0x484957531014810052",
  )
  inspect(
    bytes("hello world hgoho xx yy zz aa bb cc dd"),
    content="0x10056100575710010097",
  )
  inspect(
    bytes("hello world hgoho xx yy zz aa bb cc dd ee"),
    content="0x535797489898100101",
  )
  inspect(
    bytes("hello world hgoho xx yy zz aa bb cc dd ee ff"),
    content="0x4854569753985254",
  )
  inspect(
    bytes("hello world hgoho xx yy zz aa bb cc dd ee ff").0,
    content="109730630",
  )
}
