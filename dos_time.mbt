// DOS date/time conversion for ZIP entries.
//
// ZIP stores modification time as two packed 16-bit fields (APPNOTE 4.4.6):
//   time  bits 15-11 hours (0-23), 10-5 minutes (0-59), 4-0 seconds/2 (0-29)
//   date  bits 15-9  year-1980 (0-127), 8-5 month (1-12), 4-0 day (1-31)
// These helpers convert to and from Unix seconds (UTC). Only the two conversions
// the encoder/decoder needs are defined here, and both are private to the package.

///|
/// Days per month, indexed 0 (January) .. 11 (December), for a common year.
let days_in_month_common : FixedArray[Int] = [
  31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
]

///|
/// Days per month for a leap year (February has 29).
let days_in_month_leap : FixedArray[Int] = [
  31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
]

///|
fn days_in_months(is_leap : Bool) -> FixedArray[Int] {
  if is_leap {
    days_in_month_leap
  } else {
    days_in_month_common
  }
}

///|
fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
/// Convert a Unix timestamp (UTC seconds) to packed DOS (time, date) fields.
/// Timestamps at or before the DOS epoch clamp to 1980-01-01 00:00:00.
fn unix_to_dos_datetime(unix_timestamp : Int) -> (Int, Int) {
  if unix_timestamp <= dos_epoch {
    return (0, 0x0021) // 1980-01-01 00:00:00
  }
  let seconds_since_dos_epoch = unix_timestamp - dos_epoch
  let days_since_dos_epoch = seconds_since_dos_epoch / 86400
  let seconds_in_day = seconds_since_dos_epoch % 86400
  let hours = seconds_in_day / 3600
  let minutes = seconds_in_day % 3600 / 60
  let seconds = seconds_in_day % 60
  let dos_time = (hours << 11) | (minutes << 5) | (seconds / 2)

  // Walk whole years off the day count, then resolve month/day within the year.
  let (year, remaining_days) = for year = 1980, remaining_days = days_since_dos_epoch; remaining_days >=
                                  365; {
    let days_in_year = if is_leap_year(year) { 366 } else { 365 }
    if remaining_days >= days_in_year {
      continue year + 1, remaining_days - days_in_year
    } else {
      break (year, remaining_days)
    }
  } nobreak {
    (year, remaining_days)
  }
  let (month, day) = day_of_year_to_month_day(
    remaining_days + 1,
    is_leap_year(year),
  )
  let dos_date = ((year - 1980) << 9) | (month << 5) | day
  (dos_time, dos_date)
}

///|
/// Convert packed DOS (time, date) fields back to a Unix timestamp (UTC
/// seconds). Out-of-range fields fall back to the DOS epoch.
fn dos_datetime_to_unix(dos_time : Int, dos_date : Int) -> Int {
  let hours = (dos_time >> 11) & 0x1f
  let minutes = (dos_time >> 5) & 0x3f
  let seconds = (dos_time & 0x1f) * 2
  let year_offset = (dos_date >> 9) & 0x7f
  let month = (dos_date >> 5) & 0x0f
  let day = dos_date & 0x1f
  let year = 1980 + year_offset
  if month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31 ||
    hours > 23 ||
    minutes > 59 ||
    seconds > 59 {
    return dos_epoch
  }
  let year_days = for y = 1980, acc = 0; y < year; {
    continue y + 1, acc + (if is_leap_year(y) { 366 } else { 365 })
  } nobreak {
    acc
  }
  let days = year_days +
    month_day_to_day_of_year(month, day, is_leap_year(year)) -
    1
  dos_epoch + days * 86400 + hours * 3600 + minutes * 60 + seconds
}

///|
/// Day-of-year (1-based) to (month, day).
fn day_of_year_to_month_day(day_of_year : Int, is_leap : Bool) -> (Int, Int) {
  let months = days_in_months(is_leap)
  for i = 0, remaining_days = day_of_year; i < months.length(); {
    if remaining_days <= months[i] {
      break (i + 1, remaining_days)
    }
    continue i + 1, remaining_days - months[i]
  } nobreak {
    (12, 31) // fallback for an out-of-range day-of-year
  }
}

///|
/// (month, day) to day-of-year (1-based).
fn month_day_to_day_of_year(month : Int, day : Int, is_leap : Bool) -> Int {
  let months = days_in_months(is_leap)
  for i = 0, day_of_year = day; i < month - 1 && i < months.length(); {
    continue i + 1, day_of_year + months[i]
  } nobreak {
    day_of_year
  }
}
