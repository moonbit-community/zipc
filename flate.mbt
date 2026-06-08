// Raw DEFLATE (RFC 1951) helpers for ZIP entries.
//
// The compression core is provided by the `gmlewis/flate` package — a port of
// Go's `compress/flate`, which performs real LZ77 match-finding and emits valid
// fixed/dynamic Huffman blocks. These two helpers expose the minimal,
// `Bytes`-native surface the archive layer needs: compress on encode, decompress
// on decode. They are not public — the library deliberately ships an archive
// model, not a general codec (use `gmlewis/flate` directly for that).
//
// Spec: https://www.rfc-editor.org/rfc/rfc1951

///|
/// Compress `data` into a raw DEFLATE stream (no zlib/gzip framing, no checksum).
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
/// Decompress a raw DEFLATE stream. Raises `ZipError` if the stream is malformed
/// or truncated.
fn flate_decode(data : Bytes) -> Bytes raise ZipError {
  let src = @io.Buffer::from_bytes(data)
  let dec = &@flate.Reader::new(src)
  match @io.read_all(dec) {
    (slice, None) => slice.to_bytes()
    (_, Some(err)) => raise ZipError("inflate: \{err}")
  }
}
