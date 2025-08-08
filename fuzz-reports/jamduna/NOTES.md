Fails while imporing the second block of the trace.

```log
❯ ./duna_target_linux
2025/08/08 18:52:37 Starting target on socket: /tmp/jam_target.sock
2025/08/08 18:52:37 Target listening on /tmp/jam_target.sock
2025/08/08 18:52:41 Fuzzer connected.
2025/08/08 18:52:41 [INCOMING REQUEST] PeerInfo
2025/08/08 18:52:41 Received handshake from fuzzer: fuzzer
2025/08/08 18:52:41 [OUTGOING RESPONSE] PeerInfo
2025/08/08 18:52:41 [INCOMING REQUEST] SetState
2025/08/08 18:52:41 Received SetState request with 21 key-value pairs.
2025/08/08 18:52:41 Setting state with header: 0xb5af8edad70d962097eefa2cef92c8284cf0a7578b70a6b7554cf53ae6d51222
2025/08/08 18:52:41 StateDB initialized with 21 key-value pairs. stateRoot: 0x76acb3326996df5eb7555790b7a60a9a8d519e4fae3e6a4ef906dcc3bedbc2b8 | HeaderHash:0xb5af8edad70d962097eefa2cef92c8284cf0a7578b70a6b7554cf53ae6d51222
2025/08/08 18:52:41 [OUTGOING RESPONSE] StateRoot
2025/08/08 18:52:58 [INCOMING REQUEST] ImportBlock
2025/08/08 18:52:58 Received ImportBlock request for block hash: 0x78aee0bd9653660598d0ffe32a20b2336a935c2a350ddf487a5f23d7c87467b6
2025/08/08 18:52:58 State transition applied. New stateRoot: 0xf48ceafee3bba5fe51bc0ccbeb903df3070db2f476421b83aa93f419fc99721e | HeaderHash: 0x579eeeacab5cebe95661edaa99367d52528a0b0c7340477bcaba6a6739a5b484
2025/08/08 18:52:58 [OUTGOING RESPONSE] StateRoot
2025/08/08 18:53:02 [INCOMING REQUEST] ImportBlock
2025/08/08 18:53:02 Received ImportBlock request for block hash: 0x05bd68bbc560ed2edef8b98381d3ca5f55741e7cf16430683e59847d1819f86d
2025/08/08 18:53:02 Error applying state transition from block: ParentStateRoot does not match
2025/08/08 18:53:02 [INCOMING REQUEST] GetState
2025/08/08 18:53:02 Received GetState request headerHash: 0x7789497a259c3e67a8733a97aba8eed12fefc13c23039f6273a3a4f42526ff9d
2025/08/08 18:53:02 Error: No state found for headerHash: 0x7789497a259c3e67a8733a97aba8eed12fefc13c23039f6273a3a4f42526ff9d
2025/08/08 18:53:02 Fuzzer disconnected.
```
