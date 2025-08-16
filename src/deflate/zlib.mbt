// Zlib format decompression (RFC 1950)
// Zlib wraps deflate data with a header and Adler-32 checksum

// Decompress zlib format data
pub fn decompress(data : String, ~decompressed_size : Int = -1, ~start : Int = 0, ~len : Int = -1) -> Result[(String, @adler32.Adler32), (Option[(@adler32.Adler32, @adler32.Adler32)], String)] {
  let actual_len = if len == -1 { data.length() - start } else { len }
  
  if actual_len < 6 {
    return err((None, "Zlib data too short"))
  }
  
  let reader = @bitreader.new(data, ~start, ~len=actual_len)
  
  // Read zlib header (2 bytes)
  let cmf = match @bitreader.read_byte(reader) {
    Ok(b) => b
    Err(e) => return err((None, e))
  }
  
  let flg = match @bitreader.read_byte(reader) {
    Ok(b) => b
    Err(e) => return err((None, e))
  }
  
  // Check header checksum
  if (cmf * 256 + flg) % 31 != 0 {
    return err((None, "Invalid zlib header checksum"))
  }
  
  // Extract compression method and info
  let cm = cmf.land(0x0f)
  let cinfo = cmf.lsr(4)
  
  if cm != 8 {
    return err((None, "Unsupported compression method: \{cm}"))
  }
  
  if cinfo > 7 {
    return err((None, "Invalid compression info: \{cinfo}"))
  }
  
  // Check flags
  let fcheck = flg.land(0x1f)
  let fdict = (flg.land(0x20)) != 0
  let flevel = flg.lsr(6)
  
  if fdict {
    return err((None, "Preset dictionary not supported"))
  }
  
  // Calculate deflate data length (total - header - checksum)
  let deflate_len = actual_len - 2 - 4
  
  // Decompress deflate data
  let (decompressed, computed_adler) = match @inflate.inflate_and_adler32(data, ~decompressed_size, ~start=start + 2, ~len=deflate_len) {
    Ok(result) => result
    Err(e) => return err((None, e))
  }
  
  // Read and verify Adler-32 checksum (4 bytes, big-endian)
  let checksum_start = start + actual_len - 4
  let checksum_reader = @bitreader.new(data, ~start=checksum_start, ~len=4)
  
  let expected_adler = match read_adler32_be(checksum_reader) {
    Ok(adler) => adler
    Err(e) => return err((None, e))
  }
  
  if not(@adler32.equal(computed_adler, expected_adler)) {
    return err((Some((expected_adler, computed_adler)), "Adler-32 checksum mismatch"))
  }
  
  ok((decompressed, computed_adler))
}

// Read a 32-bit big-endian Adler-32 value
fn read_adler32_be(reader : BitReader) -> Result[@adler32.Adler32, String] {
  let b0 = match @bitreader.read_byte(reader) {
    Ok(b) => b.to_int64()
    Err(e) => return err(e)
  }
  
  let b1 = match @bitreader.read_byte(reader) {
    Ok(b) => b.to_int64()
    Err(e) => return err(e)
  }
  
  let b2 = match @bitreader.read_byte(reader) {
    Ok(b) => b.to_int64()
    Err(e) => return err(e)
  }
  
  let b3 = match @bitreader.read_byte(reader) {
    Ok(b) => b.to_int64()
    Err(e) => return err(e)
  }
  
  let adler = b0.lsl(24).lor(b1.lsl(16)).lor(b2.lsl(8)).lor(b3)
  ok(adler)
}
