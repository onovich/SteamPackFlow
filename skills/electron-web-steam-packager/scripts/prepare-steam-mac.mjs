#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

function fail(message) {
  process.stderr.write('ERROR: ' + message + '\n');
  process.exit(1);
}

function parseArgs(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 1) {
    const token = values[index];
    if (!token.startsWith('--')) fail('Unexpected argument: ' + token);
    const key = token.slice(2);
    const next = values[index + 1];
    if (!next || next.startsWith('--')) {
      result[key] = true;
    } else {
      result[key] = next;
      index += 1;
    }
  }
  return result;
}

function usage() {
  process.stdout.write([
    'Verify and archive a macOS Electron .app for Steam handoff.',
    '',
    'Usage:',
    '  node prepare-steam-mac.mjs --app <Game.app> --output-dir <dir>',
    '    --game-key <name> --version <x.y.z> --release <full|demo> [options]',
    '',
    'Options:',
    '  --archive-name <file.zip>      Override the standard archive name',
    '  --flatten-symlinks             Flatten an unsigned disposable copy',
    '  --force                        Replace an existing exact archive target',
    '  --help                         Show this help',
    ''
  ].join('\n'));
}

function run(command, values) {
  const result = spawnSync(command, values, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    shell: false
  });
  if (result.error) fail(result.error.message);
  if (result.status !== 0) {
    fail(command + ' failed: ' + String(result.stderr || result.stdout).trim());
  }
  return String(result.stdout || '');
}

function sha256(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('sha256');
    const stream = fs.createReadStream(filePath);
    stream.on('error', reject);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  usage();
  process.exit(0);
}
if (process.platform !== 'darwin') {
  fail('macOS .app archives must be prepared on a native macOS runner');
}

for (const required of ['app', 'output-dir', 'game-key', 'version', 'release']) {
  if (!args[required]) fail('--' + required + ' is required');
}
const gameKey = String(args['game-key']);
const version = String(args.version);
const release = String(args.release).toLowerCase();
if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(gameKey)) fail('Invalid --game-key');
if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(version)) {
  fail('--version must be a semantic version');
}
if (!['full', 'demo'].includes(release)) fail('--release must be full or demo');

const appPath = path.resolve(String(args.app));
if (!fs.existsSync(appPath) || !fs.statSync(appPath).isDirectory() ||
    !appPath.toLowerCase().endsWith('.app')) {
  fail('--app must point to a .app directory');
}

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
run(process.execPath, [
  path.join(scriptDir, 'verify-artifact.mjs'),
  '--platform', 'mac',
  '--input', appPath
]);

const outputDir = path.resolve(String(args['output-dir']));
fs.mkdirSync(outputDir, { recursive: true });
const suffix = release === 'demo' ? '_Demo' : '';
const archiveName = String(
  args['archive-name'] || 'Mac_' + gameKey + '_' + version + suffix + '.zip'
);
if (path.basename(archiveName) !== archiveName ||
    !archiveName.toLowerCase().endsWith('.zip')) {
  fail('--archive-name must be a plain .zip filename');
}
const destination = path.join(outputDir, archiveName);
if (fs.existsSync(destination)) {
  if (!args.force) fail('Archive exists; use --force to replace: ' + destination);
  fs.rmSync(destination);
}

const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'electron-steam-mac-'));
const temporaryZip = path.join(outputDir, '.' + crypto.randomUUID() + '.tmp.zip');
let sourceApp = appPath;
try {
  if (args['flatten-symlinks']) {
    const signaturePath = path.join(appPath, 'Contents', '_CodeSignature');
    if (fs.existsSync(signaturePath)) {
      fail('Refusing to flatten a signed .app because that invalidates its signature');
    }
    sourceApp = path.join(temporaryRoot, path.basename(appPath));
    run('cp', ['-RL', appPath, sourceApp]);
    run(process.execPath, [
      path.join(scriptDir, 'verify-artifact.mjs'),
      '--platform', 'mac',
      '--input', sourceApp
    ]);
  }

  run('ditto', [
    '-c', '-k', '--sequesterRsrc', '--keepParent',
    sourceApp,
    temporaryZip
  ]);
  const entries = run('unzip', ['-Z1', temporaryZip])
    .split(/\r?\n/)
    .filter(Boolean);
  const rootPrefix = path.basename(sourceApp) + '/';
  if (!entries.some((entry) => entry === rootPrefix || entry.startsWith(rootPrefix))) {
    fail('Archive root does not contain ' + path.basename(sourceApp));
  }
  if (!entries.some((entry) => entry.startsWith(
    rootPrefix + 'Contents/MacOS/'
  ))) {
    fail('Archive is missing the app executable directory');
  }
  fs.renameSync(temporaryZip, destination);
} finally {
  if (fs.existsSync(temporaryZip)) fs.rmSync(temporaryZip);
  fs.rmSync(temporaryRoot, { recursive: true, force: true });
}

const hash = await sha256(destination);
const hashPath = destination + '.sha256';
fs.writeFileSync(hashPath, hash + '  ' + archiveName + '\n', 'utf8');
process.stdout.write(JSON.stringify({
  schemaVersion: 1,
  platform: 'mac',
  release,
  version,
  archive: destination,
  sha256: hash,
  sha256File: hashPath,
  flattenedSymlinks: Boolean(args['flatten-symlinks'])
}, null, 2) + '\n');
