Jamixir fails when receiving the SetState message.

```
  Fuzzer             Jamixir
    |                  |
    |   PeerInfo.bin   |
    |----------------->|
    |                  |
    |  PeerInfo  OK    |
    |<-----------------|
    |                  |
    |   SetState.bin   |
    |----------------->|  FAILS
```

This is the `jamixir` log:

```log
❯ ./jamixir fuzzer --socket-path /tmp/jam_conformance.sock --log debug

15:59:02.198 [info] [NODE] 🔧 Starting fuzzer mode

15:59:02.200 [info] [NODE] Setting log level to debug

15:59:02.201 [info] [NODE] Setting log level to debug

15:59:02.201 [info] [NODE] 🟣 Pump up the JAM, pump it up...

15:59:02.208 [debug] [NODE] System loaded with config: [core_count: 2, forget_delay: 32, epoch_length: 12, max_tickets_pre_extrinsic: 16, tickets_per_validator: 3, slot_period: 6, rotation_period: 4, validator_count: 6, ticket_submission_end: 10, gas_accumulation: 1000000]

15:59:02.208 [info] [NODE] 🎭 Starting as fuzzer

15:59:02.322 [info] [NODE] Node running. Type 'q' + Enter for graceful shutdown

15:59:02.326 [info] Ready to be fuzzed on /tmp/jam_conformance.sock

15:59:10.360 [debug] New fuzzer connected

15:59:10.362 [info] Peer info: name=fuzzer, version=0.1.24, protocol=0.6.7

15:59:10.363 [info] Sending peer info: Jamixir, 0.2.0, 0.6.7

15:59:10.376 [error] Invalid state received for header hash 0x0000000000000000000000000000000000000000000000000000000000000000: missing or nil field: authorizer_pool

15:59:10.377 [info] Client disconnected
```
