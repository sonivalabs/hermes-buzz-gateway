# End-to-end setup

> Substitute every `<PLACEHOLDER>`. No secrets/keys/IPs in any file.

## 0. Prerequisites

- **Buzz relay** running. REST base `http://<RELAY_HOST>:3000` (WebSocket `ws://<...>:3000`).
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

## 3. Publish a profile (kind:0) for the key

The adapter runs `buzz users get` and needs a non-empty profile **authored by the gateway key itself**:

```bash
buzz users set-profile \
  --name "<AGENT_DISPLAY_NAME>" \
  --private-key <HEX_PRIVATE_KEY> \
  --relay http://<RELAY_HOST>:3000

# verify
buzz users get --private-key <HEX_PRIVATE_KEY> --relay http://<RELAY_HOST>:3000
# -> [{"display_name":"...","pubkey":"<your-hex>"}]
```

> Use the **hex** private key here. If the profile event ends up under the wrong key, the adapter says "no profile" (T3).

## 4. Admit the key to RELAY membership

"member of this community?" is *relay admission*, separate from channel membership. In dev mode the relay signs with a **deterministic dev key** (`DEV_RELAY_PRIVKEY` constant in `crates/buzz-relay/src/main.rs`, used when `BUZZ_REQUIRE_AUTH_TOKEN=false`):

```bash
cd <buzz-checkout> && . ./bin/activate-hermit
BUZZ_RELAY_PRIVATE_KEY=<THE_DEV_RELAY_KEY> \
  cargo run -p buzz-admin -- add-member --pubkey <AGENT_HEX_PUBKEY>
```

## 5. Add the key to the target channels

The gateway only watches channels the key is a member of:

```bash
buzz channels add-member --channel <CHANNEL_UUID> --pubkey <AGENT_HEX_PUBKEY>
buzz channels members --channel <CHANNEL_UUID>   # verify
```

> Keep **one display name per key**. If two keys share a name, `@Name` resolution becomes ambiguous (T8).

## 6. Set the home channel (optional)

Post `/sethome` addressed to the agent in the channel you want as home:
```bash
buzz messages send --channel <CHANNEL_UUID> \
  --content "@<AGENT_NPUB> /sethome" \
  --mention <AGENT_HEX_PUBKEY>
```

## 7. Install the systemd unit

Copy `templates/hermes-gateway.service`, adjust profile name + paths, then:

```bash
sudo cp templates/hermes-gateway.service /etc/systemd/system/hermes-gateway.service
sudo systemctl daemon-reload
sudo systemctl enable --now hermes-gateway
```

## 8. Verify

```bash
sudo systemctl is-active hermes-gateway
python3 -m json.tool ~/.hermes/profiles/my-agent/gateway_state.json
#    "platforms": { "buzz": { "state": "connected", "error_message": null } }
tail -50 ~/.hermes/profiles/my-agent/logs/gateway.log | grep -iE "watching|connected"
#  "... connected to http://<host>:3000 as <name> watching 2 channel(s) via poll, poll interval 4.0s"
```

Then run the behavior matrix from README.
