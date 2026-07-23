"use strict";

const assert = require("node:assert/strict");
const { unquotedFields, validation } = require("../docs/scripts/format-pattern.js");

for (const pattern of ["h:mm a", "hh:mm a", "'H' h:mm a", "HH:mm 'a'"]) {
  assert.equal(validation(pattern).valid, true, `${pattern} should be valid`);
}
for (const pattern of ["HH:mm a", "H:mm a", "h:mm a HH"]) {
  assert.equal(validation(pattern).valid, false, `${pattern} should be invalid`);
}
assert.equal(unquotedFields("'H' 'a' HH:mm").fields.has("a"), false);
assert.equal(validation("'unfinished").valid, false);

console.log("format-builder: ok");
