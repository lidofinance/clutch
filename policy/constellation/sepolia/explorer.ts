// SPDX-License-Identifier: AGPL-3.0-or-later
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { AbiCoder, getAddress, keccak256, toUtf8Bytes } from "ethers";

const ROOT = "cache/sepolia/etherscan-verification";
const API = "https://api.etherscan.io/v2/api";
type Entry = { label: string; address: string; contract: string; compilerVersion: string; input: string; constructorArgsFile: string };
type Package = { chainId: number; contracts: Entry[]; inputs: Record<string, { file: string; sha256: string }> };
type Api = (action: string, fields: Record<string, string>, publish?: boolean) => Promise<any>;

const digest = (data: string | Buffer) => createHash("sha256").update(data).digest("hex");

/** Check frozen deployment inputs. Current source files and out/ are not read. */
export function checkPackage(root = ROOT): Package {
  const checksums = JSON.parse(readFileSync(`${root}/checksums.json`, "utf8"));
  for (const [file, hash] of Object.entries(checksums)) {
    if (digest(readFileSync(file)) !== hash) throw new Error(`Frozen file changed: ${file}`);
  }
  const manifest: Package = JSON.parse(readFileSync(`${root}/manifest.json`, "utf8"));
  if (manifest.chainId !== 11155111 || !manifest.contracts.length) throw new Error("Expected a Sepolia verification package");
  const compiled = JSON.parse(readFileSync(`${root}/compiled.json`, "utf8"));
  const required = [`${root}/manifest.json`, `${root}/compiled.json`, ...Object.values(manifest.inputs).map(i => i.file), ...manifest.contracts.map(e => e.input),
    ...manifest.contracts.map(e => e.constructorArgsFile)];
  if (required.some(file => !checksums[file])) throw new Error("Incomplete frozen-file checksums");
  const addresses = new Set<string>();
  for (const entry of manifest.contracts) {
    const address = getAddress(entry.address);
    if (addresses.has(address)) throw new Error("Duplicate contract address");
    addresses.add(address);
    const input = JSON.parse(readFileSync(entry.input, "utf8"));
    const artifact = compiled[entry.contract];
    if (!artifact || artifact.metadata.compiler.version !== entry.compilerVersion) throw new Error("Compiler version differs from deployment");
    if (Object.keys(input.sources).sort().join("\n") !== Object.keys(artifact.metadata.sources).sort().join("\n")) throw new Error("Compiler source set differs from deployment");
    for (const [source, spec] of Object.entries(artifact.metadata.sources) as [string, any][]) {
      if (keccak256(toUtf8Bytes(input.sources[source]?.content ?? "")) !== spec.keccak256) throw new Error(`Source hash differs: ${source}`);
    }
    for (const key of ["optimizer", "evmVersion", "viaIR", "libraries", "remappings"]) {
      if (JSON.stringify(input.settings[key]) !== JSON.stringify(artifact.metadata.settings[key])) throw new Error(`Compiler setting differs: ${key}`);
    }
    // Solidity metadata omits these options when they retain their defaults.
    const metadataOptions = (value: any) => ({ useLiteralContent: false, appendCBOR: true, bytecodeHash: "ipfs", ...value });
    if (JSON.stringify(metadataOptions(input.settings.metadata)) !== JSON.stringify(metadataOptions(artifact.metadata.settings.metadata))) {
      throw new Error("Compiler setting differs: metadata");
    }
    const args = readFileSync(entry.constructorArgsFile, "utf8").trim();
    const coder = AbiCoder.defaultAbiCoder();
    if (coder.encode(artifact.constructorTypes, coder.decode(artifact.constructorTypes, args)).toLowerCase() !== args.toLowerCase()) {
      throw new Error(`Constructor encoding differs: ${entry.label}`);
    }
  }
  return manifest;
}

// Response shapes: docs.etherscan.io/api-reference/endpoint/{getsourcecode,verifysourcecode,checkverifystatus}.
export function sourceStatus(body: any): boolean {
  if (body?.status !== "1" || !Array.isArray(body.result) || body.result.length !== 1
      || typeof body.result[0].SourceCode !== "string" || typeof body.result[0].ABI !== "string") {
    throw new Error("Explorer source response failed; raw response suppressed");
  }
  return body.result[0].SourceCode.length > 0 && body.result[0].ABI !== "Contract source code not verified";
}

export function exactSourceStatus(body: any): boolean {
  return sourceStatus(body) && body.result[0].SimilarMatch === "";
}

export async function inspectSources(manifest: Package, api: Api) {
  const result = [];
  for (const entry of manifest.contracts) {
    const body = await api("getsourcecode", { address: entry.address });
    result.push({ label: entry.label, address: entry.address, verified: sourceStatus(body),
      exactMatch: exactSourceStatus(body), similarMatch: body.result[0].SimilarMatch });
  }
  return result;
}

export function submission(entry: Entry) {
  return { contractaddress: entry.address, sourceCode: readFileSync(entry.input, "utf8"),
    contractname: entry.contract, compilerversion: `v${entry.compilerVersion}`, codeformat: "solidity-standard-json-input",
    constructorArguments: readFileSync(entry.constructorArgsFile, "utf8").trim().replace(/^0x/, "") };
}

/** Publish only with explicit opt-in; persist each GUID before the next request. */
export async function submitSources(manifest: Package, api: Api, root = ROOT, allowed = process.env.SEPOLIA_PUBLISH_SOURCES) {
  if (allowed !== "1") throw new Error("Source publication requires SEPOLIA_PUBLISH_SOURCES=1");
  const file = `${root}/submissions.json`;
  let saved: Record<string, { guid: string; verified: boolean }>;
  try { saved = JSON.parse(readFileSync(file, "utf8")); } catch (error: any) {
    if (error.code !== "ENOENT") throw error;
    saved = {};
  }
  for (const entry of manifest.contracts) {
    const key = entry.address.toLowerCase();
    if (exactSourceStatus(await api("getsourcecode", { address: entry.address }))) {
      if (saved[key] && !saved[key].verified) {
        saved[key].verified = true;
        writeFileSync(file, JSON.stringify(saved, null, 2) + "\n");
      }
      continue;
    }
    if (!saved[key]) {
      const body = await api("verifysourcecode", submission(entry), true);
      if (body?.status !== "1" || typeof body.result !== "string" || !/^[a-zA-Z0-9]+$/.test(body.result)) {
        throw new Error(`Source submission refused: ${entry.label}; raw response suppressed`);
      }
      saved[key] = { guid: body.result, verified: false };
      writeFileSync(file, JSON.stringify(saved, null, 2) + "\n");
    }
    const body = await api("checkverifystatus", { guid: saved[key].guid });
    saved[key].verified = body?.status === "1" && body.result === "Pass - Verified";
    writeFileSync(file, JSON.stringify(saved, null, 2) + "\n");
    console.log(`${entry.label}: ${saved[key].verified ? "verified" : "pending or failed; inspect status before retrying"}`);
  }
}

if (import.meta.main) {
  try {
    const action = process.argv[2];
    if (!["check", "status", "submit"].includes(action)) throw new Error("Use check, status or submit");
    const manifest = checkPackage();
    if (action === "check") console.log(`Frozen compiler inputs and constructor arguments checked for ${manifest.contracts.length} contracts.`);
    else {
      const key = process.env.ETHERSCAN_API_KEY;
      if (!key) throw new Error("Set ETHERSCAN_API_KEY in the local environment");
      const api: Api = async (action, fields, publish = false) => {
        const query = new URLSearchParams({ chainid: "11155111", module: "contract", action, apikey: key });
        if (!publish) for (const [key, value] of Object.entries(fields)) query.set(key, value);
        try {
          const response = await fetch(`${API}?${query}`, { method: publish ? "POST" : "GET",
            ...(publish ? { body: new URLSearchParams(fields) } : {}), signal: AbortSignal.timeout(20_000) });
          if (!response.ok) throw new Error();
          const body = await response.json();
          await Bun.sleep(400);
          return body;
        } catch { throw new Error("Explorer request failed; URL and raw response suppressed"); }
      };
      if (action === "submit") await submitSources(manifest, api);
      const status = await inspectSources(manifest, api);
      writeFileSync(`${ROOT}/status.json`, JSON.stringify({ observedAt: new Date().toISOString(), contracts: status }, null, 2) + "\n");
      console.log(`${status.filter(e => e.verified).length}/${status.length} contract sources recognized by Etherscan.`);
      console.log(`${status.filter(e => e.exactMatch).length}/${status.length} exact source matches.`);
      if (action === "submit" && status.some(e => !e.exactMatch)) process.exitCode = 1;
    }
  } catch (error: any) { console.error(error.message); process.exitCode = 1; }
}
