# Example: an HF-Downloader agent built from this playbook

This page walks through standing up a **dedicated, one-channel Hugging Face
model-downloader agent** using this playbook (authored after doing it for real).
It follows `setup.md`, `config-reference.md`, and the `templates/` — every real
value here is a `<PLACEHOLDER>`; substitute your own. **Nothing here is a real
key, ID, address, or path on any machine.**

## What we're building

- A Hermes profile `hf-downloader` whose only job is to `hf download`
  models into a local `<LLMS_ROOT>`.
- It watches **exactly one** Buzz channel (`LLM Downloads`) — no other channels.
- It uses the same LLM as your other agents (here a local OpenAI-compatible
  endpoint, e.g. `quanttrio-qwen36` at `<LOCAL_LLM>`).
- It authenticates to the Hub via `HF_TOKEN` (env / the standard HF cache token
  file), never via the command line.

## 1. Create + configure the profile

```bash
hermes profile create hf-downloader
```

Set the model. Point it wherever your other agents point; example `config.yaml`:

```yaml
model:
  default: <MODEL_ID>
  provider: custom:custom
providers:
  custom:
    base_url: <LOCAL_LLM>            # e.g. http://<HOST>:8081/v1
    api_key: <PLACEHOLDER_OR_EMPTY>
    default_model: <MODEL_ID>
_config_version: 33
```

Verify with `hermes -p hf-downloader status` / `hermes -p hf-downloader acp --check`.

## 2. Give it the HF-Downloader persona

Write `~/.hermes/profiles/hf-downloader/SOUL.md`. A tight, safe persona — this
set of rules is the important part. Adapt the storage root to yours:

```markdown
# HF-Downloader
You download Hugging Face models/adapters/datasets into local storage.
Repo: <LLMS_ROOT>/<VENDOR-or-SHORT-NAME>/<model-name-or-rev>/

- Confirm model ID, revision, target dir, and flags before large downloads.
- NEVER print or pass the token on the command line; rely on $HF_TOKEN / the
  HF cache token. `hf` reads it automatically.
- USE the modern `hf` CLI (`hf download <repo> --local-dir ...`).
  `huggingface-cli` is DEPRECATED and no longer works — never call it.
- If `hf` is missing, report it / install `huggingface_hub` (into the agent's
  venv) — do NOT install/use a web browser to "research" a model.
  Browsing is never a substitute for the download.
- Prefer resumable, non-interactive downloads; safetensors over .bin; keep
  GGUF quant filters explicit (--include).
- Check disk (`df -h <LLMS_ROOT>`) first; confirm if the model is large.
- PATH CONTAINMENT: resolve --local-dir and require it be under <LLMS_ROOT>;
  abort if it would escape. Never run downloaded code or scripts.
- Report: exact command, final path, size, how to load it. Ask when ambiguous.
```

## 3. Write the profile `.env`

Copy `templates/env.example` to `~/.hermes/profiles/hf-downloader/.env`, then:

```bash
chmod 600 ~/.hermes/profiles/hf-downloader/.env
# and unset the relax default from the example:
BUZZ_RELAY_URL=http://<RELAY_HOST>:3000
BUZZ_PRIVATE_KEY=<AGENT_NSEC>
BUZZ_ALLOWED_USERS=<OWNER_HEX_PUBKEY>
BUZZ_ALLOW_ALL_USERS=false
BUZZ_CLI_PATH=<ABSOLUTE_PATH_TO_REAL_BUZZ_BIN>
BUZZ_TRANSPORT=poll
BUZZ_REQUIRE_MENTION=false          # respond to all in its single channel
BUZZ_CHANNELS=<LLM_DOWNLOADS_CHANNEL_UUID>   # <-- scope to ONE channel
HF_DOWNLOAD_ROOT=<LLMS_ROOT>
HF_TOKEN=<YOUR_HF_TOKEN>            # or leave it; HF cache token is auto-read

# Then either copy the token into this file OR rely on the HF cache:
# HF_TOKEN="$(cat ~/.cache/huggingface/token)"   # run in shell, do not commit
```

## 4. Bring up the identity & scope (from setup.md §3–§5)

Use env-var keys, never argv:

```bash
# kind:0 profile event, authored by the agent key itself
export BUZZ_PRIVATE_KEY=<AGENT_NSEC>
buzz users set-profile --name "HF-Downloader" --relay http://<RELAY_HOST>:3000
unset BUZZ_PRIVATE_KEY

# relay admission (dev-only key — see setup.md §4 REACHABLE-RELAY warning!)
export BUZZ_RELAY_PRIVATE_KEY=<THE_DEV_RELAY_KEY>
cargo run -p buzz-admin -- add-member --pubkey <AGENT_HEX_PUBKEY>
unset BUZZ_RELAY_PRIVATE_KEY

# channel membership — ONLY the LLM Downloads channel
buzz channels add-member --channel <LLM_DOWNLOADS_CHANNEL_UUID> --pubkey <AGENT_HEX_PUBKEY>
buzz channels members --channel <LLM_DOWNLOADS_CHANNEL_UUID>   # verify
```

## 5. systemd unit

Copy `templates/hermes-gateway.service` (hardened) and substitute:
- `User`/`Group`: your user/group
- `HERMES_HOME`: `~/.hermes/profiles/hf-downloader`
- `WorkingDirectory`: your Buzz checkout
- `ExecStart`: `<HERMES_VENV>/bin/python -m hermes_cli.main -p hf-downloader gateway run`

```bash
sudo cp templates/hermes-gateway.service /etc/systemd/system/hf-downloader-gateway.service
sudo systemctl daemon-reload
sudo systemctl enable --now hf-downloader-gateway
```

> Keep the hardened `[Service]` block. Note: `ProtectHome` must NOT be read-only
> here — the gateway writes its profile under `$HOME` and writes downloads (and
> needs write to the media mount, which you must allow explicitly if hardened).

## 6. Verify

```bash
python3 -m json.tool ~/.hermes/profiles/hf-downloader/gateway_state.json
#   "platforms": { "buzz": { "state": "connected" } }
grep -E "watching" ~/.hermes/profiles/hf-downloader/logs/gateway.log | tail -1
#   "... as HF-Downloader, watching 1 channel(s) via poll ..."
```

Then in Buzz, in the `LLM Downloads` channel, ask it to "list your download root"
— it should respond with its configured root and existing subfolders.

## 7. Try a real (small) download

Ask for a small repo first to prove auth + path containment end-to-end, e.g.:

```
Download <a-small-public-repo> into its own subfolder, safetensors only.
```

The agent should: check disk → resolve a `<LLMS_ROOT>/<vendor>/<repo>/` path →
download → report command, size, and load line — all without echoing its token.

## Notes / gotchas specific to this agent

- **Single-channel scope is the point.** Only ever set `BUZZ_CHANNELS` to the
  channel you want it to see.
- **HF auth:** `hf`/`huggingface_hub` read `HF_TOKEN` and the
  `~/.cache/huggingface/token` file automatically — you rarely need a token flag,
  and passing one on argv is how tokens leak (see the argv finding in
  `docs/troubleshooting.md`).
- **`huggingface-cli` is deprecated — it is a dead end.** It only prints
  "use `hf` instead" and exits. The persona must call `hf download`.
- **Ensure `hf` is actually on the agent's PATH.** The agent's sandboxed
  terminal may not see `~/.local/bin` and its python may lack `huggingface_hub`.
  Fix: install it into the Hermes venv the agent runs from:
  `HERMES_VENV/bin/pip install --upgrade huggingface_hub` (puts `hf` in
  `HERMES_VENV/bin/hf`). Without this, every download fails silently and the
  model may invent an off-task fallback (seen in practice: it installed a
  browser to browse a model card instead of downloading). Add a persona rule:
  *if the tool is missing, report/install — never install a browser to research
  a model.*
- **Safetensors vs .bin**, **GGUF quant filtering**, and **gated repos** are the
  three things users most often mis-request; the persona covers all three.
- **Disk:** warn/confirm on models bigger than free space. Add a cap if you want
  a hard upper bound.

## Files you changed by doing this

```
~/.hermes/profiles/hf-downloader/{
  config.yaml, SOUL.md, .env,
  sessions/sessions.json, logs/gateway.log, gateway_state.json
}
/etc/systemd/system/hf-downloader-gateway.service
```

The four things that make it a *safe* HF-downloader: one channel, env-only
token, path containment under `<LLMS_ROOT>`, and confirm-before-large.
