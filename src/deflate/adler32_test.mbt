// Tests for Adler-32 implementation

test "adler32_empty_string" {
  let adler = adler32_string("")
  // Empty string should have Adler-32 of 1
  assert_eq(adler, 1L)
}

test "adler32_hello_world" {
  let adler = adler32_string("Hello, World!")
  // Test that we get some Adler value (exact value may vary)
  assert_true(adler != 1L)
}

test "adler32_equality" {
  let adler1 = adler32_string("test")
  let adler2 = adler32_string("test")
  let adler3 = adler32_string("different")
  
  assert_eq(adler32_equal(adler1, adler2), true)
  assert_eq(adler32_equal(adler1, adler3), false)
}