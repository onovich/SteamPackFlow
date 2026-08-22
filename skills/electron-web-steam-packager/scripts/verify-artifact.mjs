#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

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
    'Verify that an Electron artifact is a Steam-ready unpacked payload.',
    '',
    'Usage:',
    '  node verify-artifact.mjs --platform <win|mac> --input <path> [options]',
    '',
    'Options:',
    '  --expected-executable <file>   Required Windows root executable',
    '  --project-dir <dir>            Project whose package version is checked',
    '  --release-version <version>    Expected package version',
    '  --json                         Print JSON only',
    '  --help                         Show this help',
    ''
  ].join('\n'));
}

function walk(root, visitor) {
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const fullPath = path.join(root, entry.name);
    const stats = fs.lstatSync(fullPath);
    visitor(fullPath, entry, stats);
    if (entry.isDirectory() && !stats.isSymbolicLink()) walk(fullPath, visitor);
  }
}

function findSevenZip() {
  const candidates = process.platform === 'win32'
    ? [
        process.env.ProgramFiles
          ? path.join(process.env.ProgramFiles, '7-Zip', '7z.exe')
          : null,
        '7z.exe'
      ]
    : ['7z'];
  for (const candidate of candidates.filter(Boolean)) {
    if (path.isAbsolute(candidate) && fs.existsSync(candidate)) return candidate;
    if (!path.isAbsolute(candidate)) {
      const probe = spawnSync(candidate, ['i'], { stdio: 'ignore', shell: false });
      if (!probe.error) return candidate;
    }
  }
  return null;
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  usage();
  process.exit(0);
}

const platform = String(args.platform || '').toLowerCase();
if (!['win', 'mac'].includes(platform)) fail('--platform must be win or mac');
if (!args.input) fail('--input is required');
const inputPath = path.resolve(String(args.input));
if (!fs.existsSync(inputPath)) fail('Input does not exist: ' + inputPath);

const errors = [];
const warnings = [];
const details = {};

if (args['release-version']) {
  if (!args['project-dir']) {
    errors.push('--project-dir is required with --release-version');
  } else {
    const packagePath = path.resolve(String(args['project-dir']), 'package.json');
    if (!fs.existsSync(packagePath)) {
      errors.push('package.json was not found for version verification');
    } else {
      try {
        const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
        details.packageVersion = packageJson.version;
        if (String(packageJson.version) !== String(args['release-version'])) {
          errors.push('package.json version ' + String(packageJson.version) +
            ' does not match release version ' + String(args['release-version']));
        }
      } catch (error) {
        errors.push('Cannot parse package.json: ' + error.message);
      }
    }
  }
}

if (platform === 'win') {
  if (!fs.statSync(inputPath).isDirectory()) {
    errors.push('Windows Steam input must be an unpacked directory, never a lone EXE or ZIP');
  } else {
    const rootEntries = fs.readdirSync(inputPath, { withFileTypes: true });
    const rootExecutables = rootEntries
      .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith('.exe'))
      .map((entry) => entry.name);
    const expected = String(args['expected-executable'] || '');
    if (!expected) {
      errors.push('--expected-executable is required for Windows verification');
    } else if (!rootExecutables.includes(expected)) {
      const caseOnly = rootExecutables.find((name) =>
        name.toLowerCase() === expected.toLowerCase());
      errors.push(caseOnly
        ? 'Executable case mismatch: expected ' + expected + ', found ' + caseOnly
        : 'Expected root executable is missing: ' + expected);
    }
    details.rootExecutables = rootExecutables;

    const asarPath = path.join(inputPath, 'resources', 'app.asar');
    const appDirectory = path.join(inputPath, 'resources', 'app');
    if (!fs.existsSync(asarPath) &&
        !(fs.existsSync(appDirectory) && fs.statSync(appDirectory).isDirectory())) {
      errors.push('Missing resources/app.asar or resources/app; this is not a complete unpacked Electron app');
    }

    const blockmaps = [];
    let fileCount = 0;
    walk(inputPath, (fullPath, entry) => {
      if (entry.isFile()) fileCount += 1;
      if (entry.name.toLowerCase().endsWith('.blockmap')) {
        blockmaps.push(path.relative(inputPath, fullPath));
      }
    });
    if (blockmaps.length > 0) {
      errors.push('Installer/update blockmap files are forbidden: ' + blockmaps.join(', '));
    }
    if (fileCount < 3) {
      errors.push('Payload contains too few files for an unpacked Electron runtime');
    }
    details.fileCount = fileCount;

    if (expected && rootExecutables.includes(expected)) {
      const sevenZip = findSevenZip();
      if (sevenZip) {
        const probe = spawnSync(sevenZip, ['l', '-slt', path.join(inputPath, expected)], {
          encoding: 'utf8',
          shell: false
        });
        const output = String(probe.stdout || '') + String(probe.stderr || '');
        if (/^\s*Type\s*=\s*Nsis\s*$/im.test(output)) {
          errors.push('The expected executable is an NSIS installer, not a Steam launch executable');
        }
        details.installerProbe = '7-Zip';
      } else {
        warnings.push('7-Zip is unavailable; NSIS type probing was skipped');
      }
    }
  }
} else {
  if (!fs.statSync(inputPath).isDirectory() ||
      !inputPath.toLowerCase().endsWith('.app')) {
    errors.push('macOS Steam input must be a complete .app directory, not DMG/PKG/ZIP');
  } else {
    const contents = path.join(inputPath, 'Contents');
    const infoPlist = path.join(contents, 'Info.plist');
    const macOsDir = path.join(contents, 'MacOS');
    const framework = path.join(contents, 'Frameworks', 'Electron Framework.framework');
    if (!fs.existsSync(infoPlist)) errors.push('Missing Contents/Info.plist');
    if (!fs.existsSync(macOsDir) || !fs.statSync(macOsDir).isDirectory()) {
      errors.push('Missing Contents/MacOS');
    }
    if (!fs.existsSync(framework)) {
      errors.push('Missing Contents/Frameworks/Electron Framework.framework');
    }

    let executables = [];
    if (fs.existsSync(macOsDir) && fs.statSync(macOsDir).isDirectory()) {
      executables = fs.readdirSync(macOsDir).filter((name) => {
        const candidate = path.join(macOsDir, name);
        return fs.statSync(candidate).isFile();
      });
      if (executables.length === 0) errors.push('Contents/MacOS has no executable file');
      if (process.platform === 'darwin') {
        for (const name of executables) {
          const mode = fs.statSync(path.join(macOsDir, name)).mode;
          if ((mode & 0o111) === 0) {
            errors.push('Contents/MacOS/' + name + ' is not executable');
          }
        }
      } else {
        warnings.push('Executable mode checks require a native macOS filesystem');
      }
    }

    let symlinkCount = 0;
    walk(inputPath, (_fullPath, _entry, stats) => {
      if (stats.isSymbolicLink()) symlinkCount += 1;
    });
    details.executables = executables;
    details.symlinkCount = symlinkCount;
  }
}

const result = {
  schemaVersion: 1,
  ok: errors.length === 0,
  platform,
  input: inputPath,
  errors,
  warnings,
  details,
  verifiedAt: new Date().toISOString()
};

if (args.json) {
  process.stdout.write(JSON.stringify(result, null, 2) + '\n');
} else {
  process.stdout.write((result.ok ? 'PASS' : 'FAIL') + ': ' + inputPath + '\n');
  for (const warning of warnings) process.stdout.write('WARN: ' + warning + '\n');
  for (const error of errors) process.stderr.write('ERROR: ' + error + '\n');
}
if (!result.ok) process.exit(1);

