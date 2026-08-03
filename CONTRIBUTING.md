# Contributing

Thanks for helping keep this template clean and reusable. The one hard rule:

> **Never commit real secrets, keys, IPs, or live IDs.**
>
> Every real value must be a `<UPPERCASE_PLACEHOLDER>` such as `<RELAY_HOST>`,
> `<OWNER_HEX_PUBKEY>`, `<CHANNEL_UUID>`. This repo ships with a GitHub
> Actions secret-scan and a placeholder-guard that fail CI on slips.

## How to contribute

1. Fork the repo.
2. Create a branch: `git checkout -b topic/your-change`.
3. Make your change — docs, templates, or a new gotcha in `docs/troubleshooting.md`.
4. Run the local scan before pushing:

   ```bash
   ./scripts/scan.sh   # if added, or:
   git grep -nE 'nsec1[A-Za-z0-9]{20,}|npub1[A-Za-z0-9]{20,}|[a-f0-9]{64}' -- . || true
   ```

   It should print nothing. If it prints matches, replace them with placeholders.
5. Commit with a `Signed-off-by` trailer:

   ```bash
   git commit -s -m "docs: add T12, WebSocket stale-subscription retry"
   ```

6. Open a pull request. If the CI `secrets-scan` workflow is present it must pass;
   if it hasn't been added yet (it needs a GitHub `workflow`-scoped token), run
   `./scripts/scan.sh` locally to confirm no leaks.

## What kind of change helps

- A **new troubleshooting entry** (T12+) with symptom → root cause → fix.
- A **new template** (e.g. a `docker-compose.service` variant, a Cloudflare/WireGuard tunnel step, a `prompts/` pack).
- Corrections to env-var semantics if Hermes/Buzz changed them.

## Review expectations

- Every file must stay **sanitized** and self-contained (no personal/private facts).
- Claims in `docs/` should be reproducible from the linked `block/buzz` / Hermes docs where possible.
