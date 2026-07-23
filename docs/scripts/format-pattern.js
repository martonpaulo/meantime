(function exposeFormatPattern(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.MeantimeFormatPattern = api;
}(typeof globalThis === "object" ? globalThis : this, function makeFormatPattern() {
  "use strict";

  function unquotedFields(pattern) {
    const fields = new Set();
    let insideLiteral = false;
    for (let index = 0; index < pattern.length; index += 1) {
      if (pattern[index] !== "'") {
        if (!insideLiteral && /[A-Za-z]/.test(pattern[index])) fields.add(pattern[index]);
        continue;
      }
      if (pattern[index + 1] === "'") {
        index += 1;
      } else {
        insideLiteral = !insideLiteral;
      }
    }
    return { fields, balanced: !insideLiteral };
  }

  function validation(pattern) {
    const parsed = unquotedFields(pattern);
    const hasDayPeriod = parsed.fields.has("a");
    const hasLowerHour = parsed.fields.has("h");
    const hasUpperHour = parsed.fields.has("H");
    if (!pattern.trim()) return { valid: false, message: "Enter or build a pattern." };
    if (!parsed.balanced) {
      return { valid: false, message: "Close the quoted literal before copying." };
    }
    if (hasDayPeriod && (!hasLowerHour || hasUpperHour)) {
      return {
        valid: false,
        message: "AM/PM (a) requires lowercase h or hh and cannot be combined with uppercase H or HH.",
      };
    }
    return { valid: true, message: "" };
  }

  return { unquotedFields, validation };
}));
