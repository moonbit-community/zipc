// Whitebox tests for the private DOS date/time conversions.
//
// Coverage mirrors the encoder/decoder's real needs: exact round-trips on
// even-second UTC instants, the pre-epoch clamp, leap-year handling, the
// invalid-field fallback, and DOS's 2-second precision.

///|
/// Round-trip a Unix timestamp through DOS packing and back.
fn dos_roundtrip(unix : Int) -> Int {
  let (t, d) = unix_to_dos_datetime(unix)
  dos_datetime_to_unix(t, d)
}

///|
test "unix<->dos round-trips exactly on even-second UTC instants" {
  // 2022-01-01, leap-day 2020-02-29, last day of leap year 2020-12-31, DOS epoch.
  for unix in [1640995200, 1582934400, 1609372800, dos_epoch] {
    assert_eq(dos_roundtrip(unix), unix)
  }
}

///|
test "timestamps at or before the DOS epoch clamp to 1980-01-01" {
  let (t, d) = unix_to_dos_datetime(dos_epoch - 86400)
  assert_eq(t, 0)
  assert_eq(d, 0x0021) // 1980-01-01 00:00:00
  assert_eq(dos_datetime_to_unix(t, d), dos_epoch)
}

///|
test "leap-day 2020-02-29 decodes to the right instant" {
  let dos_date = (40 << 9) | (2 << 5) | 29 // year 2020, month 2, day 29
  assert_eq(dos_datetime_to_unix(0, dos_date), 1582934400)
}

///|
test "every month round-trips through dos packing" {
  for mo = 1; mo <= 12; mo = mo + 1 {
    let dos_date = (42 << 9) | (mo << 5) | 15 // 2022-mm-15
    let unix = dos_datetime_to_unix(0, dos_date)
    let (_, decoded) = unix_to_dos_datetime(unix)
    assert_eq(decoded, dos_date)
  }
}

///|
test "invalid or zero DOS fields fall back to the DOS epoch" {
  assert_eq(dos_datetime_to_unix(0xffff, 0xffff), dos_epoch)
  assert_eq(dos_datetime_to_unix(0, 0), dos_epoch)
}

///|
test "DOS time keeps 2-second precision (odd seconds round down)" {
  let (t, _) = unix_to_dos_datetime(dos_epoch + 31) // 1980-01-01 00:00:31
  assert_eq((t & 0x1f) * 2, 30)
}

///|
test "is_leap_year matches the Gregorian rule" {
  assert_true(is_leap_year(2020))
  assert_false(is_leap_year(2021))
  assert_false(is_leap_year(1900)) // divisible by 100 but not 400
  assert_true(is_leap_year(2000)) // divisible by 400
}
