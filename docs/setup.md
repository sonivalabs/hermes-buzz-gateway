# End-to-end setup

> Substitute every `<PLACEHOLDER>`. No secrets/keys/IPs in any file.
>
> ⚠️ **This walkthrough targets a LOOPBACK / localhost development relay.**
> If your relay is reachable by anyone other than you, you MUST follow the
> **Reachable-relay warning** in Step 4 before adding any member. The identity
> steps below are the *only* gate protecting your channels.

## 0. Prerequisites

- **Buzz relay** running. REST base `http://<RELAY_HOST>:3000` (WebSocket `ws://<...>:3000`).
  - **TLS:** for anything beyond localhost, terminate TLS in front of the relay and use
    `https://` / `wss://`. Nostr signatures prove *authorship*, not confidentiality —
    message content crosses the wire in the clear on plain `http`.
- **`buzz` CLI** on PATH, from a block/buzz checkout:
  ```bash
  cd <buzz-checkout> && . ./bin/activate-hermit
  cargo build -p buzz-cli
  # ensure it is a real executable:
  readlink -f "$(which buzz)"   # -> .../target/debug/buzz
  ```
- **Hermes** with the profile you'll use, its model reachable (e.g. a local vLLM).
- A **dedicated Nostr keypair** for the agent identity.

## 1. Configure the Hermes profile

```bash
hermes profile create my-agent
# set the model/provider the profile should use (e.g. a custom endpoint)
hermes -p my-agent status        # Model / Provider should look right
hermes -p my-agent acp --check   # ACP deps OK
```

## 2. Write the profile `.env`

Copy `templates/env.example` to `~/.hermes/profiles/my-agent/.env` and fill it.

```bash
cp templates/env.example ~/.hermes/profiles/my-agent/.env
chmod 600 ~/.hermes/profiles/my-agent/.env   # <-- REQUIRED: the file holds your nsec
$EDITOR ~/.hermes/profiles/my-agent/.env
```

`chmod 600` matters: with the default `022` umask an unprotected `.env` would be
world-readable.

## 3. Publish a profile (kind:0) for the key

The adapter runs `buzz users get` and needs a non-empty profile **authored by the
gateway key itself**. **Pass the key via environment, never on the command line**
(`argv` is world-readable via `/proc/<pid>/cmdline` and `ps aux`, and leaks into
`~/.bash_history`):

```bash
export BUZZ_PRIVATE_KEY=<NSEC_OR_HEX_PRIVATE_KEY>   # do NOT paste into argv
buzz users set-profile --name "<AGENT_DISPLAY_NAME>" --relay http://<RELAY_HOST>:3000

# verify (same env, no key on the command line)
buzz users get --relay http://<RELAY_HOST>:3000
# -> [{"display_name":"...","pubkey":"<your-hex>"}]
unset BUZZ_PRIVATE_KEY
```

> If the profile event ends up under the wrong key, the adapter says "no profile" (T3).

## 4. Admit the key to RELAY membership

"member of this community?" is *relay admission*, separate from channel membership.
In dev mode the relay signs with a **deterministic dev key** (`DEV_RELAY_PRIVKEY`
constant in `crates/buzz-relay/src/main.rs`, used when `BUZZ_REQUIRE_AUTH_TOKEN=false`):

```bash
cd <buzz-checkout> && . ./bin/activate-hermit
export BUZZ_RELAY_PRIVATE_KEY=<THE_DEV_RELAY_KEY>   # env, not argv
cargo run -p buzz-admin -- add-member --pubkey <AGENT_HEX_PUBKEY>
unset BUZZ_RELAY_PRIVATE_KEY
```

> 🚨 **REACHABLE-RELAY WARNING — read before running anything above.**
> The dev relay key is a **public constant** in Buzz's open-source repo. On a relay
> running with `BUZZ_REQUIRE_AUTH_TOKEN=false`, **anyone who reaches the relay and
> knows that constant can admit arbitrary keys** to your community — i.e. let a
> stranger into your agent's channels. This is **loopback / localhost DO NOTHING
> dev use ONLY.** If anything other than yourself can connect to the relay:
>
> 1. Set `BUZZ_REQUIRE_AUTH_TOKEN=true` on the relay.
> 2. Set a **private, randomly generated** `BUZZ_RELAY_PRIVATE_KEY` (do not reuse
>    the dev constant), and
> 3. Restrict relay network exposure (bind localhost, firewall, or VPN).

## 5. Add the key to the target channels

The gateway only watches channels the key is a member of:

```bash
buzz channels add-member --channel <CHANNEL_UUID> --pubkey <AGENT_HEX_PUBKEY>
buzz channels members --channel <CHANNEL_UUID>   # verify
```

> **Authorize by hex pubkey, never by display name.** Display names are spoofable
> (T8 shows duplicate names are possible). The gateway keys everything on pubkeys.
> Keep **one display name per key** so `@Name` resolution isn't ambiguous (T8).

## 6. Set the home channel (optional)

Post `/sethome` addressed to the agent in the channel you want as home:
```bash
buzz messages send --channel <CHANNEL_UUID> \
  --content "@<AGENT_NPUB> /sethome" \
  --mention <AGENT_HEX_PUBKEY>
```

## 7. Install the systemd unit

Copy and harden `templates/hermes-gateway.service`, adjust profile name + paths, then:

```bash
sudo cp templates/hermes-gateway.service /etc/systemd/system/hermes-gateway.service
sudo systemctl daemon-reload
sudo systemctl enable --now hermes-gateway
```

The unit ships with a hardened `[Service]` block (see the template) — do not strip it.

## 8. Verify

```bash
sudo systemctl is-active hermes-gateway
python3 -m json.tool ~/.hermes/profiles/my-agent/gateway_state.json
#    "platforms": { "buzz": { "state": "connected", "error_message": null } }
tail -50 ~/.hermes/profiles/my-agent/logs/gateway.log | grep -iE "watching|connected"
#  "... connected to http://<host>:3000 as <name> watching 2 channel(s) via poll, poll interval 4.0s"
```

Then run the behavior matrix from README.

## Security of the agent's own surface

- The agent is an LLM acting on chat input. With `BUZZ_REQUIRE_MENTION=false` it
  responds to **every** message in watched channels — a broad prompt-injection
  surface into any Hermes skills/cron/approvals it holds. Mitigate with
  `BUZZ_ALLOWED_USERS` (which, on this adapter, gates **dispatch** — only
  allow-listed senders can trigger it) and keep watched channels minimal.
  Prefer allow-listing over `BUZZ_ALLOW_ALL_USERS=true`.
