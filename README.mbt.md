# zipc

A **typed, in-memory ZIP archive** library for MoonBit, ported in spirit from
the OCaml [zipc](https://github.com/dbuenzli/zipc) library.

Its focus is the *archive model*, not the codec: a value-oriented
`Archive` / `Member` / `File` API that preserves per-entry Unix mode and
modification time, produces deterministic (byte-stable) output, and verifies
CRC-32 on every decode. The DEFLATE compression itself is delegated to
[`moonbit-community/flate`](https://github.com/moonbit-community/flate) — a
pure-MoonBit, io-free DEFLATE engine with real LZ77 and fixed/dynamic Huffman
blocks.


## Scope

**In scope**

- A pure, in-memory ZIP archive value type: `Archive` / `Member` / `File` with
  `add` / `find` / `mem` / `remove` / `each` / `to_array`.
- Per-entry **Unix mode** and **mtime** preservation.
- **Deterministic** serialization (members written in path order).
- `Stored` and `Deflate` methods, produced and extracted natively, with CRC-32
  verified on decode.
- Byte-native throughout (`Bytes` in, `Bytes` out) — no lossy `String`
  round-trips.

**Non-goals** (use a dedicated library if you need these)

- **ZIP64** — archives are limited to 65535 members and ~2 GiB per entry
  (ZIP32). For larger archives, see `hustcer/fzip`.
- **Encryption**, **multi-part / split archives**, and **streaming** (the whole
  archive is held in memory for encode/decode).
- **Tunable compression levels** — the backend compresses at a single fast
  level. Choose per file between `File::stored_from_bytes` (no compression) and
  `File::deflate_from_bytes` (compressed).
- **Being a codec library.** No standalone DEFLATE/zlib/gzip surface is exposed;
  compression is an internal detail of reading and writing entries. For raw
  DEFLATE, zlib, gzip, streaming or dictionaries, use `moonbit-community/flate`,
  `moonbit-community/flate/zlib`, `moonbit-community/flate/gzip` directly.

Entries that use methods other than `Stored`/`Deflate` round-trip as opaque
`Compression::Other` payloads (they are preserved but not decoded).


## Archives — `moonbit-community/zipc`

Build an archive of members (files and directories), serialise it to ZIP bytes,
and parse it back. Unix mode and modification time are preserved.

```mbt nocheck
///|
test {
  // build
  let archive = @zipc.Archive::empty()
  archive.add(
    @zipc.Member::make(
      "readme.txt",
      File(@zipc.File::stored_from_bytes(b"hello")),
    ),
  )
  |> ignore
  archive.add(
    @zipc.Member::make(
      "src/data.bin",
      File(
        @zipc.File::deflate_from_bytes(b"compress me, compress me, compress me"),
      ),
      mode=0o644,
    ),
  )
  |> ignore
  let bytes = archive.to_bytes()

  // parse and extract
  let parsed = @zipc.Archive::from_bytes(bytes)
  guard parsed.find("readme.txt").unwrap().kind() is File(f)
  assert_eq(f.to_bytes(), b"hello")
}
```

`File::deflate_from_bytes` automatically falls back to `Stored` when DEFLATE would
not shrink the data. `File::to_bytes` verifies the entry's CRC-32 and size.

## Compared to other MoonBit options

- **`moonbit-community/flate`** (with its `gzip` / `zlib` wrappers) is a codec
  only — no ZIP *archive* layer. This library builds on it rather than competing
  with it.
- **`moonbitlang/async/gzip`** is a gzip stream transform for HTTP
  content-encoding; it is not a ZIP archive tool.
- **`hustcer/fzip`** (an `fflate` port) is the broader toolkit: more formats,
  streaming, ZIP64 *reading*, more mature. If you just want
  `zip_sync(files) -> bytes`, prefer it.

What this library offers that the others don't is the **typed, deterministic,
metadata-preserving archive model** — the right choice when you need reproducible
archives or faithful filesystem round-tripping (permissions and timestamps),
rather than just packing a bag of bytes.
