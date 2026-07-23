"use strict";

const assert = require("node:assert/strict");
const { unquotedFields, validation } = require("../docs/scripts/format-pattern.js");
const { EXAMPLE_DATE, parsePattern } = require("../docs/scripts/format-preview.js");

for (const pattern of ["h:mm a", "hh:mm a", "'H' h:mm a", "HH:mm 'a'"]) {
  assert.equal(validation(pattern).valid, true, `${pattern} should be valid`);
}
for (const pattern of ["HH:mm a", "H:mm a", "h:mm a HH"]) {
  assert.equal(validation(pattern).valid, false, `${pattern} should be invalid`);
}
assert.equal(unquotedFields("'H' 'a' HH:mm").fields.has("a"), false);
assert.equal(validation("'unfinished").valid, false);

assert.equal(EXAMPLE_DATE.getFullYear(), 2026);
assert.equal(EXAMPLE_DATE.getMonth(), 7);
assert.equal(EXAMPLE_DATE.getDate(), 8);
assert.equal(EXAMPLE_DATE.getHours(), 5);
assert.equal(EXAMPLE_DATE.getMinutes(), 4);
assert.equal(EXAMPLE_DATE.getSeconds(), 9);
assert.equal(parsePattern("d dd M MM H HH h hh m mm s ss", EXAMPLE_DATE),
             "8 08 8 08 5 05 5 05 4 04 9 09");
assert.equal(parsePattern("'Meet at' h:mm a", EXAMPLE_DATE), "Meet at 5:04 AM");

console.log("format-builder: ok");
