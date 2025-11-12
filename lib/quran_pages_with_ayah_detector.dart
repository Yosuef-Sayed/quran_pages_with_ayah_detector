library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Public database handle
late final Database _sharedDb;

/// Ayah segment info
class Segment {
  final int sura;
  final int ayah;
  final int line;
  double minX, minY, maxX, maxY;

  Segment({
    required this.sura,
    required this.ayah,
    required this.line,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  double get width => maxX - minX;
  double get height => maxY - minY;
  double get area => width * height;
}

/// The main widget users can add
class QuranPageView extends StatefulWidget {
  /// Callback when user taps an ayah
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  const QuranPageView({super.key, this.onAyahTap});

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  bool _dbLoaded = false;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    final dbPath = await getDatabasesPath();
    final dbFile = p.join(dbPath, 'ayahinfo_1920.db');
    if (!await databaseExists(dbFile)) {
      final bytes = (await rootBundle.load(
        'assets/db/ayahinfo_1920.db',
      ))
          .buffer
          .asUint8List();
      await File(dbFile).writeAsBytes(bytes, flush: true);
    }
    _sharedDb = await openDatabase(dbFile);
    if (mounted) setState(() => _dbLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_dbLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFBDB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PageView.builder(
      itemCount: 604,
      reverse: true,
      itemBuilder: (c, i) => _QuranPage(
        pageNumber: i + 1,
        onAyahTap: widget.onAyahTap,
      ),
    );
  }
}

class _QuranPage extends StatefulWidget {
  final int pageNumber;
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  const _QuranPage({required this.pageNumber, this.onAyahTap});

  @override
  State<_QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<_QuranPage> {
  List<Segment> _segments = [];
  bool _loading = true;
  final bool debugShowFill = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rows = await _sharedDb.query(
      'glyphs',
      where: 'page_number = ?',
      whereArgs: [widget.pageNumber],
    );

    final Map<String, Segment> grouped = {};

    for (final r in rows) {
      final sura = (r['sura_number'] as num).toInt();
      final ayah = (r['ayah_number'] as num).toInt();
      final line = (r['line_number'] as num).toInt();
      final minx = (r['min_x'] as num).toDouble();
      final miny = (r['min_y'] as num).toDouble();
      final maxx = (r['max_x'] as num).toDouble();
      final maxy = (r['max_y'] as num).toDouble();
      final key = '${sura}_${ayah}_$line';

      if (!grouped.containsKey(key)) {
        grouped[key] = Segment(
          sura: sura,
          ayah: ayah,
          line: line,
          minX: minx,
          minY: miny,
          maxX: maxx,
          maxY: maxy,
        );
      } else {
        final cur = grouped[key]!;
        cur.minX = min(cur.minX, minx);
        cur.minY = min(cur.minY, miny);
        cur.maxX = max(cur.maxX, maxx);
        cur.maxY = max(cur.maxY, maxy);
      }
    }

    final Map<int, List<Segment>> byLine = {};
    for (final s in grouped.values) {
      byLine.putIfAbsent(s.line, () => []).add(s);
    }

    final List<Segment> resolved = [];
    for (final entry in byLine.entries) {
      final list = entry.value;
      list.sort((a, b) => a.minX.compareTo(b.minX));
      for (int i = 1; i < list.length; i++) {
        final prev = list[i - 1];
        final curr = list[i];
        if (prev.maxX > curr.minX) {
          final cut = (prev.maxX + curr.minX) / 2.0;
          prev.maxX = cut;
          curr.minX = cut;
          if (prev.maxX - prev.minX < 2.0) prev.maxX = prev.minX + 2.0;
          if (curr.maxX - curr.minX < 2.0) curr.maxX = curr.minX + 2.0;
        }
      }
      resolved.addAll(list);
    }

    resolved.sort((a, b) => a.area.compareTo(b.area));

    if (!mounted) return;
    setState(() {
      _segments = resolved;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFBDB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBDB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final containerW = constraints.maxWidth;
          final containerH = constraints.maxHeight;
          final imgW = 1920.0;
          final imgH = 3106.0;
          final scale = min(containerW / imgW, containerH / imgH);
          final dispW = imgW * scale;
          final dispH = imgH * scale;
          final offsetX = (containerW - dispW) / 2.0;
          final offsetY = (containerH - dispH) / 2.0;

          return Stack(
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: dispW,
                height: dispH,
                child: Image.asset(
                  'assets/pages/${widget.pageNumber}.png',
                  fit: BoxFit.fill,
                ),
              ),
              for (final s in _segments)
                Positioned(
                  left: offsetX + s.minX * scale,
                  top: offsetY + s.minY * scale,
                  width: s.width * scale,
                  height: s.height * scale,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.onAyahTap != null) {
                        widget.onAyahTap!(s.sura, s.ayah, widget.pageNumber);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: debugShowFill
                            ? Colors.red.withOpacity(0.12)
                            : Colors.transparent,
                        border: Border.all(
                          color: debugShowFill
                              ? Colors.red.withOpacity(0.6)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
