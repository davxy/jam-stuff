- I noticed that jamzilla sends back a `PeerInfo` message with GP version `0.6.6`, but the fuzzer expects `0.6.6`:

    ```
    2025-08-09 17:49:24 [T] [s=0] fuzz  RX (len=16): PeerInfo { name: "jam-node", version: Version { major: 0, minor: 1, patch: 0 }, protocol_version: Version { major: 0, minor: 6, patch: 6 } }
    ```

- Jamzilla stops working as soon as the `SetState` message is sent from the fuzzer (see `exception.log` file).

- For a valid `SetState` message please try to first parse `2_set_state.bin` here: https://github.com/davxy/jam-conformance/tree/main/fuzz-proto/examples
