// Regression: decoding a ZIP must preserve the unix permission bits stored in the
// high 16 bits of a member's external file attributes (notably the executable
// bit). The decoder used to hardcode 0o644 for every file, so an extracted tree
// lost exec bits and no longer hashed like `unzip` / a NAR content hash.

///|
test "decode preserves the unix executable bit through a round-trip" {
  let file = stored_of_binary_string("#!/bin/sh\necho hi\n")
  let m0 = match member_make("run.sh", File(file)) {
    Ok(m) => m
    Err(e) => {
      fail("member_make: \{e}")
    }
  }
  // Force the executable mode, encode, decode.
  let archive = add({ ..m0, mode: 0o755 }, empty())
  let bytes = match to_binary_string(archive) {
    Ok(b) => b
    Err(e) => fail("encode: \{e}")
  }
  let decoded = match of_binary_string(bytes) {
    Ok(a) => a
    Err(e) => fail("decode: \{e}")
  }
  let got = decoded.members.get("run.sh").unwrap()
  // The exec bit must survive (regression was: it came back 0o644).
  inspect((member_mode(got) & 0o111) != 0, content="true")
}
