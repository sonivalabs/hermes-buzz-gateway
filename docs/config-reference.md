# Configuration reference

Everything lives in the Hermes profile `.env` (`~/.hermes/profiles/<profile>/.env`) unless noted. Env vars override `config.yaml`. The `.env` must be `chmod 600` (it contains your nsec).

## Variables

| Variable | Example | Effect |
|---|---|---|
| `BUZZ_RELAY_URL` | `http://<RELAY_HOST>:3000` | REST base of the relay. **Use `http://` for localhost** (T4); use `https://` behind TLS for anything reachable |
| `BUZZ_PRIVATE_KEY` | `nsec1...` | Agent Nostr identity (secret). **Never** pass on argv; keep in this env file, mode 600 |
| `BUZZ_CLI_PATH` | `/home/<user>/.local/bin/buzz` | Absolute path to the real `buzz` binary (T1/T2) |
| `BUZZ_TRANSPORT` | `poll` | Inbound transport: `auto`, `websocket`, or `poll`. Force `poll` (T4) |
| `BUZZ_REQUIRE_MENTION` | `false` | `false` = respond to every message in watched channels (prompt-injection surface — see below) |
| `BUZZ_CHANNELS` | `<CHANNEL_UUID_A>,<CHANNEL_UUID_B>` | Restrict watched channels (comma list). Empty = all joined |
| `BUZZ_ALLOWED_USERS` | `<OWNER_HEX_PUBKEY>` | **Who may trigger — gates dispatch**, see below |
| `BUZZ_ALLOW_ALL_USERS` | `false` | Allow anyone to trigger |
| `BUZZ_HOME_CHANNEL` | `<CHANNEL_UUID>` | Where cron/delivery land; also settable via `/sethome` |
| `BUZZ_POLL_INTERVAL` | `4` | Seconds between polls (min-bounded) |

## Security semantics you must understand

### `BUZZ_ALLOWED_USERS` gates DISPATCH, not just mentions

Enforcement (verified against the adapter in this Hermes release): only a sender
whose normalized pubkey is in `BUZZ_ALLOWED_USERS` reaches `_dispatch_message`.
Non-listed senders are dropped — with or without a mention — so a stranger cannot
trigger the agent even if `BUZZ_REQUIRE_MENTION=false`.

Two implementation details to know:
- **There are two allow-list layers.** The adapter checks `_allowed_pubkeys`;
  the *gateway* also applies `BUZZ_ALLOWED_USERS`/`BUZZ_ALLOW_ALL_USERS`
  centrally. Treat the pair as one gate, but know both exist.
- **Empty list = no adapter filter.** If `BUZZ_ALLOWED_USERS` is empty, the
  adapter's check is skipped and only the gateway-central check (and
  `BUZZ_ALLOW_ALL_USERS`) apply.
- **Version caveat — re-verify before relying on this.** The allow-list check
  currently sits *after* the mention gate but still *before* dispatch, so its
  effect (can't trigger) doesn't depend on that ordering. But check ordering
  and path are implementation details that can move on a Hermes upgrade.
  Grep `_allowed_pubkeys` / `BUZZ_ALLOWED_USERS` in
  `plugins/platforms/buzz/adapter.py` to reconfirm before you depend on it.

Always key it on **hex pubkeys**, never display names (names are spoofable). This
is the primary control for the prompt-injection surface described below.

### `BUZZ_REQUIRE_MENTION=false` is a wide-open surface

The agent runs on chat text. With `false`, **every** message in a watched channel
feeds the model. If the agent has skills, cron, approvals, or shell/file tools, that
is a broad prompt-injection surface. Consider:

- Keep watched channels minimal (`BUZZ_CHANNELS`).
- Keep `BUZZ_ALLOWED_USERS` tight (dispatch gate).
- Use `true` if you can tolerate typing `@` (the agent then only fires on mention).
  The "reply to everything in your own channels" convenience is a real trade-off.

### TLS

Nostr signatures prove **authorship**, not **confidentiality**. Every channel
message and agent reply is plaintext on the wire over `http`. For anything
reachable, run the relay behind TLS and use `https://`/`wss://`.

## Recommended profile `.env`

See `templates/env.example`.

## Runtime files

- `~/.hermes/profiles/<profile>/gateway_state.json` — live status (`connected`/`error`).
- `~/.hermes/profiles/<profile>/logs/gateway.log` — gateway + adapter logs.
- `~/.hermes/profiles/<profile>/sessions/sessions.json` — per-channel session store.
