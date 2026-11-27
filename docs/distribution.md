# Meantime distribution and signing

Moved out of `AGENTS.md` with the route map ([#29](https://github.com/martonpaulo/meantime/issues/29)). `AGENTS.md` routes here before
an edit under `scripts/`, `.github/workflows/` or `appcast.xml`.


- Distribution is **direct download only**: a notarized, stapled DMG signed
  with the stable Developer ID Application identity, plus Sparkle auto-update
  driven by an appcast hosted from the repository.
- Sparkle is embedded only in the packaged app; the domain kit never imports
  it, and update checks only start from a real installed bundle.
- **Official releases come only from the tag workflow.** Pushing a `vX.Y.Z` tag
  that points at the current `origin/main` commit runs the Release workflow: it
  tests and validates, checks the tag against `CFBundleShortVersionString` and
  the derived `CFBundleVersion`, signs with the Developer ID certificate in a
  temporary keychain, notarizes and staples through `scripts/notarize.sh` with
  the team App Store Connect API key, signs the Sparkle update, publishes the
  DMG and the update zip with notes from `CHANGELOG.md`, then adds the appcast
  entry on `main`. The Notary credentials check workflow verifies the API key
  without building anything.
- The workflow requires six repository secrets: `DEVELOPER_ID_CERT_P12`,
  `DEVELOPER_ID_CERT_PASSWORD`, `NOTARY_API_KEY`, `NOTARY_API_KEY_ID`,
  `NOTARY_API_ISSUER_ID`, and `SPARKLE_PRIVATE_KEY`.
- **Local notarization is a rehearsal.** `scripts/notarize.sh` is the owner's
  canonical copy shared by every macOS app; keep it byte-for-byte unchanged and
  put project-specific steps in its callers. Locally it uses the `notarytool`
  Keychain profile `NOTARY_PROFILE`, default `skd-notary`. Never publish a
  locally built artifact as a release.
- **Signing material is never committed.** Only the Sparkle public key ships in
  the bundle; the private key lives in the Keychain locally and in the
  `SPARKLE_PRIVATE_KEY` secret for CI. Credentials never enter the repository
  or logs.
