// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { readOnlyRpc } from "./prepare-constellation";

test("RPC transport refuses transactions before sending a request", async () => {
  await expect(readOnlyRpc("https://unused.invalid")("eth_sendRawTransaction", ["0x00"])).rejects.toThrow("refused");
});

test("RPC transport suppresses credential-bearing errors and checks response IDs", async () => {
  const original = globalThis.fetch;
  try {
    globalThis.fetch = (async () => { throw new Error("secret-endpoint-token"); }) as unknown as typeof fetch;
    await expect(readOnlyRpc("https://secret-endpoint-token.invalid")("eth_chainId", [])).rejects.toThrow("endpoint and response suppressed");
    globalThis.fetch = (async () => Response.json({ jsonrpc: "2.0", id: 999, result: "0xaa36a7" })) as unknown as typeof fetch;
    await expect(readOnlyRpc("https://unused.invalid")("eth_chainId", [])).rejects.toThrow("suppressed");
  } finally { globalThis.fetch = original; }
});
