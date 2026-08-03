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

On this adapter the allow-list is enforced in `_handle_event()` **before mention
resolution**: if the message sender's pubkey is not in the allow-list, the event is
**dropped entirely** — it cannot trigger the agent, with or without a mention. The
same check is also applied centrally by the gateway. So:

- `BUZZ_ALLOWED_USERS=<you>` + `BUZZ_ALLOW_ALL_USERS=false` = only you can ever
trigger the agent, regardless of `BUZZ_REQUIRE_MENTION`.
- This is the primary control for the prompt-injection surface described below.
- Always key it on **hex pubkeys**, never display names (names are spoofable).

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
