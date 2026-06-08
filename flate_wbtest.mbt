// Whitebox tests for the raw DEFLATE helpers (private to this package).
//
// Coverage:
//  - round-trips over a range of inputs
//  - the encoder actually compresses redundant data
//  - interop: we decode a real raw-DEFLATE stream produced by C `zlib`
//    (the vector below was generated with Python's `zlib` module)
//  - error handling on corrupt / truncated input

///|
/// Build `b"hello, world\n"` repeated `n` times.
fn repeated(n : Int) -> Bytes {
  let unit = b"hello, world\n"
  let arr : Array[Byte] = []
  for _ in 0..<n {
    for i in 0..<unit.length() {
      arr.push(unit[i])
    }
  }
  Bytes::from_array(arr)
}

///|
let sample_inputs : Array[Bytes] = [
  b"", b"a", b"hello, world", b"\x00\x01\x02\xfd\xfe\xff", // binary, includes NUL and high bytes
   b"The quick brown fox jumps over the lazy dog.",
]

///|
test "raw deflate round-trips" {
  for inp in sample_inputs {
    assert_eq(flate_decode(flate_encode(inp)), inp)
  }
  let big = repeated(1000)
  assert_eq(flate_decode(flate_encode(big)), big)
}

///|
test "encoder compresses redundant data" {
  let big = repeated(1000) // 13_000 bytes of highly redundant text
  let raw = flate_encode(big)
  assert_true(raw.length() < big.length() / 10)
}

///|
test "decode of a real zlib raw-deflate stream" {
  // raw DEFLATE of "hello, world\n" * 3, produced by Python's zlib (wbits=-15)
  let stream : Bytes = [
    203, 72, 205, 201, 201, 215, 81, 40, 207, 47, 202, 73, 225, 202, 192, 201, 1,
    0,
  ]
  assert_eq(flate_decode(stream), b"hello, world\nhello, world\nhello, world\n")
}

///|
test "decode rejects garbage" {
  let garbage : Bytes = [255, 255, 255, 255, 255, 255]
  let raised = try {
    flate_decode(garbage) |> ignore
    false
  } catch {
    ZipError(_) => true
  }
  assert_true(raised)
}
