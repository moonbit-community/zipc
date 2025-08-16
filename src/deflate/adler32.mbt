// Adler-32 checksum implementation for zlib format
// Adler-32 is defined as: a = 1 + sum of bytes, b = sum of a values, result = b * 65536 + a

pub typealias Adler32 = Int64

let adler32_base : Int64 = 65521L  // Largest prime smaller than 65536

// Create a new Adler-32 checksum (initial value)
pub fn new_adler32() -> Adler32 {
  1L
}

// Update Adler-32 with a single byte
pub fn update_byte(adler : Adler32, byte : Int) -> Adler32 {
  let a = adler.land(0xffffL)
  let b = adler >> 16
  let new_a = (a + byte.to_int64().land(0xffL)) % adler32_base
  let new_b = (b + new_a) % adler32_base
  (new_b << 16).lor(new_a)
}

// Update Adler-32 with a string slice
pub fn update_string(adler : Adler32, s : String, ~start : Int = 0, ~len : Int = -1) -> Adler32 {
  let actual_len = if len == -1 { s.length() - start } else { len }
  let mut result = adler
  for i = start; i < start + actual_len; i = i + 1 {
    result = update_byte(result, s[i].to_int())
  }
  result
}

// Compute Adler-32 of a string slice
pub fn string(s : String, ~start : Int = 0, ~len : Int = -1) -> Adler32 {
  let adler = new_adler32()
  update_string(adler, s, ~start, ~len)
}

// Check if two Adler-32 values are equal
pub fn equal(a1 : Adler32, a2 : Adler32) -> Bool {
  a1 == a2
}

// Check Adler-32 with error message
pub fn check(~expect : Adler32, ~found : Adler32) -> @types.Result[Unit, String] {
  if equal(expect, found) {
    @types.ok(())
  } else {
    @types.err("Adler-32 mismatch: expected \{to_hex(expect)}, found \{to_hex(found)}")
  }
}

// Format Adler-32 as hex string
pub fn to_hex(adler : Adler32) -> String {
  let hex_chars = "0123456789abcdef"
  let mut result = ""
  let mut value = adler
  for i = 0; i < 8; i = i + 1 {
    let digit = (value.land(0xfL)).to_int()
    result = hex_chars[digit].to_string() + result
    value = value >> 4
  }
  "0x" + result
}