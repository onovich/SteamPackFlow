#!/usr/bin/env node

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
    'Build and verify an unpacked Electron application for Steam.',
    '',
    'Usage:',
    '  node build.mjs --project-dir <dir> --platform <win|mac> [options]',
    '',
    'Options:',
    '  --arch <arch>                  Default: x64 on Windows, universal on macOS',
    '  --config <file>                Default: electron-builder.steam.json',
    '  --web-script <npm-script>      Default: build',
    '  --skip-web-build               Do not run the web npm script',
    '  --skip-install                 Do not run npm ci/install',
    '  --unsigned-mac                 Disable identity auto-discovery and notarization',
    '  --china-mirrors                Set Electron/electron-builder mirror environment',
    '  --allow-cross-build            Allow a non-native host (not recommended)',
    '  --result-file <json>           Write verified artifact metadata',
    '  --release-version <version>    Must match package.json version',
    '  --help                         Show this help',
    ''
  ].join('\n'));
}

function run(command, values, options = {}) {
  process.stdout.write('> ' + command + ' ' + values.join(' ') + '\n');
  const result = spawnSync(command, values, {
    cwd: options.cwd,
    env: options.env || process.env,
    stdio: 'inherit',
    shell: false
  });
  if (result.error) fail(result.error.message);
  if (result.status !== 0) {
    fail(command + ' exited with code ' + String(result.status));
  }
}

function findDirectories(root, predicate, maxDepth = 3) {
  const found = [];
  function visit(directory, depth) {
    if (!fs.existsSync(directory) || depth > maxDepth) return;
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const fullPath = path.join(directory, entry.name);
      if (predicate(fullPath, entry.name)) found.push(fullPath);
      visit(fullPath, depth + 1);
    }
  }
  visit(root, 0);
  return found;
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  usage();
  process.exit(0);
}

const projectDir = path.resolve(String(args['project-dir'] || '.'));
if (!fs.existsSync(projectDir)) fail('Project directory does not exist: ' + projectDir);

const platform = String(args.platform || '').toLowerCase();
if (!['win', 'mac'].includes(platform)) fail('--platform must be win or mac');
const arch = String(args.arch || (platform === 'win' ? 'x64' : 'universal'));
const allowedArch = platform === 'win'
  ? ['x64', 'arm64', 'ia32']
  : ['x64', 'arm64', 'universal'];
if (!allowedArch.includes(arch)) {
  fail('Unsupported ' + platform + ' architecture: ' + arch);
}

const nativePlatform = platform === 'win' ? 'win32' : 'darwin';
if (process.platform !== nativePlatform && !args['allow-cross-build']) {
  fail('Build ' + platform + ' on its native runner, or explicitly pass --allow-cross-build');
}

const packagePath = path.join(projectDir, 'package.json');
if (!fs.existsSync(packagePath)) fail('package.json was not found');
let packageJson;
try {
  packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
} catch (error) {
  fail('Cannot parse package.json: ' + error.message);
}

const releaseVersion = String(args['release-version'] || packageJson.version || '');
if (!releaseVersion) fail('package.json has no version and --release-version was not supplied');
if (args['release-version'] && String(packageJson.version) !== releaseVersion) {
  fail('package.json version ' + String(packageJson.version) +
    ' does not match release version ' + releaseVersion);
}

const configRelative = String(args.config || 'electron-builder.steam.json');
const configPath = path.resolve(projectDir, configRelative);
if (!fs.existsSync(configPath)) fail('Builder config was not found: ' + configPath);
let builderConfig;
try {
  builderConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (error) {
  fail('Builder config must be JSON: ' + error.message);
}
const executableName = String(builderConfig.executableName || builderConfig.productName || '').trim();
if (!executableName) fail('Builder config needs executableName or productName');
const outputDir = path.resolve(projectDir, builderConfig.directories?.output || 'dist-electron');

const environment = { ...process.env };
if (args['unsigned-mac']) {
  if (platform !== 'mac') fail('--unsigned-mac is only valid with --platform mac');
  environment.CSC_IDENTITY_AUTO_DISCOVERY = 'false';
}
if (args['china-mirrors']) {
  environment.ELECTRON_MIRROR ||= 'https://npmmirror.com/mirrors/electron/';
  environment.ELECTRON_BUILDER_BINARIES_MIRROR ||=
    'https://npmmirror.com/mirrors/electron-builder-binaries/';
}

const npmCommand = process.platform === 'win32' ? process.execPath : 'npm';
const npmPrefix = process.platform === 'win32'
  ? [path.join(path.dirname(process.execPath), 'node_modules', 'npm', 'bin', 'npm-cli.js')]
  : [];
if (process.platform === 'win32' && !fs.existsSync(npmPrefix[0])) {
  fail('npm CLI was not found beside Node.js: ' + npmPrefix[0]);
}
if (!args['skip-install']) {
  const hasLock = fs.existsSync(path.join(projectDir, 'package-lock.json'));
  run(npmCommand, [...npmPrefix, hasLock ? 'ci' : 'install'], {
    cwd: projectDir,
    env: environment
  });
}

if (!args['skip-web-build']) {
  const webScript = String(args['web-script'] || 'build');
  if (!packageJson.scripts || !packageJson.scripts[webScript]) {
    fail('npm script was not found: ' + webScript + ' (use --skip-web-build if intentional)');
  }
  run(npmCommand, [...npmPrefix, 'run', webScript], {
    cwd: projectDir,
    env: environment
  });
}

const builderCli = path.join(projectDir, 'node_modules', 'electron-builder', 'cli.js');
if (!fs.existsSync(builderCli)) {
  fail('electron-builder CLI is not installed at ' + builderCli);
}

const builderArgs = [
  '--config', configRelative,
  platform === 'win' ? '--win' : '--mac',
  '--' + arch,
  '--dir'
];
if (args['unsigned-mac']) {
  builderArgs.push('-c.mac.identity=null', '-c.mac.notarize=false');
}
run(process.execPath, [builderCli, ...builderArgs], {
  cwd: projectDir,
  env: environment
});

let artifactCandidates;
if (platform === 'win') {
  const preferred = arch === 'x64' ? 'win-unpacked' : 'win-' + arch + '-unpacked';
  const preferredPath = path.join(outputDir, preferred);
  artifactCandidates = fs.existsSync(preferredPath)
    ? [preferredPath]
    : findDirectories(outputDir, (_full, name) => /^win(?:-.+)?-unpacked$/i.test(name), 1);
} else {
  const preferredParent = arch === 'x64' ? 'mac' : 'mac-' + arch;
  const preferredPath = path.join(outputDir, preferredParent);
  artifactCandidates = findDirectories(
    fs.existsSync(preferredPath) ? preferredPath : outputDir,
    (_full, name) => name.toLowerCase().endsWith('.app'),
    2
  );
}

if (artifactCandidates.length !== 1) {
  fail('Expected exactly one unpacked ' + platform + ' artifact under ' + outputDir +
    ', found ' + String(artifactCandidates.length) + ': ' + artifactCandidates.join(', '));
}

const artifactPath = path.resolve(artifactCandidates[0]);
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const verifyArgs = [
  path.join(scriptDir, 'verify-artifact.mjs'),
  '--platform', platform,
  '--input', artifactPath,
  '--project-dir', projectDir,
  '--release-version', releaseVersion
];
if (platform === 'win') {
  verifyArgs.push('--expected-executable', executableName + '.exe');
}
run(process.execPath, verifyArgs, { cwd: projectDir });

const result = {
  schemaVersion: 1,
  platform,
  arch,
  version: releaseVersion,
  artifactPath,
  expectedWindowsExecutable: platform === 'win' ? executableName + '.exe' : null,
  host: os.platform(),
  verifiedAt: new Date().toISOString()
};

if (args['result-file']) {
  const resultPath = path.resolve(projectDir, String(args['result-file']));
  fs.mkdirSync(path.dirname(resultPath), { recursive: true });
  fs.writeFileSync(resultPath, JSON.stringify(result, null, 2) + '\n', 'utf8');
  process.stdout.write('Result: ' + resultPath + '\n');
}
process.stdout.write(JSON.stringify(result, null, 2) + '\n');
