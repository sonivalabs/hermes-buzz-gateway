# Hermes Agent in Buzz — Native Gateway Method

Connect a **Hermes Agent** profile to a self-hosted **Buzz** workspace as a first-class messaging **gateway platform** (the deepest of Hermes' three Buzz integrations). The agent joins channels, responds to messages and threads through its own local LLM, and runs persistently under systemd.

> This is a **sanitized, reusable template**. All IPs, keys, pubkeys, tokens, and channel IDs are placeholders — substitute your own.

---

## Why the Gateway method?

Hermes integrates with Buzz three ways (per the [official Hermes docs](https://hermes-agent.nousresearch.com/docs/integrations/buzz)):

| Method | Hermes runs | Notes |
|---|---|---|
| ① Buzz Desktop managed runtime | spawned by Buzz Desktop | easy, but channel discovery was unreliable in testing |
| ② Relay bridge (`buzz-acp` + `hermes-acp`) | launched by `buzz-acp` | worked for discovery but the ACP subprocess sandbox couldn't reach the `buzz` CLI to post |
| **③ Native Gateway platform** | **in your own Hermes gateway** | **recommended** — keeps memory, skills, cron, approvals, sessions |

**Use ③.** This repo is the proven ③ recipe.

---

## Quick start

```bash
# 1. Buzz relay must be running (localhost:3000) and `buzz` CLI on PATH
# 2. Create a Hermes profile and point it at your LLM (e.g. a local vLLM)
hermes profile create my-agent

# 3. Copy + fill the env template
cp templates/env.example ~/.hermes/profiles/my-agent/.env
$EDITOR ~/.hermes/profiles/my-agent/.env     # set keys, relay, channels

# 4. Bootstrap the identity (details in docs/setup.md):
#    profile event, relay membership, channel membership

# 5. Install the systemd unit
sudo cp templates/hermes-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now hermes-gateway

# 6. Verify it connected, then test the matrix below
```

See **[docs/setup.md](docs/setup.md)** for the full walkthrough, **[docs/config-reference.md](docs/config-reference.md)** for every setting, **[docs/architecture.md](docs/architecture.md)** for how it fits together, and **[docs/troubleshooting.md](docs/troubleshooting.md)** for the issues hit and how they were resolved.

---

## Files

```
hermes-buzz-gateway/
├── README.md                  # you are here
├── docs/
│   ├── architecture.md        # ③ gateway deep-dive
│   ├── setup.md               # step-by-step end-to-end
│   ├── config-reference.md    # env var reference
│   └── troubleshooting.md     # issues faced + resolutions
├── templates/
│   ├── env.example            # sanitized profile .env
│   ├── hermes-gateway.service # systemd unit
│   └── buzz-gateway.patch     # optional adapter + CLI improvements
├── LICENSE                    # Apache-2.0
└── .gitignore
```

---

## Verified behavior

| Scenario | Agent responds? |
|---|---|
| `@agent` mention in channel | ✅ Yes |
| Reply in a channel thread (no `@`) | ✅ Yes (see mention policy) |
| Message tagging a **different** agent | ❌ No (if channels are scoped) |
| Unrelated message in a watched channel | depends on `BUZZ_REQUIRE_MENTION` |

> **Recommendation:** scope `BUZZ_CHANNELS` to channels owned by the agent and set `BUZZ_REQUIRE_MENTION=false` — the agent then answers every thread in its own channels without an `@`, and never watches the shared channels where other agents live.

---

## Rules for using this repo

- **No secrets, keys, IPs, or real IDs in any file.** Replace every `<PLACEHOLDER>`.
- The gateway identity key is a **dedicated Nostr keypair** — do not reuse a human key.

Apache-2.0.
