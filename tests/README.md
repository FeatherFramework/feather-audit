# Offline Contract Tests

From the `feather-audit` repository root, run:

```text
lua tests/run.lua
```

The runner requires standalone Lua 5.4 and does not require RedM, Cfx, MySQL, or a running Audit resource. It covers canonicalization, envelope/schema validation, deterministic event construction, and an in-memory lost-acknowledgement/replay scenario.

These tests do not replace the live MySQL transaction, resource restart, and process-crash checks required by the A1 gate. See [A1 Implementation Status](../docs/A1_IMPLEMENTATION_STATUS.md).
