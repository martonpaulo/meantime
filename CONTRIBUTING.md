# Contributing to Meantime

Thanks for your interest! Meantime aims to stay small, native, and fast.

## Getting started

Requires macOS 26+ and the Swift 6.2 toolchain.

```bash
make check   # build (warning-free) + tests + repository invariants
make run     # run the debug app
```

## Ground rules

- Read [AGENTS.md](AGENTS.md) first — it is the working agreement (architecture,
  design-token and energy contracts, and the pattern-break protocol).
- Keep business logic in the pure domain kit, with unit tests. Views render
  prepared state; they don't compute it.
- All visual constants come from the design tokens. No hardcoded sizes/colors.
- No new dependencies without a clear, justified need.
- English everywhere; [Conventional Commits](https://www.conventionalcommits.org).
- Add focused tests for changed behavior; don't mirror implementation details.

## Before opening a pull request

- `make check` passes with zero warnings.
- New user-facing behavior states its default and configurability decision.
- If you introduce a genuinely new pattern, document it in `AGENTS.md` in the
  same change and call it out in the PR.
