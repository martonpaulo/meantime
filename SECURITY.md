# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately using GitHub's
[security advisories](https://github.com/martonpaulo/meantime/security/advisories/new)
for this repository. You will get a response as soon as possible.

Please do not open a public issue for security problems.

## Scope notes

Meantime is a local, accessory macOS app. It stores only non-sensitive
preferences in `UserDefaults`, keeps no accounts or tokens, and makes no network
requests other than Sparkle update checks against the appcast hosted in this
repository. The Sparkle EdDSA private update-signing key lives only in the
maintainer's Keychain and is never part of the repository.
