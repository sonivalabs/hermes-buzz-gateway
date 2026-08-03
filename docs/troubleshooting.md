# Issues faced & how they were resolved

Real problems hit while bringing this up from scratch, each with the root cause and the fix. Numbered `T#`; referenced from other docs.

---

## T1 — `buzz` CLI binary not found / broken symlink
- **Symptom:** gateway_state says `cli_missing` / "buzz CLI binary not found"; or the CLI prints `Permission denied`.
- **Root cause:** the `buzz` on PATH was a **0-byte/stale symlink** to a `desktop/src-tauri/target/debug/buzz` stub instead of the real `target/debug/buzz` (54 MB).
- **Fix:** point the symlink at the real binary and set `BUZZ_CLI_PATH` to its absolute path.

## T2 — CLI not resolved inside the gateway subprocess
- **Symptom:** the adapter spawns `buzz` but the subprocess env (a venv-like PATH) can't find it.
- **Fix:** explicit `BUZZ_CLI_PATH=<abs path>` (overrides `shutil.which`).

## T3 — "`users get` returned no profile — is the key a member of this community?"
- **Cause 1:** the gateway key had **no kind:0 profile event** (e.g. a `set-profile` that signed under a different key).
- **Cause 2:** the key was not in the **relay membership** list.
- **Fix:** publish a kind:0 authored by that exact key (Setup §3) **and** `buzz-admin add-member` (Setup §4). Both are required.

## T4 — WebSocket delivery doesn't arrive on this relay build
- **Symptom:** gateway connects "via websocket", "watching N channels", but inbound never triggers. Same underlying issue breaks the ②/① discovery in some builds.
- **Root cause:** the relay's NIP-01 WebSocket event delivery was unreliable; the **REST `buzz messages get` (CLI) path works**. 
- **Fix:** force `BUZZ_TRANSPORT=poll`. The adapter polls via CLI every few seconds — reliable. Also use `http://` not `ws://` for `BUZZ_RELAY_URL` (the CLI expects the HTTP base).

## T5 — Mention must be in the content, not just a p-tag
- **Symptom:** sending with `--mention <pubkey>` (a `p`-tag) only — no dispatch.
- **Root cause:** the adapter gates on `_is_mentioned(content)` which scans the **message text** for the agent's npub / hex / display name.
- **Fix:** include the identity in the text, e.g. `@<npub> ...`. A bare `@Name` is ambiguous if two keys share the name (T8).

## T6 — "Respond to everything" steps on teammates
- **Attempt A:** `BUZZ_REQUIRE_MENTION=false` replied to *all* messages, so it answered messages tagging other agents.
- **Attempt B:** a strict "@mention + reply-to-own-message" gate meant replying to your **own** message in a thread got no reply — confusing.
- **Final fix:** `BUZZ_REQUIRE_MENTION=false` **plus** `BUZZ_CHANNELS` scoped to channels that are agent-only, dropping shared channels. The agent answers every thread in its own channels and never watches where team agents live. Simplest, predictable.

## T7 — Sends fail with "mention '@-mention.' does not match a current channel member"
- **Symptom:** the model occasionally echoes its own system-prompt placeholder (`@-mention.`) into a reply; `buzz messages send` then refuses.
- **Root cause:** `buzz-cli` `resolve_names_to_pubkeys()` treated any unmatched `@token` as a fatal `Usage` error when no explicit `--mention` was passed.
- **Fix (patch to Buzz CLI):** treat an unmatched `@token` as **literal prose** instead of fatal; keep the real-member ambiguity check. `crates/buzz-cli/src/commands/messages.rs` → `resolve_names_to_pubkeys()` → the empty-match branch. Rebuild `cargo build -p buzz-cli`.

## T8 — Duplicate identities named the same
- **Symptom:** `@Name` resolution reported "ambiguous" and `users get` looked wrong.
- **Cause:** several keys (original, a GUI-managed one, a leftover test key) shared the same display name.
- **Fix:** keep ONE identity per display name; remove the extras from channels. Keep the working key, disable/remove the rest.

## T9 — "Recovered reply / Redirected current run" messages during testing
- These only appeared while repeatedly restarting the gateway mid-turn. They are delivery-recovery artifacts of a restart and do not recur in stable operation.

## T10 — Port collisions
- The relay health listener: pick a free port (`BUZZ_HEALTH_PORT` in the relay `.env`). 8080/8081/8082 are commonly taken.
- If Buzz's Docker Redis would collide with a system Redis on 6379, remap Buzz to host port **6380** (`6380:6379` in compose + `REDIS_URL=redis://localhost:6380`).

## T11 — Relay under systemd must load `.env`
- When running `buzz-relay` under systemd, the launch script must **source the project `.env`** (`set -a; source .env; set +a`) so `BUZZ_HEALTH_PORT`, DB, and Redis vars load.

---

## Optional: reply-in-own-thread dispatcher

If you keep the agent in **shared** channels (can't fully scope channels) and want it to continue its *own* threads but not reply to everything:
- Track the agent's own published message ids (`_own_message_ids` set).
- Dispatch an inbound event when its `e`-tag references one of those ids, or when `_is_mentioned(content)`, or a DM.

See `templates/buzz-gateway.patch` for a reference patch (applies to `.../plugins/platforms/buzz/adapter.py`). Prefer the simpler `BUZZ_CHANNELS` scoping when you can.
