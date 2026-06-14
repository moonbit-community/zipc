// ZIP archive container (in memory), byte-native.
//
// Ported in spirit from Daniel Bünzli's OCaml `zipc`. The archive is a set of
// members keyed by path; each member is either a directory or a file. File data
// is held as the *stored bytes* (either raw `Stored` data or a raw DEFLATE
// stream) together with its uncompressed size and CRC-32, exactly as it appears
// on disk — so parsing and serialising round-trip without recompressing.
//
// Only the `Stored` and `Deflate` methods are produced and extracted natively;
// other methods round-trip as opaque `Other` payloads.
//
// Spec: ZIP APPNOTE — https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT

// Errors

///|
pub suberror ZipError {
  ZipError(String)
}

///|
pub impl Show for ZipError with fn output(self, logger) {
  let ZipError(msg) = self
  logger.write_string("ZipError(\{msg})")
}

// Limits and constants

///|
/// Unix timestamp of the DOS epoch (1980-01-01 00:00:00 UTC), the earliest time
/// representable in a ZIP entry.
pub let dos_epoch : Int = 315532800

///|
/// Maximum number of members in a ZIP32 archive.
let max_members : Int = 65535

///|
let local_file_header_sig : Int = 0x04034b50

///|
let central_dir_sig : Int = 0x02014b50

///|
let eocd_sig : Int = 0x06054b50

///|
/// "version made by": high byte 3 = Unix (so the external-attribute mode bits
/// are honoured), low byte 20 = ZIP 2.0.
let version_made_by : Int = 0x0314

///|
/// "version needed to extract": 2.0 (DEFLATE support).
let version_needed : Int = 20

///|
/// General-purpose bit flag: bit 11 = filename/comment are UTF-8.
let gp_flags_utf8 : Int = 0x800

// Compression

///|
pub enum Compression {
  Stored
  Deflate
  Other(Int)
} derive(Eq)

///|
pub impl Show for Compression with fn output(self, logger) {
  match self {
    Stored => logger.write_string("Stored")
    Deflate => logger.write_string("Deflate")
    Other(m) => logger.write_string("Other(\{m})")
  }
}

///|
/// The numeric ZIP compression-method code for a `Compression`.
fn Compression::method_code(self : Compression) -> Int {
  match self {
    Stored => 0
    Deflate => 8
    Other(m) => m
  }
}

///|
fn Compression::from_method_code(code : Int) -> Compression {
  match code {
    0 => Stored
    8 => Deflate
    m => Other(m)
  }
}

// File

///|
/// A file's data as it is stored in the archive.
///
/// `data` is the on-disk payload: the raw bytes for `Stored`, or a raw DEFLATE
/// stream for `Deflate`. `decompressed_size` and `decompressed_crc32` describe
/// the *original* content.
pub struct File {
  compression : Compression
  data : Bytes
  decompressed_size : Int
  decompressed_crc32 : Int
}

///|
/// CRC-32 of `data`, as a 32-bit value held in an `Int`. Computed with
/// `moonbit-community/flate/checksum` (standard IEEE CRC-32, polynomial
/// 0xedb88320).
fn crc32_of(data : Bytes) -> Int {
  @checksum.crc32(data).reinterpret_as_int()
}

///|
/// Create a `Stored` (uncompressed) file from `data`.
pub fn File::stored_from_bytes(data : Bytes) -> File {
  {
    compression: Stored,
    data,
    decompressed_size: data.length(),
    decompressed_crc32: crc32_of(data),
  }
}

///|
/// Create a `Deflate`-compressed file from `data`. If compression does not
/// shrink the data (e.g. already-compressed or tiny inputs), the file is stored
/// uncompressed instead.
///
/// Example:
///
/// ```mbt nocheck
/// test {
///   let file = @zipc.File::deflate_from_bytes(b"aaaaaaaaaaaaaaaaaaaaaaaaaaaa")
///   inspect(file.compression(), content="Deflate")
///   assert_eq(file.to_bytes(), b"aaaaaaaaaaaaaaaaaaaaaaaaaaaa")
/// }
/// ```
pub fn File::deflate_from_bytes(data : Bytes) -> File {
  let compressed = flate_encode(data)
  if compressed.length() >= data.length() {
    File::stored_from_bytes(data)
  } else {
    {
      compression: Deflate,
      data: compressed,
      decompressed_size: data.length(),
      decompressed_crc32: crc32_of(data),
    }
  }
}

///|
pub fn File::compression(self : File) -> Compression {
  self.compression
}

///|
/// Size of the stored (possibly compressed) payload, in bytes.
pub fn File::compressed_size(self : File) -> Int {
  self.data.length()
}

///|
pub fn File::decompressed_size(self : File) -> Int {
  self.decompressed_size
}

///|
pub fn File::decompressed_crc32(self : File) -> Int {
  self.decompressed_crc32
}

///|
/// Whether this file can be decompressed natively (`Stored` or `Deflate`).
pub fn File::can_extract(self : File) -> Bool {
  match self.compression {
    Stored | Deflate => true
    Other(_) => false
  }
}

///|
/// Decompress the file back to its original bytes, verifying the CRC-32.
/// Raises `ZipError` for unsupported methods or on a CRC / size mismatch.
pub fn File::to_bytes(self : File) -> Bytes raise ZipError {
  let out = match self.compression {
    Stored => self.data
    Deflate => flate_decode(self.data)
    Other(m) => raise ZipError("unsupported compression method \{m}")
  }
  if out.length() != self.decompressed_size {
    raise ZipError("decompressed size mismatch")
  }
  if crc32_of(out) != self.decompressed_crc32 {
    raise ZipError("CRC-32 mismatch")
  }
  out
}

// Member

///|
pub(all) enum MemberKind {
  Dir
  File(File)
}

///|
/// An archive member: a path plus its kind, Unix mode and modification time
/// (Unix seconds).
pub struct Member {
  path : String
  mode : Int
  mtime : Int
  kind : MemberKind
}

///|
/// Normalise a member path: backslashes become forward slashes, and directories
/// gain a trailing slash.
fn normalize_path(path : String, kind : MemberKind) -> String {
  let p = path.replace_all(old="\\", new="/")
  match kind {
    Dir =>
      if p.is_empty() {
        "./"
      } else if p.has_suffix("/") {
        p
      } else {
        p + "/"
      }
    File(_) => p
  }
}

///|
/// Build a member. `mode` defaults to 0o755 for directories and 0o644 for files;
/// `mtime` defaults to the DOS epoch. Raises `ZipError` if the path is too long.
pub fn Member::make(
  path : String,
  kind : MemberKind,
  mode? : Int,
  mtime? : Int = dos_epoch,
) -> Member raise ZipError {
  let default_mode = match kind {
    Dir => 0o755
    File(_) => 0o644
  }
  let p = normalize_path(path, kind)
  if @utf8.encode(p[:]).length() > 0xffff {
    raise ZipError("path too long")
  }
  { path: p, mode: mode.unwrap_or(default_mode), mtime, kind }
}

///|
pub fn Member::path(self : Member) -> String {
  self.path
}

///|
pub fn Member::mode(self : Member) -> Int {
  self.mode
}

///|
pub fn Member::mtime(self : Member) -> Int {
  self.mtime
}

///|
pub fn Member::kind(self : Member) -> MemberKind {
  self.kind
}

///|
/// Whether this member is a directory.
pub fn Member::is_dir(self : Member) -> Bool {
  self.kind is Dir
}

// Archive

///|
/// An in-memory ZIP archive: a set of members keyed by path.
pub struct Archive {
  members : Map[String, Member]
}

///|
pub fn Archive::empty() -> Archive {
  { members: {} }
}

///|
pub fn Archive::is_empty(self : Archive) -> Bool {
  self.members.is_empty()
}

///|
pub fn Archive::member_count(self : Archive) -> Int {
  self.members.length()
}

///|
/// Whether a member with `path` exists.
pub fn Archive::mem(self : Archive, path : String) -> Bool {
  self.members.contains(path)
}

///|
/// Look up the member at `path`.
pub fn Archive::find(self : Archive, path : String) -> Member? {
  self.members.get(path)
}

///|
/// Add (or replace) a member, keyed by its (already normalised) path. Mutates
/// and returns the archive for chaining.
pub fn Archive::add(self : Archive, mem : Member) -> Archive {
  self.members[mem.path] = mem
  self
}

///|
/// Remove the member at `path`, if present.
pub fn Archive::remove(self : Archive, path : String) -> Archive {
  self.members.remove(path)
  self
}

///|
/// The members, sorted by path (so serialisation is deterministic).
pub fn Archive::to_array(self : Archive) -> Array[Member] {
  let members = self.members.values().collect()
  members.sort_by_key(m => m.path)
  members
}

///|
/// Apply `f` to each member, in path order.
pub fn Archive::each(self : Archive, f : (Member) -> Unit) -> Unit {
  for m in self.to_array() {
    f(m)
  }
}

// Encoding

///|
/// Serialise the archive to ZIP bytes. Members are written in path order, so the
/// output is deterministic. Parse it back with `Archive::from_bytes`.
///
/// Example:
///
/// ```mbt nocheck
/// test {
///   let archive = @zipc.Archive::empty()
///   archive.add(
///     @zipc.Member::make("hi.txt", File(@zipc.File::stored_from_bytes(b"hi"))),
///   )
///   |> ignore
///   let bytes = archive.to_bytes()
///   let parsed = @zipc.Archive::from_bytes(bytes)
///   guard parsed.find("hi.txt").unwrap().kind() is File(f)
///   assert_eq(f.to_bytes(), b"hi")
/// }
/// ```
pub fn Archive::to_bytes(self : Archive) -> Bytes raise ZipError {
  if self.member_count() > max_members {
    raise ZipError("too many members")
  }
  let body = Buffer()
  let central = Buffer()
  let members = self.to_array()
  for m in members {
    let offset = body.length()
    write_local_header(body, m)
    write_central_entry(central, m, offset)
  }
  let cd_offset = body.length()
  let cd_size = central.length()
  // local headers + data, then central directory, then EOCD
  body.write_bytes(central.to_bytes()[:])
  write_eocd(body, members.length(), cd_size, cd_offset)
  body.to_bytes()
}

///|
fn write_local_header(buf : @buffer.Buffer, m : Member) -> Unit {
  let name = @utf8.encode(m.path[:])
  let (dos_time, dos_date) = unix_to_dos_datetime(m.mtime)
  let (meth, crc, csize, usize, data) = match m.kind {
    Dir => (0, 0, 0, 0, b"")
    File(f) =>
      (
        f.compression.method_code(),
        f.decompressed_crc32,
        f.data.length(),
        f.decompressed_size,
        f.data,
      )
  }
  put_u32_le(buf, local_file_header_sig)
  put_u16_le(buf, version_needed)
  put_u16_le(buf, gp_flags_utf8)
  put_u16_le(buf, meth)
  put_u16_le(buf, dos_time)
  put_u16_le(buf, dos_date)
  put_u32_le(buf, crc)
  put_u32_le(buf, csize)
  put_u32_le(buf, usize)
  put_u16_le(buf, name.length())
  put_u16_le(buf, 0) // extra field length
  buf.write_bytes(name[:])
  buf.write_bytes(data[:])
}

///|
fn write_central_entry(
  buf : @buffer.Buffer,
  m : Member,
  local_offset : Int,
) -> Unit {
  let name = @utf8.encode(m.path[:])
  let (dos_time, dos_date) = unix_to_dos_datetime(m.mtime)
  let (meth, crc, csize, usize) = match m.kind {
    Dir => (0, 0, 0, 0)
    File(f) =>
      (
        f.compression.method_code(),
        f.decompressed_crc32,
        f.data.length(),
        f.decompressed_size,
      )
  }
  // External attributes: Unix mode in the high 16 bits, MS-DOS directory bit in
  // the low byte for directories.
  let dir_bit = if m.is_dir() { 0x10 } else { 0 }
  let external_attrs = (m.mode << 16) | dir_bit
  put_u32_le(buf, central_dir_sig)
  put_u16_le(buf, version_made_by)
  put_u16_le(buf, version_needed)
  put_u16_le(buf, gp_flags_utf8)
  put_u16_le(buf, meth)
  put_u16_le(buf, dos_time)
  put_u16_le(buf, dos_date)
  put_u32_le(buf, crc)
  put_u32_le(buf, csize)
  put_u32_le(buf, usize)
  put_u16_le(buf, name.length())
  put_u16_le(buf, 0) // extra field length
  put_u16_le(buf, 0) // comment length
  put_u16_le(buf, 0) // disk number start
  put_u16_le(buf, 0) // internal attributes
  put_u32_le(buf, external_attrs)
  put_u32_le(buf, local_offset)
  buf.write_bytes(name[:])
}

///|
fn write_eocd(
  buf : @buffer.Buffer,
  entry_count : Int,
  cd_size : Int,
  cd_offset : Int,
) -> Unit {
  put_u32_le(buf, eocd_sig)
  put_u16_le(buf, 0) // this disk
  put_u16_le(buf, 0) // disk with central directory
  put_u16_le(buf, entry_count) // entries on this disk
  put_u16_le(buf, entry_count) // total entries
  put_u32_le(buf, cd_size)
  put_u32_le(buf, cd_offset)
  put_u16_le(buf, 0) // archive comment length
}

// Decoding

///|
/// Whether `data` starts with a ZIP local-file-header or empty-archive EOCD
/// signature.
pub fn bytes_has_magic(data : Bytes) -> Bool {
  if data.length() < 4 {
    return false
  }
  let sig = read_u32_le(data, 0)
  sig == local_file_header_sig || sig == eocd_sig
}

///|
/// Scan backwards for the End Of Central Directory record's offset.
fn find_eocd(data : Bytes) -> Int? {
  let len = data.length()
  // `from_bytes` guarantees len >= 22 before calling this.
  // The EOCD is at the end except for an optional trailing comment (<= 65535).
  let mut i = len - 22
  let limit = if len - 22 - 0xffff > 0 { len - 22 - 0xffff } else { 0 }
  while i >= limit {
    if read_u32_le(data, i) == eocd_sig {
      return Some(i)
    }
    i -= 1
  }
  None
}

///|
/// Parse ZIP bytes into an archive. Raises `ZipError` on malformed input.
pub fn Archive::from_bytes(data : Bytes) -> Archive raise ZipError {
  if data.length() < 22 || !bytes_has_magic(data) {
    raise ZipError("not a ZIP archive")
  }
  let eocd = match find_eocd(data) {
    Some(o) => o
    None => raise ZipError("end of central directory record not found")
  }
  let entry_count = read_u16_le(data, eocd + 10)
  let cd_offset = read_u32_le(data, eocd + 16)
  let archive = Archive::empty()
  let mut offset = cd_offset
  for _ in 0..<entry_count {
    let (mem, next) = parse_central_entry(data, offset)
    archive.add(mem) |> ignore
    offset = next
  }
  archive
}

///|
/// Parse one central-directory entry starting at `offset`, returning the member
/// and the offset of the next entry.
fn parse_central_entry(
  data : Bytes,
  offset : Int,
) -> (Member, Int) raise ZipError {
  if offset + 46 > data.length() {
    raise ZipError("central directory entry truncated")
  }
  if read_u32_le(data, offset) != central_dir_sig {
    raise ZipError("bad central directory signature")
  }
  let version_made = read_u16_le(data, offset + 4)
  let method_code = read_u16_le(data, offset + 10)
  let dos_time = read_u16_le(data, offset + 12)
  let dos_date = read_u16_le(data, offset + 14)
  let crc = read_u32_le(data, offset + 16)
  let csize = read_u32_le(data, offset + 20)
  let usize = read_u32_le(data, offset + 24)
  let name_len = read_u16_le(data, offset + 28)
  let extra_len = read_u16_le(data, offset + 30)
  let comment_len = read_u16_le(data, offset + 32)
  let external_attrs = read_u32_le(data, offset + 38)
  let local_offset = read_u32_le(data, offset + 42)
  let name_start = offset + 46
  if name_start + name_len > data.length() {
    raise ZipError("central directory filename truncated")
  }
  let name = @utf8.decode_lossy(data[name_start:name_start + name_len])
  let compressed = read_local_data(data, local_offset, csize)
  let is_dir = name.has_suffix("/") || (external_attrs & 0x10) != 0

  // Unix mode lives in the high 16 bits of the external attributes, but only
  // when the archive was made on a Unix host (version-made-by high byte 3).
  let unix_mode = if version_made >> 8 == 3 {
    (external_attrs >> 16) & 0o7777
  } else {
    0
  }
  let mode = if unix_mode != 0 {
    unix_mode
  } else if is_dir {
    0o755
  } else {
    0o644
  }
  let mtime = dos_datetime_to_unix(dos_time, dos_date)
  let kind = if is_dir {
    MemberKind::Dir
  } else {
    File({
      compression: Compression::from_method_code(method_code),
      data: compressed,
      decompressed_size: usize,
      decompressed_crc32: crc,
    })
  }
  let mem = { path: name, mode, mtime, kind }
  (mem, offset + 46 + name_len + extra_len + comment_len)
}

///|
/// Read the compressed payload referenced by a central-directory entry by
/// following its local-header offset.
fn read_local_data(
  data : Bytes,
  local_offset : Int,
  csize : Int,
) -> Bytes raise ZipError {
  if local_offset + 30 > data.length() {
    raise ZipError("local header truncated")
  }
  if read_u32_le(data, local_offset) != local_file_header_sig {
    raise ZipError("bad local header signature")
  }
  let name_len = read_u16_le(data, local_offset + 26)
  let extra_len = read_u16_le(data, local_offset + 28)
  let start = local_offset + 30 + name_len + extra_len
  if start + csize > data.length() {
    raise ZipError("file data truncated")
  }
  data[start:start + csize].to_owned()
}
