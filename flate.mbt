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
/// Decompress one exactly framed raw DEFLATE stream, allowing at most
/// `decompressed_size` output bytes. ZIP records both compressed and
/// decompressed sizes, so accepting a valid DEFLATE prefix or growing output
/// past the declared size would violate the entry boundary.
fn flate_decode(data : Bytes, decompressed_size : Int) -> Bytes raise ZipError {
  if decompressed_size < 0 {
    raise ZipError("invalid decompressed size")
  }
  let inflater = @flate.Inflater::new()
  let scratch = FixedArray::make(32768, b'\x00')
  let out = Buffer()
  let mut pos = 0
  for ;; {
    let remaining = decompressed_size - out.length()
    // Keep one byte of headroom after the advertised size. If the stream
    // produces it, reject immediately without accumulating attacker-controlled
    // output. A one-byte view also lets an empty stream reach `Done`.
    let output_len = if remaining < scratch.length() {
      remaining + 1
    } else {
      scratch.length()
    }
    let (status, consumed, produced) = inflater.step(
      data[pos:],
      scratch.mut_view(end=output_len),
      end=true,
    ) catch {
      InflateError(msg) => raise ZipError("inflate: \{msg}")
    }
    pos = pos + consumed
    if produced > remaining {
      raise ZipError("decompressed size mismatch")
    }
    for i in 0..<produced {
      out.write_byte(scratch[i])
    }
    match status {
      Done => {
        if pos != data.length() {
          raise ZipError("inflate: trailing data")
        }
        return out.to_bytes()
      }
      NeedMoreOutput => continue
      NeedMoreInput => raise ZipError("inflate: unexpected end of input")
    }
  }
}
