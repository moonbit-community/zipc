// Tests for the raw DEFLATE codec.
//
// Coverage:
//  - raw deflate round-trips over a range of inputs
//  - the encoder actually compresses redundant data
//  - interop: we can decode a real raw-DEFLATE stream produced by C `zlib`
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
/// True if `thunk` raises a `DeflateError`.
fn raises(thunk : () -> Bytes raise DeflateError) -> Bool {
  try {
    thunk() |> ignore
    false
  } catch {
    _ => true
  }
}

///|
let sample_inputs : Array[Bytes] = [
  b"", b"a", b"hello, world", b"\x00\x01\x02\xfd\xfe\xff", // binary, includes NUL and high bytes
   b"The quick brown fox jumps over the lazy dog.",
]

///|
test "raw deflate round-trips" {
  for inp in sample_inputs {
    assert_eq(@deflate.inflate(@deflate.deflate(inp)), inp)
  }
  let big = repeated(1000)
  assert_eq(@deflate.inflate(@deflate.deflate(big)), big)
}

///|
test "encoder compresses redundant data" {
  let big = repeated(1000) // 13_000 bytes of highly redundant text
  let raw = @deflate.deflate(big)
  assert_true(raw.length() < big.length() / 10)
}

///|
test "inflate decodes a real zlib raw-deflate stream" {
  // raw DEFLATE of "hello, world\n" * 3, produced by Python's zlib (wbits=-15)
  let stream : Bytes = [
    203, 72, 205, 201, 201, 215, 81, 40, 207, 47, 202, 73, 225, 202, 192, 201, 1,
    0,
  ]
  assert_eq(
    @deflate.inflate(stream),
    b"hello, world\nhello, world\nhello, world\n",
  )
}

///|
test "inflate rejects garbage" {
  let garbage : Bytes = [255, 255, 255, 255, 255, 255]
  assert_true(raises(() => @deflate.inflate(garbage)))
}
