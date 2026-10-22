#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description="Freeze exact deployment inputs without publishing sources.")
parser.add_argument("--out", type=Path, default=Path("cache/sepolia/etherscan-verification"))
parser.add_argument("--broadcast", type=Path, default=Path("broadcast/DeploySepolia.s.sol/11155111/run-latest.json"))
parser.add_argument("--manifest", type=Path, default=Path("cache/sepolia/manifest.json"))
args = parser.parse_args()
out = args.out
if out.exists():
    raise SystemExit("Verification package exists; preserve it and use a different output directory")
broadcast = json.loads(args.broadcast.read_text())
manifest = json.loads(args.manifest.read_text())
if broadcast["chain"] != 11155111 or manifest["chainId"] != 11155111:
    raise SystemExit("Sepolia inputs required")
out.mkdir(parents=True)
try:
    compiled = {}
    labels = {value.lower(): name for name, value in manifest.items() if isinstance(value, str) and value.startswith('0x') and len(value) == 42}
    env = os.environ.copy()
    env.pop('ETHERSCAN_API_KEY', None)
    contracts = []
    inputs = {}
    for tx in broadcast['transactions']:
        if tx['transactionType'] != 'CREATE':
            continue
        name = tx['contractName']
        source = 'SepoliaStand' if name.startswith('Sepolia') else name
        artifact = json.loads(Path(f'out/{source}.sol/{name}.json').read_text())
        fqn = f'src/mocks/{source}.sol:{name}'
        compiled[fqn] = {'metadata': artifact['metadata'], 'bytecode': artifact['bytecode']['object'],
                         'constructorTypes': [item['type'] for item in next((a for a in artifact['abi'] if a['type'] == 'constructor'), {'inputs': []})['inputs']]}
        code = artifact['bytecode']['object']
        initcode = tx['transaction']['input']
        if not initcode.lower().startswith(code.lower()):
            raise SystemExit(f'{name}: current build differs from recorded creation input; use the preserved deployment package')
        args = '0x' + initcode[len(code):]
        if name not in inputs:
            result = subprocess.run(['forge', 'verify-contract', '--chain', '11155111', '--show-standard-json-input', '--skip-is-verified-check', tx['contractAddress'], fqn], env=env, capture_output=True, text=True, timeout=60)
            if result.returncode:
                raise SystemExit(f'Local input generation failed for {name}; nothing submitted')
            compiler_input = json.loads(result.stdout)
            input_path = out / f'{name}.standard.json'
            input_path.write_text(json.dumps(compiler_input, indent=2) + '\n')
            inputs[name] = {'file': str(input_path), 'sha256': hashlib.sha256(input_path.read_bytes()).hexdigest(), 'sources': sorted(compiler_input['sources'])}
        address = tx['contractAddress']
        label = labels[address.lower()]
        args_path = out / f'{label}.constructor.hex'
        args_path.write_text(args + '\n')
        contracts.append({'label': label, 'address': address, 'contract': fqn, 'compilerVersion': artifact['metadata']['compiler']['version'], 'input': inputs[name]['file'], 'constructorArgsFile': str(args_path), 'creationTransactionHash': tx['hash']})
    for prefix in ['usd', 'eth']:
        args = subprocess.run(['cast', 'abi-encode', 'f(string,string,address)', 'First-loss test claim asset', 'tCLAIM', manifest[prefix+'Queue']], capture_output=True, text=True, env=env, check=True).stdout.strip()
        label = prefix+'ClaimAsset'
        args_path = out / f'{label}.constructor.hex'
        args_path.write_text(args + '\n')
        contracts.append({'label': label, 'address': manifest[label], 'contract': 'src/mocks/SepoliaStand.sol:SepoliaToken', 'compilerVersion': compiled['src/mocks/SepoliaStand.sol:SepoliaToken']['metadata']['compiler']['version'], 'input': inputs['SepoliaToken']['file'], 'constructorArgsFile': str(args_path), 'creationTransactionHash': next(tx['hash'] for tx in broadcast['transactions'] if tx.get('contractAddress','').lower() == manifest[prefix+'Queue'].lower())})
    package = {'chainId': 11155111, 'submitted': False, 'contracts': contracts, 'inputs': inputs}
    (out / 'manifest.json').write_text(json.dumps(package, indent=2) + '\n')
    (out / 'compiled.json').write_text(json.dumps(compiled, indent=2) + '\n')
    files = [out / 'manifest.json', out / 'compiled.json'] + [Path(item['file']) for item in inputs.values()] + [Path(item['constructorArgsFile']) for item in contracts]
    (out / 'checksums.json').write_text(json.dumps({str(file): hashlib.sha256(file.read_bytes()).hexdigest() for file in files}, indent=2) + '\n')
    print(json.dumps({'preparedContracts': len(contracts), 'compilerInputs': len(inputs), 'sourceFiles': sorted({source for item in inputs.values() for source in item['sources']}), 'manifest': str(out / 'manifest.json'), 'submitted': False}, indent=2))
except BaseException:
    shutil.rmtree(out)
    raise
