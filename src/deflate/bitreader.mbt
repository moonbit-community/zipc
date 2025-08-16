// Bit reader for deflate decompression
// Reads bits from a byte stream in LSB-first order

pub struct BitReader {
  data : String
  mut pos : Int      // Current byte position
  mut bit_pos : Int  // Current bit position within byte (0-7)
  len : Int          // Total length of data
}

// Create a new bit reader
pub fn new(data : String, ~start : Int = 0, ~len : Int = -1) -> BitReader {
  let actual_len = if len == -1 { data.length() - start } else { len }
  { data, pos: start, bit_pos: 0, len: start + actual_len }
}

// Check if there are more bits to read
pub fn has_bits(reader : BitReader) -> Bool {
  reader.pos < reader.len || (reader.pos == reader.len && reader.bit_pos > 0)
}

// Read a single bit (returns 0 or 1)
pub fn read_bit(reader : BitReader) -> Result[Int, String] {
  if reader.pos >= reader.len {
    return err("Unexpected end of data")
  }
  
  let byte = reader.data[reader.pos].to_int()
  let bit = (byte.lsr(reader.bit_pos)).land(1)
  
  reader.bit_pos = reader.bit_pos + 1
  if reader.bit_pos >= 8 {
    reader.bit_pos = 0
    reader.pos = reader.pos + 1
  }
  
  ok(bit)
}

// Read multiple bits (up to 32 bits, LSB first)
pub fn read_bits(reader : BitReader, count : Int) -> Result[Int, String] {
  if count <= 0 || count > 32 {
    return err("Invalid bit count: \{count}")
  }
  
  let mut result = 0
  for i = 0; i < count; i = i + 1 {
    match read_bit(reader) {
      Ok(bit) => result = result.lor(bit.lsl(i))
      Err(e) => return err(e)
    }
  }
  ok(result)
}

// Align to next byte boundary
pub fn align_byte(reader : BitReader) -> Unit {
  if reader.bit_pos != 0 {
    reader.bit_pos = 0
    reader.pos = reader.pos + 1
  }
}

// Read a byte (aligned)
pub fn read_byte(reader : BitReader) -> Result[Int, String] {
  align_byte(reader)
  if reader.pos >= reader.len {
    return err("Unexpected end of data")
  }
  
  let byte = reader.data[reader.pos].to_int()
  reader.pos = reader.pos + 1
  ok(byte)
}

// Read multiple bytes
pub fn read_bytes(reader : BitReader, count : Int) -> Result[String, String] {
  align_byte(reader)
  if reader.pos + count > reader.len {
    return err("Not enough data for \{count} bytes")
  }
  
  let result = reader.data.substring(~start=reader.pos, ~end=reader.pos + count)
  reader.pos = reader.pos + count
  ok(result)
}

// Read a 16-bit little-endian value
pub fn read_u16_le(reader : BitReader) -> Result[Int, String] {
  match read_bytes(reader, 2) {
    Ok(bytes) => {
      let low = bytes[0].to_int()
      let high = bytes[1].to_int()
      ok(low.lor(high.lsl(8)))
    }
    Err(e) => err(e)
  }
}

// Read a 32-bit little-endian value  
pub fn read_u32_le(reader : BitReader) -> Result[Int64, String] {
  match read_bytes(reader, 4) {
    Ok(bytes) => {
      let b0 = bytes[0].to_int().to_int64()
      let b1 = bytes[1].to_int().to_int64()
      let b2 = bytes[2].to_int().to_int64()
      let b3 = bytes[3].to_int().to_int64()
      ok(b0.lor(b1.lsl(8)).lor(b2.lsl(16)).lor(b3.lsl(24)))
    }
    Err(e) => err(e)
  }
}

// Get current position in bits
pub fn position_bits(reader : BitReader) -> Int {
  reader.pos * 8 + reader.bit_pos
}

// Get remaining bytes
pub fn remaining_bytes(reader : BitReader) -> Int {
  let remaining = reader.len - reader.pos
  if reader.bit_pos > 0 { remaining - 1 } else { remaining }
}
