// LZ77 Encoder Implementation
// Implements sliding window compression with hash-based string matching

// Encode bytes using LZ77 compression
pub fn encode(data : Bytes, config : LZ77Config) -> Array[LZ77Token] {
  if data.length() == 0 {
    return []
  }
  
  let state = new_encoder_state(config)
  let mut result = []
  
  while state.position < data.length() {
    let token = find_best_match(data, state, config)
    result = result + [token]
    
    match token {
      LZ77Token::Literal(_) => {
        // Add literal to output
        state.position += 1
      }
      LZ77Token::Reference(length, _) => {
        // Add reference to output and advance position
        state.position += length
      }
    }
    
    // Update hash tables for the processed bytes
    update_hash_tables(data, state, config)
  }
  
  result
}

// Find the best match for the current position
fn find_best_match(data : Bytes, state : EncoderState, config : LZ77Config) -> LZ77Token {
  let pos = state.position
  
  // Need at least 3 bytes for a match
  if pos + 2 >= data.length() {
    return LZ77Token::Literal(data[pos])
  }
  
  // Calculate hash for current 3-byte sequence
  let hash = hash3(data[pos], data[pos + 1], data[pos + 2])
  let chain_head = state.hash_head[hash]
  
  if chain_head == -1 {
    // No previous occurrence of this hash
    return LZ77Token::Literal(data[pos])
  }
  
  // Search for the longest match
  let mut best_length = 0
  let mut best_distance = 0
  let mut current = chain_head
  let mut chain_count = 0
  let max_chain_length = 128 // Limit chain traversal for performance
  
  while current != -1 && chain_count < max_chain_length {
    let distance = pos - current
    
    // Check if distance is within bounds
    if distance > config.max_distance || distance <= 0 {
      break
    }
    
    // Check if this position is still within the sliding window
    if current < state.window_start {
      break
    }
    
    // Find match length
    let match_length = find_match_length(data, pos, current, config.max_match_length)
    
    if match_length >= config.min_match_length && match_length > best_length {
      best_length = match_length
      best_distance = distance
      
      // If we found the maximum possible match, stop searching
      if best_length == config.max_match_length {
        break
      }
    }
    
    current = state.hash_prev[current % config.window_size]
    chain_count += 1
  }
  
  if best_length >= config.min_match_length {
    LZ77Token::Reference(best_length, best_distance)
  } else {
    LZ77Token::Literal(data[pos])
  }
}

// Find the length of a match between two positions
fn find_match_length(data : Bytes, pos1 : Int, pos2 : Int, max_length : Int) -> Int {
  let mut length = 0
  let data_length = data.length()
  
  while length < max_length && 
        pos1 + length < data_length && 
        pos2 + length < data_length &&
        data[pos1 + length] == data[pos2 + length] {
    length += 1
  }
  
  length
}

// Update hash tables with new position
fn update_hash_tables(data : Bytes, state : EncoderState, config : LZ77Config) -> Unit {
  let pos = state.position
  
  // Update sliding window start
  if pos >= config.window_size {
    state.window_start = pos - config.window_size + 1
  }
  
  // Add current position to hash table if we have enough bytes
  if pos + 2 < data.length() {
    let hash = hash3(data[pos], data[pos + 1], data[pos + 2])
    let window_pos = pos % config.window_size
    
    // Update hash chain
    state.hash_prev[window_pos] = state.hash_head[hash]
    state.hash_head[hash] = pos
  }
}

// Encode with default configuration
pub fn encode_default(data : Bytes) -> Array[LZ77Token] {
  encode(data, default_config())
}

// Simple encode that returns a more practical format
pub fn encode_to_bytes(data : Bytes, config : LZ77Config) -> Bytes {
  let tokens = encode(data, config)
  let output = @buffer.new()
  
  for token in tokens {
    match token {
      LZ77Token::Literal(byte) => {
        // Format: 0 + byte (literal marker + byte)
        output.write_byte(b'\x00')
        output.write_byte(byte)
      }
      LZ77Token::Reference(length, distance) => {
        // Format: 1 + length_bytes + distance_bytes (reference marker + data)
        output.write_byte(b'\x01')
        write_varint(output, length)
        write_varint(output, distance)
      }
    }
  }
  
  output.to_bytes()
}

// Write variable-length integer (simple implementation)
fn write_varint(buffer : @buffer.T, value : Int) -> Unit {
  if value < 128 {
    buffer.write_byte(value.to_byte())
  } else {
    buffer.write_byte((value % 128 + 128).to_byte())
    write_varint(buffer, value / 128)
  }
}
