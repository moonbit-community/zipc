// Error type for the deflate codec.
//
// All fallible operations in this package (`inflate`, `zlib_decompress`,
// `gzip_decompress`, `gzip_read_metadata`) signal failure by raising
// `DeflateError` with a human-readable message describing what went wrong
// (truncated input, bad header, checksum mismatch, ...).

///|
pub suberror DeflateError {
  DeflateError(String)
}

///|
pub impl Show for DeflateError with fn output(self, logger) {
  let DeflateError(msg) = self
  logger.write_string("DeflateError(\{msg})")
}
