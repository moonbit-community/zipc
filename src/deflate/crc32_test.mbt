// Tests for CRC-32 implementation

test "crc32_empty_string" {
  let crc = string("")
  // Empty string should have CRC-32 of 0
  @test.eq(crc, 0L)
}

test "crc32_hello_world" {
  let crc = string("Hello, World!")
  // Known CRC-32 value for "Hello, World!"
  @test.eq(crc, 0xec4ac3d0L)
}

test "crc32_incremental" {
  let crc1 = new_crc32()
  let crc2 = update_string(crc1, "Hello")
  let crc3 = update_string(crc2, ", World!")
  let final_crc = finalize(crc3)
  
  let direct_crc = string("Hello, World!")
  @test.eq(final_crc, direct_crc)
}

test "crc32_substring" {
  let text = "abcHello, World!xyz"
  let crc1 = string(text, ~start=3, ~len=13)
  let crc2 = string("Hello, World!")
  @test.eq(crc1, crc2)
}

test "crc32_equality" {
  let crc1 = string("test")
  let crc2 = string("test")
  let crc3 = string("different")
  
  @test.eq(equal(crc1, crc2), true)
  @test.eq(equal(crc1, crc3), false)
}

test "crc32_check_success" {
  let crc = string("test")
  match check(~expect=crc, ~found=crc) {
    Ok(_) => ()
    Err(_) => @test.fail("CRC check should succeed")
  }
}

test "crc32_check_failure" {
  let crc1 = string("test")
  let crc2 = string("different")
  match check(~expect=crc1, ~found=crc2) {
    Ok(_) => @test.fail("CRC check should fail")
    Err(_) => ()
  }
}

test "crc32_hex_format" {
  let crc = 0x12345678L
  let hex = to_hex(crc)
  @test.eq(hex, "0x12345678")
}
