const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const resolver = path.resolve(__dirname, '../../scripts/resolve-version.sh');

function fixture(t, version, tag) {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'tmail-version-'));
  t.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
  fs.writeFileSync(path.join(cwd, 'pubspec.yaml'), `version: ${version}\n`);
  execFileSync('git', ['init', '-q'], { cwd });
  execFileSync('git', ['add', 'pubspec.yaml'], { cwd });
  execFileSync('git', ['-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
    'commit', '-qm', 'fixture'], { cwd });
  if (tag) execFileSync('git', ['tag', tag], { cwd });
  return (env = {}, args = []) => execFileSync('bash', [resolver, ...args], {
    cwd, encoding: 'utf8', env: { ...process.env, GITHUB_REF: '',
      GITHUB_REF_TYPE: '', GITHUB_REF_NAME: '', ...env },
  }).trim();
}

test('a fork checkout without upstream tags retains its newer app version', t => {
  assert.equal(fixture(t, '0.39.3', 'v0.34.13')(), '0.39.3');
});
test('a newer published fork tag still overrides an older manifest', t => {
  assert.equal(fixture(t, '0.34.5', 'v0.34.13')(), '0.34.13');
});
test('explicit versions and release tags retain priority', t => {
  const resolve = fixture(t, '0.39.3+1', 'v0.34.13');
  assert.equal(resolve({ GITHUB_REF: 'refs/tags/v0.34.13' }), '0.34.13');
  assert.equal(resolve({ GITHUB_REF_TYPE: 'tag', GITHUB_REF_NAME: 'v0.34.12' }), '0.34.12');
  assert.equal(resolve({}, ['v0.40.0']), '0.40.0');
});
test('an untagged checkout resolves from the committed manifest', t => {
  assert.equal(fixture(t, '0.39.3+2')(), '0.39.3');
});
