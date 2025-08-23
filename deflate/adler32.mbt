// Adler-32 checksum implementation for zlib format
// Adler-32 is defined as: a = 1 + sum of bytes, b = sum of a values, result = b * 65536 + a

///|
pub typealias Int64 as Adler32

///|
let adler32_base : Int64 = 65521L // Largest prime smaller than 65536

// Create a new Adler-32 checksum (initial value)

///|
pub fn new_adler32() -> Adler32 {
  1L
}

// Update Adler-32 with a single byte

///|
fn adler32_update_byte(adler : Adler32, byte : Int) -> Adler32 {
  let a = adler & 0xffffL
  let b = adler >> 16
  let new_a = (a + (byte.to_int64() & 0xffL)) % adler32_base
  let new_b = (b + new_a) % adler32_base
  (new_b << 16) | new_a
}

// Update Adler-32 with a string

///|
fn adler32_update_string(adler : Adler32, s : String) -> Adler32 {
  let mut result = adler
  for i = 0; i < s.length(); i = i + 1 {
    result = adler32_update_byte(result, s[i])
  }
  result
}

// Update Adler-32 with bytes (more efficient for binary data)

///|
fn adler32_update_bytes(adler : Adler32, data : Bytes) -> Adler32 {
  let mut result = adler
  for i = 0; i < data.length(); i = i + 1 {
    result = adler32_update_byte(result, data[i].to_int())
  }
  result
}

// Compute Adler-32 of a string

///|
pub fn adler32_string(s : String) -> Adler32 {
  let adler = new_adler32()
  adler32_update_string(adler, s)
}

// Compute Adler-32 of bytes (more efficient for binary data)

///|
pub fn adler32_bytes(data : Bytes) -> Adler32 {
  let adler = new_adler32()
  adler32_update_bytes(adler, data)
}

// Check if two Adler-32 values are equal

///|
pub fn adler32_equal(a1 : Adler32, a2 : Adler32) -> Bool {
  a1 == a2
}

// Check Adler-32 with error message

///|
pub fn adler32_check(expect : Adler32, found : Adler32) -> Result[Unit, String] {
  if adler32_equal(expect, found) {
    Ok(())
  } else {
    Err(
      "Adler-32 mismatch: expected \{adler32_to_hex(expect)}, found \{adler32_to_hex(found)}",
    )
  }
}

// Format Adler-32 as hex string

///|
pub fn adler32_to_hex(adler : Adler32) -> String {
  let hex_chars = "0123456789abcdef"
  let mut result = ""
  let mut value = adler
  for i = 0; i < 8; i = i + 1 {
    let digit = value.land(0xfL).to_int()
    result = hex_chars[digit].to_string() + result
    value = value >> 4
  }
  "0x" + result
}
