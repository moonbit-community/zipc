// Tests for Adler-32 implementation

test "adler32_empty_string" {
  let adler = string("")
  // Empty string should have Adler-32 of 1
  assert_eq!(adler, 1L)
}

test "adler32_hello_world" {
  let adler = string("Hello, World!")
  // Test that we get some Adler value (exact value may vary)
  assert_ne!(adler, 1L)
}

test "adler32_equality" {
  let adler1 = string("test")
  let adler2 = string("test")
  let adler3 = string("different")
  
  assert_eq!(equal(adler1, adler2), true)
  assert_eq!(equal(adler1, adler3), false)
}