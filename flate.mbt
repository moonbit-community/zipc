// Raw DEFLATE (RFC 1951) helpers for ZIP entries.
//
// The compression core is provided by the `moonbit-community/flate` package — a
// pure-MoonBit, io-free DEFLATE engine that performs real LZ77 match-finding and
// emits valid fixed/dynamic Huffman blocks. These two helpers expose the minimal,
// `Bytes`-native surface the archive layer needs: compress on encode, decompress
// on decode. They are not public — the library deliberately ships an archive
// model, not a general codec (use `moonbit-community/flate` directly for that).
//
// Spec: https://www.rfc-editor.org/rfc/rfc1951

///|
/// Compress `data` into a raw DEFLATE stream (no zlib/gzip framing, no checksum).
fn flate_encode(data : Bytes) -> Bytes {
  @flate.deflate_all(data)
}

///|
/// Decompress a raw DEFLATE stream. Raises `ZipError` if the stream is malformed
/// or truncated.
fn flate_decode(data : Bytes) -> Bytes raise ZipError {
  @flate.inflate_all(data) catch {
    @flate.InflateError(msg) => raise ZipError("inflate: \{msg}")
  }
}
