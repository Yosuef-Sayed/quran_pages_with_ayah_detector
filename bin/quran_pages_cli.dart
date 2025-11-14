#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// ----- Utilities -----

Future<int> _runProcessCaptureExit(String exe, List<String> args,
    {bool runInShell = true, String spinnerLabel = 'running'}) async {
  try {
    final process = await Process.start(exe, args, runInShell: runInShell);
    final spinner = _startSpinner(spinnerLabel);
    // pipe stdout/stderr to our stdout/stderr
    process.stdout.listen((b) => stdout.add(b));
    process.stderr.listen((b) => stderr.add(b));
    final code = await process.exitCode;
    spinner.cancel();
    stdout.writeln(''); // newline after spinner
    return code;
  } catch (e) {
    return -1;
  }
}

Timer _startSpinner(String label) {
  const chars = ['|', '/', '-', r'\'];
  int i = 0;
  stdout.write('$label ${chars[i]}');
  return Timer.periodic(const Duration(milliseconds: 120), (_) {
    i = (i + 1) % chars.length;
    stdout.write('\r$label ${chars[i]} ');
  });
}

/// ----- Repo download helpers -----

String _findRepoRoot(String tmpPath) {
  // Prefer the tmpPath itself if it contains 'pages' or pngs
  final tmpDir = Directory(tmpPath);
  try {
    final pagesInTmp = Directory(p.join(tmpPath, 'pages'));
    if (pagesInTmp.existsSync()) return tmpPath;

    // quick PNG probe in tmpPath
    final probe = tmpDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'));
    if (probe.isNotEmpty) return tmpPath;
  } catch (_) {}

  // Otherwise look for child directories that look like the repo root.
  final children = tmpDir
      .listSync()
      .whereType<Directory>()
      .where((d) => p.basename(d.path) != '.git')
      .toList(growable: false);

  if (children.isEmpty) return tmpPath;

  // 1) pick a child that has pages/ subfolder
  for (final d in children) {
    final cand = Directory(p.join(d.path, 'pages'));
    if (cand.existsSync()) return d.path;
  }

  // 2) pick child that contains pngs
  for (final d in children) {
    final files = d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'));
    if (files.isNotEmpty) return d.path;
  }

  // 3) fallback: choose the largest child by file count (most likely the repo folder)
  children.sort((a, b) {
    final aCount = a.listSync(recursive: true).length;
    final bCount = b.listSync(recursive: true).length;
    return bCount.compareTo(aCount);
  });
  return children.first.path;
}

Future<bool> _tryGitClone(String repoUrl, String destPath) async {
  final gitCheck = await _runProcessCaptureExit('git', ['--version'],
      spinnerLabel: 'checking git');
  if (gitCheck != 0) return false;
  final exit = await _runProcessCaptureExit(
      'git', ['clone', '--depth', '1', repoUrl, destPath],
      spinnerLabel: 'git clone');
  return exit == 0;
}

Future<bool> _tryCurlOrWgetDownload(String zipUrl, String outPath) async {
  // try curl
  var exit = await _runProcessCaptureExit('curl', ['-L', '-o', outPath, zipUrl],
      spinnerLabel: 'curl download');
  if (exit == 0) return true;
  // try wget
  exit = await _runProcessCaptureExit('wget', ['-O', outPath, zipUrl],
      spinnerLabel: 'wget download');
  return exit == 0;
}

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
    if (!ok) {
      return false;
    }
    try {
      await tmpZip.delete();
    } catch (_) {}
    return true;
  } catch (e) {
    return false;
  }
}

/// ----- Copy PNGs -----

Future<Map<String, int>> _copyPngs(String repoRoot, String destPath,
    {required bool overwriteAll, required bool dryRun}) async {
  final srcRoot = Directory(repoRoot);
  final destination = Directory(destPath);
  final result = {'copied': 0, 'skipped': 0, 'failed': 0};

  // prefer pages/ subfolder (common layout)
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

/// ----- pubspec editing (safe append-if-missing strategy) -----

Future<void> _ensurePubspecHasAsset(String projectRoot, String assetPath,
    {required bool dryRun}) async {
  final pubFile = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!await pubFile.exists()) {
    print('ERROR: pubspec.yaml not found at $projectRoot');
    return;
  }

  final content = await pubFile.readAsString();

  // Load YAML document (for inspection)
  YamlMap? doc;
  try {
    final node = loadYaml(content);
    if (node is YamlMap) doc = node;
  } catch (e) {
    // If YAML parse fails, fallback to append behavior below.
    doc = null;
  }

  // If parsing failed, fallback: append a safe flutter/assets block at the end.
  if (doc == null) {
    final appendBlock =
        '\n\n# Added by quran_pages_cli\nflutter:\n  assets:\n    - $assetPath\n';
    if (dryRun) {
      print('DRY-RUN: pubspec not parseable. Would append:\n$appendBlock');
      return;
    }
    await pubFile.writeAsString(content.trimRight() + appendBlock);
    print(
        'pubspec.yaml was not parseable; appended flutter/assets block at end.');
    return;
  }

  // If asset already present anywhere, do nothing.
  if (content.contains('\n- $assetPath') ||
      content.contains('\n- $assetPath/')) {
    print('pubspec.yaml already lists asset path: $assetPath');
    return;
  }

  // Use yaml_edit to safely update the document
  final editor = YamlEditor(content);

  // Ensure `flutter` mapping exists
  if (!doc.containsKey('flutter')) {
    if (dryRun) {
      print('DRY-RUN: would add flutter.assets -> $assetPath');
      return;
    }
    // create flutter with assets list
    editor.update([
      'flutter'
    ], {
      'uses-material-design': true,
      'assets': [assetPath]
    });
    await pubFile.writeAsString(editor.toString());
    print('Added flutter with assets -> $assetPath');
    return;
  }

  // flutter exists
  final flutterNode = doc['flutter'];
  // If flutter exists but is not a map (weird), fallback to appending block
  if (flutterNode is! YamlMap) {
    final appendBlock =
        '\n\n# Added by quran_pages_cli\nflutter:\n  assets:\n    - $assetPath\n';
    if (dryRun) {
      print('DRY-RUN: flutter is not a mapping. Would append:\n$appendBlock');
      return;
    }
    await pubFile.writeAsString(content.trimRight() + appendBlock);
    print('flutter was not a mapping; appended fallback flutter/assets block.');
    return;
  }

  // If assets is missing, add it
  if (!flutterNode.containsKey('assets')) {
    if (dryRun) {
      print('DRY-RUN: would add assets: - $assetPath under flutter');
      return;
    }
    editor.update(['flutter', 'assets'], [assetPath]);
    await pubFile.writeAsString(editor.toString());
    print('Inserted assets list under flutter with: $assetPath');
    return;
  }

  // assets exists: ensure it's a list and append if missing
  final assetsNode = flutterNode['assets'];
  if (assetsNode is! YamlList) {
    // if assets exists but not a list, fallback to replacing it with a list
    if (dryRun) {
      print(
          'DRY-RUN: assets found but not a list. Would replace with list containing $assetPath');
      return;
    }
    editor.update(['flutter', 'assets'], [assetPath]);
    await pubFile.writeAsString(editor.toString());
    print('Replaced non-list assets with list containing: $assetPath');
    return;
  }

  // Convert existing assets to plain Dart list to check membership
  final existingAssets =
      (jsonDecode(jsonEncode(assetsNode)) as List).cast<String>();
  if (existingAssets.contains(assetPath) ||
      existingAssets.contains(assetPath.replaceAll(RegExp(r'/$'), ''))) {
    print('Asset path already listed under flutter.assets: $assetPath');
    return;
  }

  // Append to existing list
  final newList = List<String>.from(existingAssets)..add(assetPath);
  if (dryRun) {
    print(
        'DRY-RUN: would append $assetPath to flutter.assets (currently ${existingAssets.length} entries)');
    return;
  }
  editor.update(['flutter', 'assets'], newList);
  await pubFile.writeAsString(editor.toString());
  print('Appended $assetPath to flutter.assets');
}

/// ----- Main handler -----

Future<void> _handleFetchPages(String repoUrl, String destRelativePath,
    {required bool overwriteAll, required bool dryRun}) async {
  final cwd = Directory.current.path;
  final tmpDir = await Directory.systemTemp.createTemp('quran_pages_repo_');
  print('Using temporary directory: ${tmpDir.path}');

  bool ok = false;
  // 1) git clone
  try {
    ok = await _tryGitClone(repoUrl, tmpDir.path);
    if (ok) {
      print('Repository cloned (git).');
    } else {
      print('git clone unavailable or failed; trying zip downloads.');
    }
  } catch (e) {
    print('git clone attempt failed: $e');
    ok = false;
  }

  // 2) curl/wget zip + unzip
  if (!ok) {
    try {
      final zipUrl =
          '${repoUrl.replaceFirst(RegExp(r'\.git$'), '')}/archive/refs/heads/main.zip';
      final zipPath = p.join(tmpDir.path, 'repo.zip');
      final dlOk = await _tryCurlOrWgetDownload(zipUrl, zipPath);
      if (dlOk) {
        final unzOk = await _unzipUsingArchive(zipPath, tmpDir.path);
        if (unzOk) {
          ok = true;
        }
      }
    } catch (e) {
      print('curl/wget attempt failed: $e');
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
      print('HTTP fallback failed: $e');
      ok = false;
    }
  }

  if (!ok) {
    print('Failed to retrieve repository. Aborting.');
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
    return;
  }

  final repoRoot = _findRepoRoot(tmpDir.path);
  print('Detected repository root: $repoRoot');

  // perform copying
  final projectDest = p.normalize(p.join(cwd, destRelativePath));
  final stats = await _copyPngs(repoRoot, projectDest,
      overwriteAll: overwriteAll, dryRun: dryRun);

  print(
      'Copy finished. stats: copied=${stats['copied']}, skipped=${stats['skipped']}, failed=${stats['failed']}');

  // update pubspec.yaml — ensure trailing slash and asset entry
  final normalizedAssetPath =
      destRelativePath.endsWith('/') ? destRelativePath : '$destRelativePath/';
  await _ensurePubspecHasAsset(cwd, normalizedAssetPath, dryRun: dryRun);

  // run flutter pub get automatically (no asking) unless dry-run
  if (!dryRun) {
    print('Running flutter pub get (automatic) ...');
    final code = await _runProcessCaptureExit('flutter', ['pub', 'get'],
        spinnerLabel: 'flutter pub get');
    if (code != 0) {
      print(
          'flutter pub get failed with exit code $code. You may run it manually.');
    } else {
      print('flutter pub get completed.');
    }
  } else {
    print('DRY-RUN: skipped flutter pub get.');
  }

  // cleanup
  try {
    await tmpDir.delete(recursive: true);
  } catch (_) {}

  print('All done.');
}

/// ----- CLI -----

void _printHelp(ArgParser parser) {
  print('quran_pages_cli - fetch quran pages into your Flutter project assets');
  print('');
  print(
      'Usage: quran_pages_cli fetch-pages [--repo <git-url>] [--dest <assets/path>] [--yes] [--dry-run]');
  print('');
  print(parser.usage);
}

Future<void> main(List<String> args) async {
  final parser = ArgParser();
  parser.addCommand('fetch-pages')
    ..addOption('repo',
        abbr: 'r',
        help: 'Git repository URL',
        defaultsTo: 'https://github.com/Yosuef-Sayed/quran_pages.git')
    ..addOption('dest',
        abbr: 'd',
        help: 'Destination assets path (relative to project root)',
        defaultsTo: 'assets/pages')
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

  if (results.command!.name == 'fetch-pages') {
    final repo = results.command!['repo'] as String;
    var dest = results.command!['dest'] as String;
    final yes = results.command!['yes'] as bool;
    final dryRun = results.command!['dry-run'] as bool;

    // normalize dest: ensure it doesn't start with slash and is relative
    dest = dest.replaceAll(RegExp(r'^[\\/]+'), '');
    print('Will fetch pages from: $repo');
    if (dryRun) print('DRY-RUN mode: no files will be written.');

    // If not dry-run and not yes, ask once to confirm the full operation (not per-file)
    if (!dryRun && !yes) {
      stdout.write('Proceed with download and add assets to "$dest"? (y/N): ');
      final ans = stdin.readLineSync();
      if (ans == null || ans.toLowerCase() != 'y') {
        print('Aborted by user.');
        return;
      }
    }

    await _handleFetchPages(repo, dest, overwriteAll: yes, dryRun: dryRun);
  } else {
    _printHelp(parser);
  }
}
