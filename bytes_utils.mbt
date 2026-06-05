// Little-endian integer helpers for the byte-oriented ZIP container format.
// All multi-byte fields in a ZIP file are unsigned little-endian (APPNOTE 4.4).

///|
/// Read a 16-bit little-endian unsigned integer at `offset`.
fn read_u16_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
/// Read a 32-bit little-endian unsigned integer at `offset`, as a non-negative
/// `Int` (ZIP sizes/offsets fit in 31 bits for the archives we support).
fn read_u32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() |
  (data[offset + 1].to_int() << 8) |
  (data[offset + 2].to_int() << 16) |
  (data[offset + 3].to_int() << 24)
}

///|
/// Append a 16-bit little-endian integer to `buf`.
fn put_u16_le(buf : @buffer.Buffer, v : Int) -> Unit {
  buf.write_byte((v & 0xff).to_byte())
  buf.write_byte(((v >> 8) & 0xff).to_byte())
}

///|
/// Append a 32-bit little-endian integer to `buf`.
fn put_u32_le(buf : @buffer.Buffer, v : Int) -> Unit {
  buf.write_byte((v & 0xff).to_byte())
  buf.write_byte(((v >> 8) & 0xff).to_byte())
  buf.write_byte(((v >> 16) & 0xff).to_byte())
  buf.write_byte(((v >> 24) & 0xff).to_byte())
}
