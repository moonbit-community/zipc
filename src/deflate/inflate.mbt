// Deflate decompression (inflate) implementation

// Length and distance extra bits tables
let length_base = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
  35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
]

let length_extra = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
  3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
]

let distance_base = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
  257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
]

let distance_extra = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
  7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
]

// Output buffer for decompressed data
struct OutputBuffer {
  mut data : String
  mut pos : Int
  max_size : Int
}

fn new_output_buffer(max_size : Int) -> OutputBuffer {
  { data: "", pos: 0, max_size }
}

fn write_byte(buf : OutputBuffer, byte : Int) -> Result[Unit, String] {
  if buf.pos >= buf.max_size {
    return err("Output buffer overflow")
  }
  buf.data = buf.data + Char::from_int(byte).to_string()
  buf.pos = buf.pos + 1
  ok(())
}

fn copy_bytes(buf : OutputBuffer, distance : Int, length : Int) -> Result[Unit, String] {
  if distance > buf.pos {
    return err("Invalid distance: \{distance} > \{buf.pos}")
  }
  
  if buf.pos + length > buf.max_size {
    return err("Output buffer overflow")
  }
  
  let start_pos = buf.pos - distance
  for i = 0; i < length; i = i + 1 {
    let byte_pos = start_pos + (i % distance)
    let byte = buf.data[byte_pos].to_int()
    match write_byte(buf, byte) {
      Ok(_) => ()
      Err(e) => return err(e)
    }
  }
  ok(())
}

// Decode a length from a literal/length symbol
fn decode_length(symbol : Int, reader : BitReader) -> Result[Int, String] {
  if symbol < 257 {
    return err("Invalid length symbol: \{symbol}")
  }
  
  if symbol == 256 {
    return ok(0)  // End of block
  }
  
  if symbol > 285 {
    return err("Invalid length symbol: \{symbol}")
  }
  
  let index = symbol - 257
  let base = length_base[index]
  let extra_bits = length_extra[index]
  
  if extra_bits == 0 {
    ok(base)
  } else {
    match @bitreader.read_bits(reader, extra_bits) {
      Ok(extra) => ok(base + extra)
      Err(e) => err(e)
    }
  }
}

// Decode a distance from a distance symbol
fn decode_distance(symbol : Int, reader : BitReader) -> Result[Int, String] {
  if symbol >= 30 {
    return err("Invalid distance symbol: \{symbol}")
  }
  
  let base = distance_base[symbol]
  let extra_bits = distance_extra[symbol]
  
  if extra_bits == 0 {
    ok(base)
  } else {
    match @bitreader.read_bits(reader, extra_bits) {
      Ok(extra) => ok(base + extra)
      Err(e) => err(e)
    }
  }
}

// Inflate a compressed block
fn inflate_block(reader : BitReader, lit_tree : @huffman.HuffmanTree, dist_tree : @huffman.HuffmanTree, output : OutputBuffer) -> Result[Bool, String] {
  loop {
    let symbol = match @huffman.decode_symbol(lit_tree, reader) {
      Ok(s) => s
      Err(e) => return err(e)
    }
    
    if symbol < 256 {
      // Literal byte
      match write_byte(output, symbol) {
        Ok(_) => ()
        Err(e) => return err(e)
      }
    } else if symbol == 256 {
      // End of block
      return ok(true)
    } else {
      // Length/distance pair
      let length = match decode_length(symbol, reader) {
        Ok(len) => len
        Err(e) => return err(e)
      }
      
      let dist_symbol = match @huffman.decode_symbol(dist_tree, reader) {
        Ok(s) => s
        Err(e) => return err(e)
      }
      
      let distance = match decode_distance(dist_symbol, reader) {
        Ok(dist) => dist
        Err(e) => return err(e)
      }
      
      match copy_bytes(output, distance, length) {
        Ok(_) => ()
        Err(e) => return err(e)
      }
    }
  }
}

// Main inflate function
pub fn inflate(data : String, ~decompressed_size : Int = -1, ~start : Int = 0, ~len : Int = -1) -> Result[String, String] {
  let actual_len = if len == -1 { data.length() - start } else { len }
  let reader = @bitreader.new(data, ~start, ~len=actual_len)
  
  let max_size = if decompressed_size == -1 { 1048576 } else { decompressed_size }  // Default 1MB limit
  let output = new_output_buffer(max_size)
  
  let mut is_final = false
  
  while not(is_final) {
    // Read block header
    is_final = match @bitreader.read_bit(reader) {
      Ok(bit) => bit == 1
      Err(e) => return err(e)
    }
    
    let block_type = match @bitreader.read_bits(reader, 2) {
      Ok(t) => t
      Err(e) => return err(e)
    }
    
    match block_type {
      0 => {
        // Uncompressed block
        @bitreader.align_byte(reader)
        
        let len = match @bitreader.read_u16_le(reader) {
          Ok(l) => l
          Err(e) => return err(e)
        }
        
        let nlen = match @bitreader.read_u16_le(reader) {
          Ok(nl) => nl
          Err(e) => return err(e)
        }
        
        if len.lxor(nlen) != 0xffff {
          return err("Invalid uncompressed block length check")
        }
        
        let block_data = match @bitreader.read_bytes(reader, len) {
          Ok(data) => data
          Err(e) => return err(e)
        }
        
        for i = 0; i < block_data.length(); i = i + 1 {
          match write_byte(output, block_data[i].to_int()) {
            Ok(_) => ()
            Err(e) => return err(e)
          }
        }
      }
      1 => {
        // Fixed Huffman codes
        let lit_tree = @huffman.fixed_literal_tree()
        let dist_tree = @huffman.fixed_distance_tree()
        match inflate_block(reader, lit_tree, dist_tree, output) {
          Ok(_) => ()
          Err(e) => return err(e)
        }
      }
      2 => {
        // Dynamic Huffman codes
        let (lit_tree, dist_tree) = match @huffman.decode_dynamic_trees(reader) {
          Ok(trees) => trees
          Err(e) => return err(e)
        }
        match inflate_block(reader, lit_tree, dist_tree, output) {
          Ok(_) => ()
          Err(e) => return err(e)
        }
      }
      _ => return err("Invalid block type: \{block_type}")
    }
  }
  
  ok(output.data)
}

// Inflate with CRC-32 calculation
pub fn inflate_and_crc32(data : String, ~decompressed_size : Int = -1, ~start : Int = 0, ~len : Int = -1) -> Result[(String, @crc32.Crc32), String] {
  match inflate(data, ~decompressed_size, ~start, ~len) {
    Ok(result) => {
      let crc = @crc32.string(result)
      ok((result, crc))
    }
    Err(e) => err(e)
  }
}

// Inflate with Adler-32 calculation
pub fn inflate_and_adler32(data : String, ~decompressed_size : Int = -1, ~start : Int = 0, ~len : Int = -1) -> Result[(String, @adler32.Adler32), String] {
  match inflate(data, ~decompressed_size, ~start, ~len) {
    Ok(result) => {
      let adler = @adler32.string(result)
      ok((result, adler))
    }
    Err(e) => err(e)
  }
}
