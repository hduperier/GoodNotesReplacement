# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue or PR.

Use GitHub's private vulnerability reporting: the repository's **Security** tab →
**Report a vulnerability**. (If it isn't visible, enable it under
*Settings → Code security and analysis → Private vulnerability reporting*.)

Please include reproduction steps, affected version/commit, and impact. We aim
to acknowledge a report within **7 days** and to coordinate a fix and
disclosure timeline with you.

## Supported versions

This is a pre-1.0 project; only the latest commit on `main` is supported.

## Scope & threat model

GoodNotes Replacement is an **offline, local-only** iPad app:

- **No network calls and no third-party runtime dependencies.** All data
  (notebooks, pages, ink) is stored locally via SwiftData. There is no account,
  sync, or telemetry. This eliminates server-side, transport, and most
  third-party supply-chain vectors.
- **Document content is not adaptive chrome.** Ink and paper colors are fixed
  values, never derived from untrusted input beyond a validated hex parser.

In-scope concerns we care about:

- Local data-at-rest exposure beyond the app sandbox.
- Crashes or corruption from malformed persisted documents.
- **Build / CI supply chain** (the primary external surface):
  - GitHub Actions are pinned to full commit SHAs and updated via Dependabot.
  - The CI token is least-privilege (`contents: read`) and not persisted to
    `.git/config`.
  - See `.github/workflows/ci.yml` and `.github/dependabot.yml`.

Out of scope: issues requiring a jailbroken device or physical access with the
device unlocked; the security of Apple frameworks (PencilKit, SwiftData) themselves.
