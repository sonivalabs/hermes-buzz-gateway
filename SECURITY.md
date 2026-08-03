# Security

## Reporting a vulnerability

If you find a security issue (in this template, Hermes, or Buzz), please **do not**
open a public issue. Report privately via **GitHub Private Vulnerability
Reporting** (Repo → Security tab → "Report a vulnerability") once this repo is
made public, or to the maintainer's published contact address. Include:

- Affected file / docs section
- A minimal reproduction
- Impact

For Hermes/Buzz themselves, follow their own responsible-disclosure policies before
reporting here.

## This repo: what it is and is not

This repository is **configuration, templates, and documentation only**. It:

- **does not** vendor or include secrets,
- **does not** contain private keys, credit PyPI/crates tokens, or live host addresses,
- is meant to be *copied* and customized — do not commit real values back into it.

## Hardening guidance for anyone using this template

The deployment this template describes should follow the baseline posture below:

1. **Dedicated identity** — each agent uses its own Nostr keypair; never reuse a human's
   key. The private key lives only in the profile `.env` (mode `600`), never in `sys.argv`
   or logs.
2. **Least privilege** — `BUZZ_ALLOWED_USERS` restricted to the owner, `BUZZ_CHANNELS`
   scoped to channels the agent should see, `BUZZ_ALLOW_ALL_USERS=false` unless intended.
3. **Isolate the gateway key** — the gateway's key must be admitted to the relay and be a
   channel member *and* have a profile event; do not grant it admin/owner roles.
4. **Transport** — this template forces `BUZZ_TRANSPORT=poll`; if you move to the WebSocket
   path later, still terminate TLS at the relay (wss) in any non-local deployment.
5. **Secrets hygiene** — keep the private key out of git (`.gitignore` has `.env`),
   rotate any key that is ever committed even once.
6. **Host hardening** — bind the relay to localhost when possible; treat the profile's
   sandboxed HOME as an untrusted scratch space.

## Secret scan

Keep the repo leak-free. Run `./scripts/scan.sh` before commits. If the GitHub
Actions `secrets-scan` workflow is present/enabled in this repo, it enforces the
same checks (gitleaks + placeholder guard) in CI; if not present, rely on the
local `scan.sh` and review diffs manually. (The workflow file must be added with
a token that has the GitHub `workflow` scope.)
