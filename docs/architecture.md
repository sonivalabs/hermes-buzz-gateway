# Architecture

## The ③ Native Gateway

```
Buzz relay (http://<RELAY_HOST>:3000)
   │
   ├── inbound:  REST poll  `buzz messages get --channel <id> --since <ts>`
   │             (optionally a NIP-42 WebSocket — see Troubleshooting T4)
   │
   ▼
Hermes gateway process  (systemd: hermes-gateway.service, profile=my-agent)
   │
   ▼
Buzz adapter  (plugins/platforms/buzz/adapter.py)
   ├─ connect():      `buzz users get` to confirm identity + acquire a scoped lock
   ├─ poll loop:      `buzz messages get` (REST) every few seconds
   ├─ _handle_event(): de-dupe → mention/thread gate → dispatch to Hermes
   └─ send():         `buzz messages send --channel <id> --content -`
```

## Context / session model

- **Per-channel session.** Hermes keys a session by `(platform, chat_type, chat_id, sender)` — the channel UUID is part of the session key, so **each Buzz channel has its own running context**. There is **no `thread_id`** in the key, so threads inside a channel share that channel's one session.
- The model's context window accumulates the whole channel conversation across turns; long histories are compressed when they exceed the window.
- Long-term memory, skills, and cron come from Hermes itself.

```
# example session key (sanitized)
agent:main:buzz:group:<CHANNEL_UUID>:<SENDER_PUBKEY>
```

## Identity requirements (why it won't connect if any is missing)

The gateway key must, all at once:
1. have a **kind:0 profile event** (adapter does `buzz users get`),
2. be a **relay/community member** (relay admission), and
3. be a **member of each channel** it should watch.

Missing any one produces a specific failure — see Troubleshooting.
