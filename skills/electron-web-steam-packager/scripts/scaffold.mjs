#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

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
    'Scaffold a project-specific Electron entry and Steam-only electron-builder config.',
    '',
    'Usage:',
    '  node scaffold.mjs --project-dir <dir> --web-root <dir> --app-name <name>',
    '    --app-id <reverse.dns.id> --executable-name <name> [options]',
    '',
    'Options:',
    '  --entry <file>                 Web entry relative to web root (default: index.html)',
    '  --config <file>                Config path (default: electron-builder.steam.json)',
    '  --electron-version <version>   Default: 43.4.1 when Electron is not already declared',
    '  --builder-version <version>    Default: 26.15.3 when electron-builder is not declared',
    '  --force-main                   Replace electron/main.cjs',
    '  --force-config                 Replace the Steam builder config',
    '  --help                         Show this help',
    ''
  ].join('\n'));
}

function toPosix(value) {
  return value.split(path.sep).join('/');
}

function npmName(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'electron-steam-app';
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  usage();
  process.exit(0);
}

const projectDir = path.resolve(String(args['project-dir'] || '.'));
if (!fs.existsSync(projectDir) || !fs.statSync(projectDir).isDirectory()) {
  fail('Project directory does not exist: ' + projectDir);
}

if (!args['web-root']) fail('--web-root is required');
const webRoot = path.resolve(projectDir, String(args['web-root']));
const webRelative = path.relative(projectDir, webRoot);
if (!webRelative || webRelative.startsWith('..' + path.sep) || path.isAbsolute(webRelative)) {
  fail('--web-root must be a dedicated directory inside the project, not the project root');
}

const entry = String(args.entry || 'index.html').replaceAll('\\', '/');
if (entry.startsWith('/') || entry.split('/').includes('..')) {
  fail('--entry must stay inside --web-root');
}

const packagePath = path.join(projectDir, 'package.json');
let packageJson = {};
if (fs.existsSync(packagePath)) {
  try {
    packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
  } catch (error) {
    fail('Cannot parse package.json: ' + error.message);
  }
}

const appName = String(args['app-name'] || packageJson.productName || packageJson.name || '').trim();
const appId = String(args['app-id'] || '').trim();
let executableName = String(args['executable-name'] || appName).trim();
executableName = executableName.replace(/\.exe$/i, '');

if (!appName) fail('--app-name is required when package.json has no usable name');
if (/[\\/:*?"<>|]/.test(appName) || appName === '.' || appName === '..') {
  fail('--app-name contains unsupported filesystem characters');
}
if (!/^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9_-]+)+$/.test(appId)) {
  fail('--app-id must be a reverse-DNS identifier such as com.example.game');
}
if (!executableName || /[\\/:*?"<>|]/.test(executableName)) {
  fail('--executable-name must be a filename base without path separators');
}

const electronDir = path.join(projectDir, 'electron');
const defaultMainPath = path.join(electronDir, 'main.cjs');
const existingMain = typeof packageJson.main === 'string'
  ? path.resolve(projectDir, packageJson.main)
  : null;
const shouldWriteMain = !existingMain || args['force-main'];
const mainPath = shouldWriteMain ? defaultMainPath : existingMain;
const mainRelative = toPosix(path.relative(projectDir, mainPath));

if (shouldWriteMain) {
  if (fs.existsSync(defaultMainPath) && !args['force-main']) {
    fail('electron/main.cjs already exists; inspect it or rerun with --force-main');
  }
  fs.mkdirSync(electronDir, { recursive: true });
  const mainSource = [
    "'use strict';",
    '',
    "const { app, BrowserWindow } = require('electron');",
    "const path = require('node:path');",
    '',
    'function createWindow() {',
    '  const window = new BrowserWindow({',
    '    width: 1280,',
    '    height: 720,',
    '    minWidth: 960,',
    '    minHeight: 540,',
    '    show: false,',
    "    backgroundColor: '#000000',",
    '    webPreferences: {',
    '      contextIsolation: true,',
    '      nodeIntegration: false,',
    '      sandbox: true',
    '    }',
    '  });',
    '',
    "  window.once('ready-to-show', () => window.show());",
    "  window.loadFile(path.join(app.getAppPath(), 'web', " + JSON.stringify(entry) + '));',
    '}',
    '',
    'app.whenReady().then(() => {',
    '  createWindow();',
    "  app.on('activate', () => {",
    '    if (BrowserWindow.getAllWindows().length === 0) createWindow();',
    '  });',
    '});',
    '',
    "app.on('window-all-closed', () => {",
    "  if (process.platform !== 'darwin') app.quit();",
    '});',
    ''
  ].join('\n');
  fs.writeFileSync(defaultMainPath, mainSource, 'utf8');
}

const configRelative = String(args.config || 'electron-builder.steam.json').replaceAll('\\', '/');
if (configRelative.startsWith('/') || configRelative.split('/').includes('..')) {
  fail('--config must stay inside the project');
}
const configPath = path.resolve(projectDir, configRelative);
if (fs.existsSync(configPath) && !args['force-config']) {
  fail(configRelative + ' already exists; inspect it or rerun with --force-config');
}

const files = [
  mainRelative,
  {
    from: toPosix(webRelative),
    to: 'web',
    filter: ['**/*']
  }
];
if (mainRelative.startsWith('electron/')) files[0] = 'electron/**/*';

const config = {
  $schema: 'https://raw.githubusercontent.com/electron-userland/electron-builder/master/packages/app-builder-lib/scheme.json',
  appId,
  productName: appName,
  executableName,
  asar: true,
  directories: {
    output: 'dist-electron'
  },
  files,
  mac: {
    category: 'public.app-category.games'
  }
};

fs.mkdirSync(path.dirname(configPath), { recursive: true });
fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n', 'utf8');

packageJson.name ||= npmName(appName);
packageJson.version ||= '0.1.0';
packageJson.private ??= true;
packageJson.main = mainRelative;
packageJson.scripts ||= {};
packageJson.scripts['desktop:steam:win'] =
  'electron-builder --config ' + configRelative + ' --win --x64 --dir';
packageJson.scripts['desktop:steam:mac'] =
  'electron-builder --config ' + configRelative + ' --mac --universal --dir';
packageJson.devDependencies ||= {};
packageJson.devDependencies.electron ||= String(args['electron-version'] || '43.4.1');
packageJson.devDependencies['electron-builder'] ||=
  String(args['builder-version'] || '26.15.3');
fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2) + '\n', 'utf8');

const ignorePath = path.join(projectDir, '.gitignore');
const ignoreEntries = ['node_modules/', 'dist-electron/', '.steam-build/', 'steam-artifacts/'];
const currentIgnore = fs.existsSync(ignorePath) ? fs.readFileSync(ignorePath, 'utf8') : '';
const missingEntries = ignoreEntries.filter((item) => {
  return !currentIgnore.split(/\r?\n/).some((line) => line.trim() === item);
});
if (missingEntries.length > 0) {
  const separator = currentIgnore.length > 0 && !currentIgnore.endsWith('\n') ? '\n' : '';
  fs.appendFileSync(ignorePath, separator + missingEntries.join('\n') + '\n', 'utf8');
}

process.stdout.write(JSON.stringify({
  projectDir,
  packagePath,
  mainPath,
  configPath,
  webRoot,
  entry,
  expectedWindowsExecutable: executableName + '.exe'
}, null, 2) + '\n');
