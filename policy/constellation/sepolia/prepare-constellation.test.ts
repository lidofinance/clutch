// SPDX-License-Identifier: AGPL-3.0-or-later
import { expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { readOnlyRpc } from "./prepare-constellation";
import network from "./network.json";

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

test.each(["--diff", "11111111-1111-4111-8111-111111111111"])("failed preparation preserves saved evidence: %s", (command) => {
  const root = mkdtempSync(path.join(tmpdir(), "clutch-prepare-"));
  try {
    const entry = path.join(root, "policy/constellation/sepolia/prepare-constellation.ts");
    const output = path.join(root, "cache/sepolia/constellation");
    mkdirSync(path.dirname(entry), { recursive: true });
    mkdirSync(output, { recursive: true });
    // Run the unchanged CLI workflow in a disposable cache; imports use the installed sources.
    const source = readFileSync(path.join(import.meta.dir, "prepare-constellation.ts"), "utf8")
      .replace(/from "(\.\/[^\"]+)"/g, (_, module: string) => `from ${JSON.stringify(path.resolve(import.meta.dir, module))}`);
    writeFileSync(entry, source);
    const preload = path.join(root, "offline.ts");
    writeFileSync(preload, 'globalThis.fetch = async () => { throw new Error("Offline fixture"); };');
    const names = ["assetSafe", "ordersSafe", "firstLossSafe", "operatorSafe", "emergencySafe", "operatorModifier", "safetyModifier", "ordersModifier", "firstLossModifier", "easyTrackExecutor", "agent", "usdQueue", "ethQueue", "usdShare", "ethShare"];
    const manifest: Record<string, any> = { network: "sepolia", chainId: 11155111, dependencies: network,
      ...Object.fromEntries(names.map((name, i) => [name, "0x" + (i + 256).toString(16).padStart(40, "0")])),
    };
    manifest.modules = [manifest.operatorModifier, manifest.safetyModifier];
    const manifestFile = path.join(root, "manifest.json");
    writeFileSync(manifestFile, JSON.stringify(manifest));
    const previous = '{"saved":"previous successful snapshot"}\n';
    const files = ["diff.json", "payload.json", "context.json"];
    files.forEach((name) => writeFileSync(path.join(output, name), previous));
    const result = Bun.spawnSync([process.execPath, "--no-env-file", "--preload", preload, entry, command], {
      env: { SEPOLIA_RPC: "https://unused.invalid", SEPOLIA_MANIFEST: manifestFile },
      stdout: "pipe", stderr: "pipe",
    });
    expect(result.exitCode).toBe(1);
    expect(result.stderr.toString()).toContain("RPC");
    for (const name of files) {
      expect(existsSync(path.join(output, name))).toBe(true);
      expect(readFileSync(path.join(output, name), "utf8")).toBe(previous);
    }
  } finally { rmSync(root, { recursive: true, force: true }); }
});
