// Tests for Adler-32 implementation

test "adler32_empty_string" {
  let adler = string("")
  // Empty string should have Adler-32 of 1
  @test.eq(adler, 1L)
}

test "adler32_hello_world" {
  let adler = string("Hello, World!")
  // Known Adler-32 value for "Hello, World!"
  @test.eq(adler, 0x1c49043eL)
}

test "adler32_incremental" {
  let adler1 = new_adler32()
  let adler2 = update_string(adler1, "Hello")
  let adler3 = update_string(adler2, ", World!")
  
  let direct_adler = string("Hello, World!")
  @test.eq(adler3, direct_adler)
}

test "adler32_substring" {
  let text = "abcHello, World!xyz"
  let adler1 = string(text, ~start=3, ~len=13)
  let adler2 = string("Hello, World!")
  @test.eq(adler1, adler2)
}

test "adler32_equality" {
  let adler1 = string("test")
  let adler2 = string("test")
  let adler3 = string("different")
  
  @test.eq(equal(adler1, adler2), true)
  @test.eq(equal(adler1, adler3), false)
}

test "adler32_check_success" {
  let adler = string("test")
  match check(~expect=adler, ~found=adler) {
    Ok(_) => ()
    Err(_) => @test.fail("Adler-32 check should succeed")
  }
}

test "adler32_check_failure" {
  let adler1 = string("test")
  let adler2 = string("different")
  match check(~expect=adler1, ~found=adler2) {
    Ok(_) => @test.fail("Adler-32 check should fail")
    Err(_) => ()
  }
}

test "adler32_hex_format" {
  let adler = 0x12345678L
  let hex = to_hex(adler)
  @test.eq(hex, "0x12345678")
}
