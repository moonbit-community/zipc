// Tests for CRC-32 implementation

///|
test "crc32_empty_bytes" {
  let crc = @crc32.bytes(Bytes::from_array([]))
  // Empty bytes should have CRC-32 of 0
  assert_eq(crc, Crc32(0L))
}

///|
test "crc32_hello_world" {
  let crc = @crc32.bytes(
    @utf16.encode("Hello, World!"[:], bom=false, endianness=Little),
  )
  // Test that we get some CRC value (exact value may vary)
  assert_true(crc != Crc32(0L))
}

///|
test "crc32_equality" {
  let crc1 = @crc32.bytes(
    @utf16.encode("test"[:], bom=false, endianness=Little),
  )
  let crc2 = @crc32.bytes(
    @utf16.encode("test"[:], bom=false, endianness=Little),
  )
  let crc3 = @crc32.bytes(
    @utf16.encode("different"[:], bom=false, endianness=Little),
  )
  assert_eq(crc1, crc2)
  assert_not_eq(crc1, crc3)
}

///|
test "crc32_bytes_consistency" {
  let test_string = "Hello, Bytes!"
  let test_bytes = @utf16.encode(test_string[:], bom=false, endianness=Little)
  let crc1 = @crc32.bytes(test_bytes)
  let crc2 = @crc32.bytes(
    @utf16.encode(test_string[:], bom=false, endianness=Little),
  )

  // Both should produce the same result
  assert_eq(crc1, crc2)
  assert_true(crc1 != Crc32(0L))
}

///|
test "crc32_bytes" {
  // Below tests are verified, it should not be changed.
  // MOONBIT supports overloading, in check modes, "" will be interpreted as Bytes
  inspect(
    @crc32.bytes(@utf16.encode("hello"[:], bom=false, endianness=Little)),
    content=(
      #|0x551272df
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode("hello world hgoho"[:], bom=false, endianness=Little),
    ),
    content=(
      #|0x0bf693df
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode("hello world hgoho xx"[:], bom=false, endianness=Little),
    ),
    content=(
      #|0x25958ab8
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode("hello world hgoho xx yy"[:], bom=false, endianness=Little),
    ),
    content=(
      #|0xe773258a
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz"[:],
        bom=false,
        endianness=Little,
      ),
    ),
    content=(
      #|0x04112b8c
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa"[:],
        bom=false,
        endianness=Little,
      ),
    ),
    content=(
      #|0x79dd3c85
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb"[:],
        bom=false,
        endianness=Little,
      ),
    ),
    content=(
      #|0xd538704f
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc"[:],
        bom=false,
        endianness=Little,
      ),
    ),
    content=(
      #|0x682cbbff
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd"[:],
        bom=false,
        endianness=Little,
      ),
    ),
    content=(
      #|0x2c4872b5
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd ee"[:],
        bom=false,
        endianness=Little,
      ),
    ),
    content=(
      #|0x04fec279
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd ee ff"[:],
        bom=false,
        endianness=Little,
      ),
    ),
    content=(
      #|0x45ccee91
    ),
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd ee ff"[:],
        bom=false,
        endianness=Little,
      ),
    ).0,
    content="1171058321",
  )
}
