// Raw DEFLATE codec (RFC 1951).
//
// The compression core is provided by the `gmlewis/flate` package — a port of
// Go's `compress/flate` — which performs real LZ77 match-finding and emits
// valid fixed/dynamic Huffman blocks. This module exposes a small,
// `Bytes`-native surface on top of that streaming API.
//
// Spec: https://www.rfc-editor.org/rfc/rfc1951

// ---------------------------------------------------------------------------
// Internal stream helpers shared by the zlib/gzip wrappers as well.
// ---------------------------------------------------------------------------

///|
/// Run `data` through a freshly constructed `gmlewis/flate` writer and return
/// the raw DEFLATE byte stream.
fn flate_encode(data : Bytes) -> Bytes {
  let dst = @io.Buffer::new()
  let w = @flate.Writer::new(dst)
  let _ = w.write(@io.Slice::new(data.to_array()))
  // `close` flushes the final block; it only errors if the sink errors, which a
  // memory buffer never does.
  guard w.close() is None
  dst.to_bytes()
}

///|
/// Read every byte out of an `@io.Reader`, translating a non-EOF I/O error into
/// a `DeflateError`. Used by `inflate` and the zlib/gzip decoders.
fn read_all_or_raise(
  r : &@io.Reader,
  what : String,
) -> Bytes raise DeflateError {
  match @io.read_all(r) {
    (slice, None) => slice.to_bytes()
    (_, Some(err)) => raise DeflateError("\{what}: \{err}")
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

///|
/// Compress `data` into a raw DEFLATE stream (RFC 1951): no zlib/gzip framing
/// and no checksum. Decompress the result with `inflate`.
///
/// Example:
///
/// ```mbt nocheck
/// test {
///   let original = b"banana banana banana banana"
///   let packed = @deflate.deflate(original)
///   assert_eq(@deflate.inflate(packed), original)
/// }
/// ```
pub fn deflate(data : Bytes) -> Bytes {
  flate_encode(data)
}

///|
/// Decompress a raw DEFLATE stream produced by `deflate` (or any RFC 1951
/// encoder). Raises `DeflateError` if the stream is malformed or truncated.
///
/// Example:
///
/// ```mbt nocheck
/// test {
///   // a raw DEFLATE stream of "hello, world" produced by zlib
///   let stream : Bytes = [
///     203, 72, 205, 201, 201, 215, 81, 40, 207, 47, 202, 73, 1, 0,
///   ]
///   assert_eq(@deflate.inflate(stream), b"hello, world")
/// }
/// ```
pub fn inflate(data : Bytes) -> Bytes raise DeflateError {
  let src = @io.Buffer::from_bytes(data)
  let dec = &@flate.Reader::new(src)
  read_all_or_raise(dec, "inflate")
}
