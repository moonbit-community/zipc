// Tests for the ZIP archive container.
//
// Coverage:
//  - round-trips (empty / stored / deflate / multi-member / directories)
//  - Unix mode and mtime preservation
//  - interop: parsing and extracting a real archive written by Python's
//    `zipfile` (deflated, Unix host)
//  - the deflate constructor falls back to stored for incompressible data
//  - error handling on malformed input and corrupted entries

///|
/// `b"hello, zip world!\n"` repeated `n` times.
fn repeat_unit(n : Int) -> Bytes {
  let unit = b"hello, zip world!\n"
  let arr : Array[Byte] = []
  for _ in 0..<n {
    for i in 0..<unit.length() {
      arr.push(unit[i])
    }
  }
  Bytes::from_array(arr)
}

///|
test "empty archive round-trips" {
  let a = @zipc.Archive::empty()
  let bytes = a.to_bytes()
  assert_true(@zipc.bytes_has_magic(bytes))
  let b = @zipc.Archive::from_bytes(bytes)
  inspect(b.member_count(), content="0")
  inspect(b.is_empty(), content="true")
}

///|
test "stored file round-trips" {
  let content = b"the quick brown fox"
  let file = @zipc.File::stored_from_bytes(content)
  let mem = @zipc.Member::make("fox.txt", File(file))
  let bytes = @zipc.Archive::empty().add(mem).to_bytes()
  let archive = @zipc.Archive::from_bytes(bytes)
  inspect(archive.member_count(), content="1")
  let got = archive.find("fox.txt").unwrap()
  guard got.kind() is File(f)
  inspect(f.compression(), content="Stored")
  assert_eq(f.to_bytes(), content)
}

///|
test "deflate file round-trips and compresses" {
  let content = repeat_unit(50) // 900 bytes, highly compressible
  let file = @zipc.File::deflate_from_bytes(content)
  inspect(file.compression(), content="Deflate")
  assert_true(file.compressed_size() < content.length() / 2)
  let bytes = @zipc.Archive::empty()
    .add(@zipc.Member::make("data.txt", File(file)))
    .to_bytes()
  let archive = @zipc.Archive::from_bytes(bytes)
  guard archive.find("data.txt").unwrap().kind() is File(f)
  inspect(f.compression(), content="Deflate")
  assert_eq(f.to_bytes(), content)
}

///|
test "multi-member archive with a directory round-trips" {
  let a = @zipc.Archive::empty()
  a.add(
    @zipc.Member::make("readme.txt", File(@zipc.File::stored_from_bytes(b"hi"))),
  )
  |> ignore
  a.add(
    @zipc.Member::make(
      "src/main.mbt",
      File(@zipc.File::deflate_from_bytes(repeat_unit(20))),
    ),
  )
  |> ignore
  a.add(@zipc.Member::make("src", Dir)) |> ignore
  let archive = @zipc.Archive::from_bytes(a.to_bytes())
  inspect(archive.member_count(), content="3")
  assert_true(archive.mem("readme.txt"))
  assert_true(archive.mem("src/")) // directories gain a trailing slash
  assert_true(archive.find("src/").unwrap().is_dir())
  assert_eq(
    archive.find("readme.txt").unwrap().kind() is File(f) &&
    f.to_bytes() == b"hi",
    true,
  )
}

///|
test "Unix mode and mtime are preserved" {
  let file = @zipc.File::stored_from_bytes(b"#!/bin/sh\necho hi\n")
  let mem = @zipc.Member::make(
    "run.sh",
    File(file),
    mode=0o755,
    mtime=978307200, // 2001-01-01
  )
  let archive = @zipc.Archive::from_bytes(
    @zipc.Archive::empty().add(mem).to_bytes(),
  )
  let got = archive.find("run.sh").unwrap()
  inspect(got.mode(), content="493") // 0o755
  inspect(got.mtime(), content="978307200")
}

///|
test "parses and extracts a real Python zipfile archive" {
  // greeting.txt = b"hello, zip world!\n" * 20, DEFLATE, mode 0644, Unix host.
  let real : Bytes = [
    80, 75, 3, 4, 20, 0, 0, 0, 8, 0, 0, 0, 33, 82, 151, 120, 121, 180, 25, 0, 0,
    0, 104, 1, 0, 0, 12, 0, 0, 0, 103, 114, 101, 101, 116, 105, 110, 103, 46, 116,
    120, 116, 203, 72, 205, 201, 201, 215, 81, 168, 202, 44, 80, 40, 207, 47, 202,
    73, 81, 228, 202, 24, 21, 161, 129, 8, 0, 80, 75, 1, 2, 20, 3, 20, 0, 0, 0, 8,
    0, 0, 0, 33, 82, 151, 120, 121, 180, 25, 0, 0, 0, 104, 1, 0, 0, 12, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 164, 1, 0, 0, 0, 0, 103, 114, 101, 101, 116, 105, 110,
    103, 46, 116, 120, 116, 80, 75, 5, 6, 0, 0, 0, 0, 1, 0, 1, 0, 58, 0, 0, 0, 67,
    0, 0, 0, 0, 0,
  ]
  assert_true(@zipc.bytes_has_magic(real))
  let archive = @zipc.Archive::from_bytes(real)
  inspect(archive.member_count(), content="1")
  let got = archive.find("greeting.txt").unwrap()
  inspect(got.mode(), content="420") // 0o644
  guard got.kind() is File(f)
  inspect(f.compression(), content="Deflate")
  assert_eq(f.to_bytes(), repeat_unit(20))
}

///|
test "deflate constructor falls back to stored for incompressible data" {
  // A tiny input cannot be shrunk by DEFLATE framing.
  let file = @zipc.File::deflate_from_bytes(b"x")
  inspect(file.compression(), content="Stored")
  assert_eq(file.to_bytes(), b"x")
}

///|
test "serialization is deterministic regardless of insertion order" {
  // Two archives with the same members added in different orders must produce
  // byte-identical output (members are written in path order).
  let a = @zipc.Archive::empty()
  a.add(
    @zipc.Member::make("b.txt", File(@zipc.File::stored_from_bytes(b"two"))),
  )
  |> ignore
  a.add(
    @zipc.Member::make(
      "a.txt",
      File(@zipc.File::deflate_from_bytes(repeat_unit(30))),
    ),
  )
  |> ignore
  a.add(@zipc.Member::make("c/", Dir)) |> ignore
  let b = @zipc.Archive::empty()
  b.add(@zipc.Member::make("c/", Dir)) |> ignore
  b.add(
    @zipc.Member::make(
      "a.txt",
      File(@zipc.File::deflate_from_bytes(repeat_unit(30))),
    ),
  )
  |> ignore
  b.add(
    @zipc.Member::make("b.txt", File(@zipc.File::stored_from_bytes(b"two"))),
  )
  |> ignore
  assert_eq(a.to_bytes(), b.to_bytes())
  // and serialising the same archive twice is stable
  assert_eq(a.to_bytes(), a.to_bytes())
}

///|
test "from_bytes rejects non-ZIP input" {
  let garbage : Bytes = b"this is definitely not a zip file at all!!"
  assert_true(
    try {
      @zipc.Archive::from_bytes(garbage) |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "to_bytes detects a corrupted deflate payload" {
  // Build an archive, then flip a byte inside the stored DEFLATE stream. The
  // central directory (and thus the recorded CRC-32) is untouched, so parsing
  // still succeeds but extraction must fail.
  let bytes = @zipc.Archive::empty()
    .add(
      @zipc.Member::make(
        "data.txt",
        File(@zipc.File::deflate_from_bytes(repeat_unit(50))),
      ),
    )
    .to_bytes()
  let arr = bytes.to_array()
  // Local header is 30 bytes + 8-byte name "data.txt"; the deflate payload
  // begins at offset 38. Flip a byte well inside it.
  arr[44] = (arr[44].to_int() ^ 0xff).to_byte()
  let archive = @zipc.Archive::from_bytes(Bytes::from_array(arr))
  guard archive.find("data.txt").unwrap().kind() is File(f)
  assert_true(
    try {
      f.to_bytes() |> ignore
      false
    } catch {
      _ => true
    },
  )
}
