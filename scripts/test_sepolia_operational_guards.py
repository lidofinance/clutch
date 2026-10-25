#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Exercise actual CLI guards with real temporary Git state and blocked transport."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
WORKSPACE = '11111111-1111-4111-8111-111111111111'


class OperationalGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='clutch-guards-')
        cls.base = Path(cls.tmp.name)
        cls.repo = cls.base / 'repo'
        cls.repo.mkdir()
        cls.env = {'PATH': os.environ['PATH'], 'GIT_CONFIG_GLOBAL': '/dev/null',
                   'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0'}
        target = cls.repo / 'policy/constellation'
        shutil.copytree(ROOT / 'policy/constellation/sepolia', target / 'sepolia')
        for name in ['node_modules', 'compiler', 'constellation']:
            (target / name).symlink_to(ROOT / 'policy/constellation' / name, target_is_directory=True)
        shutil.copy2(ROOT / 'sepolia.just', cls.repo / 'sepolia.just')
        (cls.repo / '.gitignore').write_text('cache/\ntrace.jsonl\npreload.ts\n')
        (cls.repo / 'README.md').write_text('Operational guard fixture.\n')
        cache = cls.repo / 'cache/sepolia/constellation'
        cache.mkdir(parents=True)
        # Guard refusal precedes payload decoding. Only the manifest must be valid for the chain case.
        names = ['assetSafe', 'ordersSafe', 'firstLossSafe', 'operatorSafe', 'emergencySafe',
                 'operatorModifier', 'safetyModifier', 'ordersModifier', 'firstLossModifier',
                 'easyTrackExecutor', 'agent', 'usdQueue', 'ethQueue', 'usdShare', 'ethShare', 'voting', 'controller']
        manifest = {'network': 'sepolia', 'chainId': 11155111, 'roleKeyScheme': 'account',
                    'dependencies': json.loads((target / 'sepolia/network.json').read_text())}
        manifest.update({name: '0x' + format(256 + i, '040x') for i, name in enumerate(names)})
        manifest['modules'] = [manifest['operatorModifier'], manifest['safetyModifier']]
        (cache.parent / 'manifest.json').write_text(json.dumps(manifest))
        (cache / 'payload.json').write_text('{}')
        (cache / 'context.json').write_text(json.dumps({'workspace': WORKSPACE, 'manifest': manifest}))
        cls.sender = manifest['controller']
        cls.preload = cls.repo / 'preload.ts'
        cls.trace = cls.repo / 'trace.jsonl'
        cls.preload.write_text('''import {appendFileSync} from 'node:fs';
globalThis.fetch = async (url, options) => {
  const request = JSON.parse(options?.body ?? '{}');
  appendFileSync(process.env.GUARD_TRACE, JSON.stringify({url:String(url),method:request.method})+'\\n');
  if (String(url) !== 'https://rpc.invalid' || request.method !== 'eth_chainId') throw new Error('Transport blocked by guard test');
  return new Response(JSON.stringify({jsonrpc:'2.0',id:request.id,result:'0x1'}),{status:200});
};
''')
        cls.git('init', '-b', 'testnet/sepolia')
        cls.git('config', 'user.name', 'Fixture')
        cls.git('config', 'user.email', 'fixture@example.invalid')
        cls.git('add', '.')
        cls.git('-c', 'commit.gpgsign=false', 'commit', '-m', 'Guard fixture')
        cls.head = cls.git('rev-parse', 'HEAD').stdout.strip()
        cls.git('init', '--bare', str(cls.base / 'origin.git'))
        cls.git('remote', 'add', 'origin', str(cls.base / 'origin.git'))
        cls.git('push', '-u', 'origin', 'testnet/sepolia')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    @classmethod
    def git(cls, *args):
        return subprocess.run(['git', *args], cwd=cls.repo, env=cls.env,
                              capture_output=True, text=True, check=True, timeout=20)

    def invoke(self, command, env, label, reason=None, expected_requests=0):
        self.trace.unlink(missing_ok=True)
        result = subprocess.run(command, cwd=self.repo,
                                env={**self.env, **env, 'GUARD_TRACE': str(self.trace)},
                                capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        requests = [json.loads(x) for x in self.trace.read_text().splitlines()] if self.trace.exists() else []
        self.assertEqual(len(requests), expected_requests, output)
        self.assertTrue(all(r == {'url': 'https://rpc.invalid', 'method': 'eth_chainId'} for r in requests))
        self.assertNotIn('test-key-not-a-secret', output)
        self.assertNotIn('private-test-value', output)
        self.assertNotIn('executor-test-value', output)
        self.assertFalse((self.repo / 'cache/sepolia/constellation/hosted').exists())
        if reason:
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn(reason, output)
        else:
            self.assertEqual(result.returncode, 0, output)
        print(json.dumps({'case': label, 'exit': result.returncode, 'requests': requests}))

    def publisher(self, label, change=None, reason=None, requests=0):
        env = {'CLUTCH_SEPOLIA_PUSH': '1', 'SEPOLIA_ZODIAC_API_KEY': 'test-key-not-a-secret',
               'SEPOLIA_ZODIAC_WORKSPACE': WORKSPACE, 'SEPOLIA_RPC': 'https://rpc.invalid'}
        for key, value in (change or {}).items():
            if value is None: env.pop(key, None)
            else: env[key] = value
        self.invoke(['bun', '--no-env-file', '--preload', str(self.preload),
                     'policy/constellation/sepolia/publish-constellation.ts', 'resolve'],
                    env, label, reason, requests)

    def test_real_git_branch_dirty_and_unpushed_refusals(self):
        self.git('checkout', '-b', 'main')
        self.publisher('wrong branch', reason='check out testnet/sepolia')
        self.git('checkout', 'testnet/sepolia')
        self.git('checkout', '--detach')
        self.publisher('detached HEAD', reason='not HEAD')
        self.git('checkout', 'testnet/sepolia')
        (self.repo / 'README.md').write_text('Changed.\n')
        self.publisher('tracked dirty file', reason='local changes')
        self.git('checkout', '--', 'README.md')
        (self.repo / 'untracked').write_text('Changed.\n')
        self.publisher('untracked dirty file', reason='local changes')
        (self.repo / 'untracked').unlink()
        self.git('-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-m', 'Unpushed fixture')
        self.publisher('unpushed commit', reason='push the commit')
        self.git('reset', '--hard', self.head)

    def test_publisher_environment_and_chain_refusals(self):
        cases = [({'CLUTCH_SEPOLIA_PUSH': None}, 'CLUTCH_SEPOLIA_PUSH=1'),
                 ({'CI': 'true'}, 'CI never'),
                 ({'SEPOLIA_ZODIAC_API_KEY': None}, 'SEPOLIA_ZODIAC_API_KEY'),
                 ({'SEPOLIA_ZODIAC_WORKSPACE': '22222222-2222-4222-8222-222222222222'}, 'prepared payload'),
                 ({'SEPOLIA_ZODIAC_API_URL': 'http://blocked.invalid'}, 'must use https')]
        for change, reason in cases:
            with self.subTest(change=change): self.publisher(reason, change, reason)
        manifest = self.repo / 'cache/sepolia/manifest.json'
        original = manifest.read_text()
        changed = json.loads(original); changed['controller'] = '0x' + '99' * 20
        manifest.write_text(json.dumps(changed))
        self.publisher('wrong prepared manifest', reason='prepared context uses another manifest')
        manifest.write_text(original)
        self.publisher('wrong chain after clean/pushed Git', reason='Sepolia RPC, manifest and artifact required', requests=1)

    def test_public_write_recipe_guard(self):
        command = ['just', '--no-dotenv', '--justfile', 'sepolia.just', '_guard']
        valid = {'CLUTCH_SEPOLIA': '1', 'SEPOLIA_ACCOUNT': 'fixture-account',
                 'SEPOLIA_SENDER': self.sender, 'SEPOLIA_RPC': 'https://rpc.invalid'}
        self.invoke(command, valid, 'public recipe guard positive control')
        cases = [(name, None) for name in valid] + [('CLUTCH_SEPOLIA', '2'), ('CI', 'true'), ('PRIVATE_KEY', 'private-test-value'), ('EXECUTOR_KEY', 'executor-test-value')]
        for key, value in cases:
            with self.subTest(key=key):
                env = dict(valid)
                if value is None: env.pop(key)
                else: env[key] = value
                state = 'missing' if value is None else 'set' if key in ['PRIVATE_KEY', 'EXECUTOR_KEY'] else value
                self.invoke(command, env, 'public recipe ' + key + '=' + state, 'failed')


if __name__ == '__main__':
    unittest.main()
