// Robustness / error-path tests for the ZIP container: malformed input, every
// `raise ZipError` branch in the parser, opaque `Other` compression, and the
// accessor / collection surface that the happy-path tests don't reach.

///|
/// True if `thunk` raises (any error).
fn raises_zip(thunk : () -> Unit raise) -> Bool {
  try {
    thunk()
    false
  } catch {
    _ => true
  }
}

///|
/// A valid single-entry archive: stored file "a.txt" = b"xy".
fn base_archive() -> Array[Byte] raise {
  @zipc.Archive::empty()
  .add(@zipc.Member::make("a.txt", File(@zipc.File::stored_from_bytes(b"xy"))))
  .to_bytes()
  .to_array()
}

///|
/// Index of the first occurrence of the 4-byte little-endian signature `sig`.
fn find_sig(arr : Array[Byte], sig : UInt) -> Int {
  for i in 0..<(arr.length() - 3) {
    let v = arr[i].to_uint() |
      (arr[i + 1].to_uint() << 8) |
      (arr[i + 2].to_uint() << 16) |
      (arr[i + 3].to_uint() << 24)
    if v == sig {
      return i
    }
  }
  -1
}

///|
fn put_u32(arr : Array[Byte], off : Int, v : Int) -> Unit {
  arr[off] = (v & 0xff).to_byte()
  arr[off + 1] = ((v >> 8) & 0xff).to_byte()
  arr[off + 2] = ((v >> 16) & 0xff).to_byte()
  arr[off + 3] = ((v >> 24) & 0xff).to_byte()
}

///|
let central_sig : UInt = 0x02014b50

// --- malformed top-level input --------------------------------------------

///|
test "from_bytes rejects too-short and non-magic input" {
  assert_true(raises_zip(() => @zipc.Archive::from_bytes(b"") |> ignore))
  assert_true(raises_zip(() => @zipc.Archive::from_bytes(b"PK") |> ignore))
  assert_true(
    raises_zip(() => {
      @zipc.Archive::from_bytes(b"not a zip but long enough.............")
      |> ignore
    }),
  )
}

///|
test "from_bytes raises when the EOCD record is missing" {
  // Starts with a local-file-header magic (so bytes_has_magic passes) but has no
  // EOCD signature anywhere.
  let data : Bytes = [
    0x50, 0x4b, 0x03, 0x04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,
  ]
  assert_true(raises_zip(() => @zipc.Archive::from_bytes(data) |> ignore))
}

///|
test "from_bytes raises on a bad central-directory signature" {
  let arr = base_archive()
  let eocd = arr.length() - 22
  let cd_off = arr[eocd + 16].to_int() | (arr[eocd + 17].to_int() << 8)
  arr[cd_off] = 0xff // corrupt the central-dir signature
  assert_true(
    raises_zip(() => @zipc.Archive::from_bytes(Bytes::from_array(arr)) |> ignore),
  )
}

///|
test "from_bytes raises when the central directory is truncated" {
  let arr = base_archive()
  let eocd = arr.length() - 22
  // Point the central directory near the very end so offset + 46 overruns.
  put_u32(arr, eocd + 16, arr.length() - 4)
  assert_true(
    raises_zip(() => @zipc.Archive::from_bytes(Bytes::from_array(arr)) |> ignore),
  )
}

///|
test "from_bytes raises on a bad local-header signature" {
  // Keep the file's leading magic intact (so the top-level check passes) but
  // point the central entry's local-header offset at a non-header location.
  let arr = base_archive()
  let c = find_sig(arr, central_sig)
  put_u32(arr, c + 42, 4) // local header offset -> mid local header (no signature)
  assert_true(
    raises_zip(() => @zipc.Archive::from_bytes(Bytes::from_array(arr)) |> ignore),
  )
}

///|
test "from_bytes raises when the local header overruns the buffer" {
  let arr = base_archive()
  let c = find_sig(arr, central_sig)
  put_u32(arr, c + 42, arr.length() - 5) // local offset so that +30 overruns
  assert_true(
    raises_zip(() => @zipc.Archive::from_bytes(Bytes::from_array(arr)) |> ignore),
  )
}

///|
test "from_bytes raises when local file data overruns the buffer" {
  let arr = base_archive()
  // Bloat the local header's extra-field length so the data range overruns.
  arr[28] = 0xff // local header extra field length low byte
  arr[29] = 0xff
  assert_true(
    raises_zip(() => @zipc.Archive::from_bytes(Bytes::from_array(arr)) |> ignore),
  )
}

///|
test "to_bytes raises when there are too many members" {
  let a = @zipc.Archive::empty()
  let empty = @zipc.File::stored_from_bytes(b"")
  for i in 0..<=65535 { // 65536 members, one over the ZIP32 limit
    a.add(@zipc.Member::make(i.to_string(), File(empty))) |> ignore
  }
  assert_true(raises_zip(() => a.to_bytes() |> ignore))
}

// --- per-entry extraction errors ------------------------------------------

///|
test "to_bytes raises 'CRC-32 mismatch' when the recorded CRC is wrong" {
  let arr = base_archive()
  let c = find_sig(arr, central_sig)
  put_u32(arr, c + 16, 0x12345678) // clobber the central-dir CRC field
  let archive = @zipc.Archive::from_bytes(Bytes::from_array(arr))
  guard archive.find("a.txt").unwrap().kind() is File(f)
  assert_true(raises_zip(() => f.to_bytes() |> ignore))
}

///|
test "Other compression: preserved (round-trips) but not extractable" {
  let arr = base_archive()
  let c = find_sig(arr, central_sig)
  arr[c + 10] = 99 // central-dir compression method = 99 (unknown)
  arr[c + 11] = 0
  let archive = @zipc.Archive::from_bytes(Bytes::from_array(arr))
  guard archive.find("a.txt").unwrap().kind() is File(f)
  inspect(f.compression(), content="Other(99)")
  inspect(f.can_extract(), content="false")
  assert_true(raises_zip(() => f.to_bytes() |> ignore))
  // The opaque entry must survive re-serialisation with its method intact.
  let again = @zipc.Archive::from_bytes(archive.to_bytes())
  guard again.find("a.txt").unwrap().kind() is File(f2)
  inspect(f2.compression(), content="Other(99)")
}

///|
test "to_bytes raises 'decompressed size mismatch' on a wrong stored size" {
  let arr = base_archive()
  let c = find_sig(arr, central_sig)
  put_u32(arr, c + 24, 9999) // central-dir uncompressed size, but data is 2 bytes
  let archive = @zipc.Archive::from_bytes(Bytes::from_array(arr))
  guard archive.find("a.txt").unwrap().kind() is File(f)
  assert_true(raises_zip(() => f.to_bytes() |> ignore))
}

///|
test "from_bytes raises when a central filename is truncated" {
  let arr = base_archive()
  let c = find_sig(arr, central_sig)
  arr[c + 28] = 0xff // filename length = 0xffff, overruns the buffer
  arr[c + 29] = 0xff
  assert_true(
    raises_zip(() => @zipc.Archive::from_bytes(Bytes::from_array(arr)) |> ignore),
  )
}

///|
test "non-Unix host falls back to default modes" {
  // File from a non-Unix archive (version-made-by high byte != 3) → 0o644.
  let arr = base_archive()
  let c = find_sig(arr, central_sig)
  arr[c + 5] = 0 // version-made-by high byte = 0 (DOS/FAT, not Unix)
  let archive = @zipc.Archive::from_bytes(Bytes::from_array(arr))
  inspect(archive.find("a.txt").unwrap().mode(), content="420") // 0o644
  // Directory from a non-Unix archive → 0o755.
  let darr = @zipc.Archive::empty()
    .add(@zipc.Member::make("d", Dir))
    .to_bytes()
    .to_array()
  let dc = find_sig(darr, central_sig)
  darr[dc + 5] = 0
  let darch = @zipc.Archive::from_bytes(Bytes::from_array(darr))
  inspect(darch.find("d/").unwrap().mode(), content="493") // 0o755
}

///|
test "bytes_has_magic edge cases" {
  inspect(@zipc.bytes_has_magic(b"PK"), content="false") // too short
  inspect(@zipc.bytes_has_magic(b"junk"), content="false") // wrong signature
  inspect(
    @zipc.bytes_has_magic(@zipc.Archive::empty().to_bytes()),
    content="true",
  )
}

///|
test "empty directory path normalises to './'" {
  let m = @zipc.Member::make("", Dir)
  inspect(m.path(), content="./")
  inspect(m.is_dir(), content="true")
}

///|
test "ZipError has a readable Show" {
  let msg = try {
    @zipc.Archive::from_bytes(b"") |> ignore
    ""
  } catch {
    e => "\{e}"
  }
  inspect(msg, content="ZipError(not a ZIP archive)")
}

// --- construction limits ---------------------------------------------------

///|
test "Member::make raises on an over-long path" {
  let long = String::make(70000, 'a') // > 65535 bytes once UTF-8 encoded
  assert_true(
    raises_zip(() => {
      @zipc.Member::make(long, File(@zipc.File::stored_from_bytes(b"")))
      |> ignore
    }),
  )
}

// --- accessor / collection surface ----------------------------------------

///|
test "File and Member accessors" {
  let f = @zipc.File::stored_from_bytes(b"hello")
  inspect(f.can_extract(), content="true")
  inspect(f.compressed_size(), content="5")
  inspect(f.decompressed_size(), content="5")
  // CRC-32("hello") = 907060870 (verified against Python zlib.crc32)
  inspect(f.decompressed_crc32(), content="907060870")
  let m = @zipc.Member::make("p/q.txt", File(f), mode=0o600, mtime=315532800)
  inspect(m.path(), content="p/q.txt")
  inspect(m.mode(), content="384") // 0o600
  inspect(m.is_dir(), content="false")
  let d = @zipc.Member::make("dir", Dir)
  inspect(d.is_dir(), content="true")
}

///|
test "Archive remove / mem / each" {
  let a = @zipc.Archive::empty()
  a.add(@zipc.Member::make("x", File(@zipc.File::stored_from_bytes(b"1"))))
  |> ignore
  a.add(@zipc.Member::make("y", File(@zipc.File::stored_from_bytes(b"2"))))
  |> ignore
  inspect(a.member_count(), content="2")
  a.remove("x") |> ignore
  inspect(a.mem("x"), content="false")
  inspect(a.mem("y"), content="true")
  let seen = []
  a.each(m => seen.push(m.path()))
  inspect(seen.length(), content="1")
  assert_true(seen[0] == "y")
}
