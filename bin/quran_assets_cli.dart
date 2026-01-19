#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

/// CLI tool to automate fetching Quran assets (page images and fonts) from
/// remote repositories and registering them in the Flutter project's pubspec.yaml.
///
/// This tool supports dual fetching:
/// 1. Images from the pages repository.
/// 2. Fonts from the fonts repository.
/// It also handles registering all 605 fonts with their respective families.

/// Starts a process with the given executable [exe] and [args], pipes its
/// stdout/stderr to this process's stdout/stderr, displays a simple spinner
/// labeled with [spinnerLabel] while the external process runs, and returns
/// the external process exit code.
///
/// The function returns `-1` if starting the process throws an exception.
Future<int> _runProcessCaptureExit(String exe, List<String> args,
    {bool runInShell = true, String spinnerLabel = 'running'}) async {
  try {
    final process = await Process.start(exe, args, runInShell: runInShell);
    final spinner = _startSpinner(spinnerLabel);
    // Pipe external stdout/stderr to our stdout/stderr for user visibility.
    process.stdout.listen((b) => stdout.add(b));
    process.stderr.listen((b) => stderr.add(b));
    final code = await process.exitCode;
    spinner.cancel();
    stdout.writeln(''); // newline to move cursor after spinner
    return code;
  } catch (e) {
    // Return a non-zero sentinel to indicate failure to start.
    return -1;
  }
}

/// Start a terminal spinner animation labeled with [label]. Returns a [Timer]
/// that must be cancelled by the caller when the work completes.
///
/// The spinner writes to stdout and updates roughly every 120 ms. It does not
/// claim to be a full-featured progress indicator — its purpose is purely UX.
Timer _startSpinner(String label) {
  const chars = ['|', '/', '-', r'\'];
  int i = 0;
  stdout.write('$label ${chars[i]}');
  return Timer.periodic(const Duration(milliseconds: 120), (_) {
    i = (i + 1) % chars.length;
    stdout.write('\r$label ${chars[i]} ');
  });
}

/// Inspect [tmpPath] (a temporary extraction/clone directory) and select a
/// likely repository root that contains the `pages/` folder or PNG files.
///
/// The function will:
/// - return [tmpPath] itself if it already contains `pages/` or PNGs,
/// - otherwise scan direct child directories (ignoring `.git`) and prefer a
///   child that has `pages/` or PNGs,
/// - finally fallback to the child directory with the most entries.
String _findRepoRoot(String tmpPath) {
  final tmpDir = Directory(tmpPath);
  try {
    // If pages/ exists in the root, use root directly.
    final pagesInTmp = Directory(p.join(tmpPath, 'pages'));
    if (pagesInTmp.existsSync()) return tmpPath;

    // Probe for PNG files under tmpPath itself.
    final probe = tmpDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'));
    if (probe.isNotEmpty) return tmpPath;
  } catch (_) {
    // ignore probe errors; continue to deeper search
  }

  // Otherwise examine children (ignore .git)
  final children = tmpDir
      .listSync()
      .whereType<Directory>()
      .where((d) => p.basename(d.path) != '.git')
      .toList(growable: false);

  if (children.isEmpty) return tmpPath;

  // Prefer a child that contains pages/
  for (final d in children) {
    final cand = Directory(p.join(d.path, 'pages'));
    if (cand.existsSync()) return d.path;
  }

  // Prefer a child that contains PNG files
  for (final d in children) {
    final files = d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'));
    if (files.isNotEmpty) return d.path;
  }

  // Fallback: pick the child with the most entries (most likely the repo folder)
  children.sort((a, b) {
    final aCount = a.listSync(recursive: true).length;
    final bCount = b.listSync(recursive: true).length;
    return bCount.compareTo(aCount);
  });
  return children.first.path;
}

/// Attempt to perform `git clone --depth 1` of [repoUrl] into [destPath].
///
/// Returns `true` on successful clone, `false` if git is not available or the
/// clone failed. This uses `_runProcessCaptureExit` and will show a spinner
/// while cloning.
Future<bool> _tryGitClone(String repoUrl, String destPath) async {
  final gitCheck = await _runProcessCaptureExit('git', ['--version'],
      spinnerLabel: 'checking git');
  if (gitCheck != 0) return false;
  final exit = await _runProcessCaptureExit(
      'git', ['clone', '--depth', '1', repoUrl, destPath],
      spinnerLabel: 'git clone');
  return exit == 0;
}

/// Try to download a ZIP archive from [zipUrl] into [outPath] using `curl`
/// or `wget`. Returns `true` if download succeeded (exit code 0 from either).
///
/// This uses `_runProcessCaptureExit` to run the external downloader commands.
Future<bool> _tryCurlOrWgetDownload(String zipUrl, String outPath) async {
  var exit = await _runProcessCaptureExit('curl', ['-L', '-o', outPath, zipUrl],
      spinnerLabel: 'curl download');
  if (exit == 0) return true;
  exit = await _runProcessCaptureExit('wget', ['-O', outPath, zipUrl],
      spinnerLabel: 'wget download');
  return exit == 0;
}

/// Unzip a ZIP file at [zipFilePath] into directory [extractTo] using the
/// `archive` package. Returns `true` on success, `false` on failure.
///
/// This function handles both files and directories contained in the archive.
Future<bool> _unzipUsingArchive(String zipFilePath, String extractTo) async {
  try {
    final bytes = await File(zipFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      final outPath = p.join(extractTo, filename);
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(data, flush: true);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
    return true;
  } catch (e) {
    return false;
  }
}

/// Download [zipUrl] via a pure-Dart HTTP GET and extract it into [outDir].
///
/// Returns `true` when the download and unzip succeeded, `false` otherwise.
/// This is the most portable fallback when git/curl/wget are not available.
Future<bool> _downloadZipHttpAndUnzip(String zipUrl, String outDir) async {
  try {
    final resp = await http.get(Uri.parse(zipUrl));
    if (resp.statusCode != 200) {
      print('HTTP download failed: ${resp.statusCode}');
      return false;
    }
    final tmpZip = File(p.join(outDir, 'repo.zip'));
    await tmpZip.writeAsBytes(resp.bodyBytes);
    final ok = await _unzipUsingArchive(tmpZip.path, outDir);
    if (!ok) return false;
    try {
      await tmpZip.delete();
    } catch (_) {}
    return true;
  } catch (e) {
    return false;
  }
}

/// Helper function to fetch a repository using git clone, curl, or http fallback.
///
/// It first attempts a shallow git clone. If that fails (e.g., git is not installed),
/// it tries downloading the repository archive as a ZIP file using curl or wget.
/// If those also fail, it falls back to a pure-Dart HTTP download.
///
/// Creates a temporary directory and returns its absolute path if successful.
/// The caller is responsible for cleaning up the directory.
Future<String?> _fetchRepo(String repoUrl) async {
  final tmpDir = await Directory.systemTemp.createTemp('quran_repo_');
  bool ok = false;

  // 1) try git clone
  try {
    ok = await _tryGitClone(repoUrl, tmpDir.path);
    if (ok) {
      print('Repository "$repoUrl" cloned (git).');
    } else {
      print('git clone unavailable or failed for "$repoUrl"; trying zip.');
    }
  } catch (e) {
    ok = false;
  }

  // 2) try curl/wget + unzip
  if (!ok) {
    try {
      final zipUrl =
          '${repoUrl.replaceFirst(RegExp(r'\.git$'), '')}/archive/refs/heads/main.zip';
      final zipPath = p.join(tmpDir.path, 'repo.zip');
      final dlOk = await _tryCurlOrWgetDownload(zipUrl, zipPath);
      if (dlOk) {
        final unzOk = await _unzipUsingArchive(zipPath, tmpDir.path);
        if (unzOk) ok = true;
      }
    } catch (e) {
      ok = false;
    }
  }

  // 3) pure-dart HTTP download + unzip
  if (!ok) {
    try {
      final zipUrl =
          '${repoUrl.replaceFirst(RegExp(r'\.git$'), '')}/archive/refs/heads/main.zip';
      final httpOk = await _downloadZipHttpAndUnzip(zipUrl, tmpDir.path);
      if (httpOk) ok = true;
    } catch (e) {
      ok = false;
    }
  }

  if (ok) return tmpDir.path;

  try {
    await tmpDir.delete(recursive: true);
  } catch (_) {}
  return null;
}

/// Copy PNG image files from [repoRoot] into [destPath].
///
/// The function:
/// - prefers a `pages/` subfolder inside the repo (if present),
/// - preserves relative paths under `pages/`,
/// - prompts per-file unless [overwriteAll] is true,
/// - supports a [dryRun] mode: when true, no files are written,
/// - returns a stats map: `{'copied': n, 'skipped': m, 'failed': k}`.
Future<Map<String, int>> _copyPngs(String repoRoot, String destPath,
    {required bool overwriteAll, required bool dryRun}) async {
  final srcRoot = Directory(repoRoot);
  final destination = Directory(destPath);
  final result = {'copied': 0, 'skipped': 0, 'failed': 0};

  final preferred = Directory(p.join(repoRoot, 'pages'));
  final bool preferredExists = await preferred.exists();
  final searchRoot = preferredExists ? preferred : srcRoot;

  if (!await destination.exists() && !dryRun) {
    await destination.create(recursive: true);
  }

  final pngFiles = <File>[];
  await for (final e in searchRoot.list(recursive: true, followLinks: false)) {
    if (e is File && e.path.toLowerCase().endsWith('.png')) pngFiles.add(e);
  }

  print(
      'Found ${pngFiles.length} PNG files to copy (search root: ${searchRoot.path}).');

  for (final file in pngFiles) {
    final rel = p.relative(file.path, from: searchRoot.path);
    final targetPath = p.join(destination.path, rel);
    final targetFile = File(targetPath);

    if (!await targetFile.parent.exists() && !dryRun) {
      await targetFile.parent.create(recursive: true);
    }

    if (await targetFile.exists()) {
      if (!overwriteAll) {
        stdout.write('File $rel exists — overwrite? (y/N): ');
        final ans = stdin.readLineSync();
        if (ans == null || ans.toLowerCase() != 'y') {
          result['skipped'] = result['skipped']! + 1;
          continue;
        }
      }
    }

    try {
      if (!dryRun) {
        await file.copy(targetFile.path);
      }
      result['copied'] = result['copied']! + 1;
    } catch (e) {
      print('Failed to copy ${file.path}: $e');
      result['failed'] = result['failed']! + 1;
    }
  }

  return result;
}

/// Recursively finds all `.TTF` files in [repoRoot] and copies them to [destFontsPath].
///
/// It scans the repository root for any file ending with `.ttf` (case-insensitive)
/// and copies each to the specified destination. If a font already exists at the
/// destination, it prompts for overwrite unless [overwriteAll] is true.
///
/// Returns a list of filenames of the fonts that were successfully copied.
Future<List<String>> _copyAllFonts(String repoRoot, String destFontsPath,
    {required bool overwriteAll, required bool dryRun}) async {
  final result = <String>[];
  final rootDir = Directory(repoRoot);
  final destDir = Directory(destFontsPath);

  if (!await destDir.exists() && !dryRun) {
    await destDir.create(recursive: true);
  }

  final files = <File>[];
  await for (final e in rootDir.list(recursive: true, followLinks: false)) {
    if (e is File && e.path.toLowerCase().endsWith('.ttf')) {
      files.add(e);
    }
  }

  print('Found ${files.length} font files to copy.');

  for (final file in files) {
    final name = p.basename(file.path);
    final targetPath = p.join(destFontsPath, name);
    final targetFile = File(targetPath);

    if (await targetFile.exists()) {
      if (!overwriteAll) {
        stdout.write('Font $name exists — overwrite? (y/N): ');
        final ans = stdin.readLineSync();
        if (ans == null || ans.toLowerCase() != 'y') continue;
      }
    }

    try {
      if (!dryRun) {
        await file.copy(targetFile.path);
      }
      result.add(name);
    } catch (e) {
      print('Failed to copy font $name: $e');
    }
  }

  return result;
}

/// Safely ensure that `flutter.assets` contains [assetPath] and that
/// `flutter.fonts` contains a mapping for [fontFamily] pointing to [fontAsset]
/// (if provided). Uses `yaml_edit` to modify `pubspec.yaml` reliably.
///
/// If [dryRun] is true, no file writes are performed and intended changes are
/// printed instead.
///
/// The function will:
/// - parse the existing `pubspec.yaml`,
/// - if `flutter` key is missing, create it with `uses-material-design: true`
///   and an `assets` list containing [assetPath] (and font mapping if provided),
/// - if `assets` exists, append [assetPath] if missing,
/// - if `fonts` exists, append the provided family/asset mapping or create it.
/// Update the `pubspec.yaml` of the project to include asset paths and font mappings.
///
/// This function generates a comprehensive `flutter:` section containing:
/// 1. An `assets` entry for the pages images.
/// 2. A `fonts` list with 605 entries. `QCF_P000` is mapped to family `suraNameFont`,
///    while all others use their filename as the family name.
///
/// If [dryRun] is enabled, it prints the intended changes without modifying the file.
Future<void> _ensurePubspecHasAssetsAndFonts(String projectRoot,
    {required String assetPath,
    required List<String> fontFiles,
    required String fontsDestRelative,
    required bool dryRun}) async {
  final pubFile = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!await pubFile.exists()) return;

  final original = await pubFile.readAsString();
  final editor = YamlEditor(original);

  // Generate the list of fonts as requested by the user
  final List<Map<String, dynamic>> fontsList = [];
  fontFiles.sort(); // ensure QCF_P000 is first if present

  for (final file in fontFiles) {
    final name = p.basenameWithoutExtension(file);
    final family = (name == 'QCF_P000') ? 'suraNameFont' : name;
    final asset = p.join(fontsDestRelative, file);

    fontsList.add({
      'family': family,
      'fonts': [
        {'asset': asset}
      ]
    });
  }

  // Update flutter section
  final flutterMap = {
    'uses-material-design': true,
    'assets': [assetPath],
    'fonts': fontsList,
  };

  if (dryRun) {
    print(
        'DRY-RUN: Would update pubspec.yaml with ${fontsList.length} font families.');
    return;
  }

  editor.update(['flutter'], flutterMap);
  await pubFile.writeAsString(editor.toString());
  print(
      'Updated pubspec.yaml with assets and ${fontsList.length} font families.');
}

/// Facilitates the entire fetch-and-copy process for both images and fonts.
///
/// Workflow:
/// 1. Fetches the pages repository and copies PNG images.
/// 2. Fetches the fonts repository and copies all TTF font files.
/// 3. Updates `pubspec.yaml` to register all copied assets and fonts.
/// 4. Runs `flutter pub get` to apply the configuration changes.
///
/// If [dryRun] is true, no permanent changes are made to the filesystem.
Future<void> _handleFetchPagesAndFonts(String pagesRepo, String fontsRepo,
    String destPagesRelative, String destFontsRelative,
    {required bool overwriteAll, required bool dryRun}) async {
  final cwd = Directory.current.path;

  // 1) Fetch Pages Repo
  print('Fetching pages repository...');
  final pagesTmpPath = await _fetchRepo(pagesRepo);
  if (pagesTmpPath == null) {
    print('Failed to fetch pages repository.');
    return;
  }
  final pagesRepoRoot = _findRepoRoot(pagesTmpPath);
  final pagesDest = p.normalize(p.join(cwd, destPagesRelative));
  final pagesStats = await _copyPngs(pagesRepoRoot, pagesDest,
      overwriteAll: overwriteAll, dryRun: dryRun);
  print('Pages copied: ${pagesStats['copied']} file(s).');

  // 2) Fetch Fonts Repo
  print('Fetching fonts repository...');
  final fontsTmpPath = await _fetchRepo(fontsRepo);
  if (fontsTmpPath == null) {
    print('Failed to fetch fonts repository.');
    return;
  }
  final fontsRepoRoot = _findRepoRoot(fontsTmpPath);
  final fontsDest = p.normalize(p.join(cwd, destFontsRelative));
  final fontFiles = await _copyAllFonts(fontsRepoRoot, fontsDest,
      overwriteAll: overwriteAll, dryRun: dryRun);
  print('Fonts copied: ${fontFiles.length} file(s).');

  // 3) Update Pubspec
  final normalizedAssetPath = destPagesRelative.endsWith('/')
      ? destPagesRelative
      : '$destPagesRelative/';
  await _ensurePubspecHasAssetsAndFonts(cwd,
      assetPath: normalizedAssetPath,
      fontFiles: fontFiles,
      fontsDestRelative: destFontsRelative,
      dryRun: dryRun);

  // 4) Pub Get
  if (!dryRun) {
    print('Running flutter pub get...');
    await _runProcessCaptureExit('flutter', ['pub', 'get'],
        spinnerLabel: 'flutter pub get');
  }

  // Cleanup
  try {
    await Directory(pagesTmpPath).delete(recursive: true);
    await Directory(fontsTmpPath).delete(recursive: true);
  } catch (_) {}

  print('All operations completed.');
}

/// Print usage information for the CLI.
void _printHelp(ArgParser parser) {
  print(
      'quran_assets_cli - fetch quran pages and font into your Flutter project assets');
  print('');
  print(
      'Usage: quran_assets_cli fetch-assets [--pages-repo <git-url>] [--fonts-repo <git-url>] [--pages-dest <assets/pages>] [--fonts-dest <assets/fonts>] [--yes] [--dry-run]');
  print('');
  print(parser.usage);
}

/// CLI entrypoint.
///
/// Supports the `fetch-assets` command with the following options:
/// - `--repo` (`-r`): Git repository URL (defaults to the quran_pages repo)
/// - `--pages-dest` (`-p`): destination folder for page images (default: `assets/pages`)
/// - `--fonts-dest` (`-f`): destination folder for fonts (default: `assets/fonts`)
/// - `--font` (`-t`): font filename to search for (default: `QCF_P000.ttf`)
/// - `--family` (`-n`): font family name to add to `pubspec.yaml` (default: `suraNameFont`)
/// - `--yes` (`-y`): overwrite existing files without prompting
/// - `--dry-run`: preview actions without writing files
Future<void> main(List<String> args) async {
  final parser = ArgParser();
  parser.addCommand('fetch-assets')
    ..addOption('pages-repo',
        abbr: 'r',
        help: 'Git repository URL for Quran page images',
        defaultsTo: 'https://github.com/Yosuef-Sayed/quran_pages.git')
    ..addOption('fonts-repo',
        help: 'Git repository URL for Quran fonts',
        defaultsTo: 'https://github.com/Yosuef-Sayed/quran_fonts.git')
    ..addOption('pages-dest',
        abbr: 'p',
        help: 'Destination assets path for pages (relative to project root)',
        defaultsTo: 'assets/pages')
    ..addOption('fonts-dest',
        abbr: 'f',
        help: 'Destination assets path for fonts (relative to project root)',
        defaultsTo: 'assets/fonts')
    ..addFlag('yes',
        abbr: 'y',
        negatable: false,
        help: 'Overwrite existing files without prompting')
    ..addFlag('dry-run',
        negatable: false, help: 'Show actions but do not perform writes');

  parser.addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    print('Error parsing args: $e');
    _printHelp(parser);
    exit(2);
  }

  if (results['help'] == true || results.command == null) {
    _printHelp(parser);
    return;
  }

  if (results.command!.name == 'fetch-assets') {
    final pagesRepo = results.command!['pages-repo'] as String;
    final fontsRepo = results.command!['fonts-repo'] as String;
    var pagesDest = results.command!['pages-dest'] as String;
    var fontsDest = results.command!['fonts-dest'] as String;
    final yes = results.command!['yes'] as bool;
    final dryRun = results.command!['dry-run'] as bool;

    // normalize dest: ensure relative path
    pagesDest = pagesDest.replaceAll(RegExp(r'^[\\/]+'), '');
    fontsDest = fontsDest.replaceAll(RegExp(r'^[\\/]+'), '');

    print('Will fetch pages from: $pagesRepo');
    print('Will fetch fonts from: $fontsRepo');
    if (dryRun) print('DRY-RUN mode: no files will be written.');

    if (!dryRun && !yes) {
      stdout.write(
          'Proceed with download and add assets to "$pagesDest" and fonts to "$fontsDest"? (y/N): ');
      final ans = stdin.readLineSync();
      if (ans == null || ans.toLowerCase() != 'y') {
        print('Aborted by user.');
        return;
      }
    }

    await _handleFetchPagesAndFonts(pagesRepo, fontsRepo, pagesDest, fontsDest,
        overwriteAll: yes, dryRun: dryRun);
  } else {
    _printHelp(parser);
  }
}
