# Configuration reference

Everything lives in the Hermes profile `.env` (`~/.hermes/profiles/<profile>/.env`) unless noted. Env vars override `config.yaml`.

| Variable | Example | Effect |
|---|---|---|
| `BUZZ_RELAY_URL` | `http://<RELAY_HOST>:3000` | REST base of the relay. **Use `http://` not `ws://`** (see T4). |
| `BUZZ_PRIVATE_KEY` | `nsec1...` | Agent Nostr identity (secret). |
| `BUZZ_CLI_PATH` | `/home/<user>/.local/bin/buzz` | Absolute path to the real `buzz` binary (see T1/T2). |
| `BUZZ_TRANSPORT` | `poll` | Inbound transport: `auto`, `websocket`, or `poll`. Force `poll` (see T4). |
| `BUZZ_REQUIRE_MENTION` | `false` | `false` = respond to every message in watched channels (see T6). |
| `BUZZ_CHANNELS` | `<CHANNEL_UUID_A>,<CHANNEL_UUID_B>` | Restrict watched channels (comma list). Empty = all joined. |
| `BUZZ_ALLOWED_USERS` | `<OWNER_PUBKEY>` | Who may trigger (comma list). |
| `BUZZ_ALLOW_ALL_USERS` | `false` | Allow anyone to trigger. |
| `BUZZ_HOME_CHANNEL` | `<CHANNEL_UUID>` | Where cron/delivery land. Also settable via `/sethome`. |
| `BUZZ_POLL_INTERVAL` | `4` | Seconds between polls (min bounded). |

## Recommended profile `.env`

See `templates/env.example`.

## Runtime files

- `~/.hermes/profiles/<profile>/gateway_state.json` — live status (`connected`/`error`).
- `~/.hermes/profiles/<profile>/logs/gateway.log` — gateway + adapter logs.
- `~/.hermes/profiles/<profile>/sessions/sessions.json` — per-channel session store.
