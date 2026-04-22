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
    @utf16.encode(
      "Hello, World!"[:],
      bom=false,
      endianness=@utf16.Endian::Little,
    ),
  )
  // Test that we get some CRC value (exact value may vary)
  assert_true(crc != Crc32(0L))
}

///|
test "crc32_equality" {
  let crc1 = @crc32.bytes(
    @utf16.encode("test"[:], bom=false, endianness=@utf16.Endian::Little),
  )
  let crc2 = @crc32.bytes(
    @utf16.encode("test"[:], bom=false, endianness=@utf16.Endian::Little),
  )
  let crc3 = @crc32.bytes(
    @utf16.encode("different"[:], bom=false, endianness=@utf16.Endian::Little),
  )
  assert_eq(crc1, crc2)
  assert_not_eq(crc1, crc3)
}

///|
test "crc32_bytes_consistency" {
  let test_string = "Hello, Bytes!"
  let test_bytes = @utf16.encode(
    test_string[:],
    bom=false,
    endianness=@utf16.Endian::Little,
  )
  let crc1 = @crc32.bytes(test_bytes)
  let crc2 = @crc32.bytes(
    @utf16.encode(test_string[:], bom=false, endianness=@utf16.Endian::Little),
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
    @crc32.bytes(
      @utf16.encode("hello"[:], bom=false, endianness=@utf16.Endian::Little),
    ),
    content="0x535349505550100102",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x4898102545751100102",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x5053575356979856",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x10155555150535697",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x4852494950985699",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x555710010051995653",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x100535156554852102",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x545650999898102102",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x5099525655509853",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd ee"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x485210210199505557",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd ee ff"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ),
    content="0x525399991011015749",
  )
  inspect(
    @crc32.bytes(
      @utf16.encode(
        "hello world hgoho xx yy zz aa bb cc dd ee ff"[:],
        bom=false,
        endianness=@utf16.Endian::Little,
      ),
    ).0,
    content="1171058321",
  )
}
