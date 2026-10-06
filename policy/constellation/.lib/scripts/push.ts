#!/usr/bin/env bun
import "../globals";
import path from "node:path";
import open from "open";
import { push } from "@zodiaceco/sdk";

const entrypoint = process.argv[2] ?? "constellation/index.ts";
const resolved = path.resolve(process.cwd(), entrypoint);
const mod = await import(resolved);

// Pass every named export (skip `default`) — keys become refs in the payload.
const { default: defaultExport, ...nodes } = mod;
if (defaultExport !== undefined) {
  console.warn(
    `warning: ${entrypoint} has a default export which will be ignored. ` +
      `Use named exports — each export becomes a ref in the pushed spec.`,
  );
}

const results = await push(nodes);

for (const { url } of results) {
  console.log(`Pushed constellation to: ${url}`);
  open(url);
}
