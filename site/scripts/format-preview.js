(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.MeantimeFormatPreview = api;
}(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  // Saturday, August 8 at 05:04:09 makes every one- and two-digit field
  // visibly different while also exercising weekday, month, and day period.
  const EXAMPLE_DATE = new Date(2026, 7, 8, 5, 4, 9);
  const pad = (value, width) => String(value).padStart(width, "0");
  const local = (date, options) => date.toLocaleString(undefined, options);
  const twelveHour = date => ((date.getHours() + 11) % 12) + 1;
  const offset = date => {
    const total = -date.getTimezoneOffset();
    if (total === 0) return "Z";
    const sign = total < 0 ? "-" : "+";
    return `${sign}${pad(Math.floor(Math.abs(total) / 60), 2)}:${pad(Math.abs(total) % 60, 2)}`;
  };
  const zoneName = (date, style) => {
    const parts = new Intl.DateTimeFormat(undefined, { timeZoneName: style }).formatToParts(date);
    return parts.find(part => part.type === "timeZoneName")?.value ?? "";
  };

  const fields = {
    yyyy: date => pad(date.getFullYear(), 4),
    yy: date => pad(date.getFullYear() % 100, 2),
    MMMM: date => local(date, { month: "long" }),
    MMM: date => local(date, { month: "short" }),
    MM: date => pad(date.getMonth() + 1, 2),
    M: date => String(date.getMonth() + 1),
    EEEE: date => local(date, { weekday: "long" }),
    EEE: date => local(date, { weekday: "short" }),
    dd: date => pad(date.getDate(), 2),
    d: date => String(date.getDate()),
    HH: date => pad(date.getHours(), 2),
    H: date => String(date.getHours()),
    hh: date => pad(twelveHour(date), 2),
    h: date => String(twelveHour(date)),
    mm: date => pad(date.getMinutes(), 2),
    m: date => String(date.getMinutes()),
    ss: date => pad(date.getSeconds(), 2),
    s: date => String(date.getSeconds()),
    a: date => date.getHours() < 12 ? "AM" : "PM",
    zzzz: date => zoneName(date, "long"),
    z: date => zoneName(date, "short"),
    XXX: date => offset(date),
    VV: () => Intl.DateTimeFormat().resolvedOptions().timeZone,
  };
  const fieldKeys = Object.keys(fields).sort((left, right) => right.length - left.length);

  function parsePattern(pattern, date = EXAMPLE_DATE) {
    let output = "";
    let index = 0;
    while (index < pattern.length) {
      const character = pattern[index];
      if (character === "'") {
        if (pattern[index + 1] === "'") {
          output += "'";
          index += 2;
          continue;
        }
        index += 1;
        while (index < pattern.length) {
          if (pattern[index] === "'" && pattern[index + 1] === "'") {
            output += "'";
            index += 2;
          } else if (pattern[index] === "'") {
            index += 1;
            break;
          } else {
            output += pattern[index];
            index += 1;
          }
        }
        continue;
      }

      const token = fieldKeys.find(field => pattern.startsWith(field, index));
      if (token) {
        output += fields[token](date);
        index += token.length;
      } else if (/[A-Za-z]/.test(character)) {
        let end = index + 1;
        while (end < pattern.length && pattern[end] === character) end += 1;
        output += "·";
        index = end;
      } else {
        output += character;
        index += 1;
      }
    }
    return output;
  }

  return { EXAMPLE_DATE, parsePattern };
}));
