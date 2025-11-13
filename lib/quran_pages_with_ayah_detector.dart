import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quran_pages_with_ayah_detector/ayah_data.dart';

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
  final String pageImagePath;
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  const QuranPageView({super.key, this.onAyahTap, required this.pageImagePath});

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: 604,
      reverse: true,
      itemBuilder: (c, i) => _QuranPage(
        pageNumber: i + 1,
        onAyahTap: widget.onAyahTap,
        pageImagePath: widget.pageImagePath,
      ),
    );
  }
}

class _QuranPage extends StatefulWidget {
  final int pageNumber;
  final String pageImagePath;
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  const _QuranPage(
      {required this.pageNumber, this.onAyahTap, required this.pageImagePath});

  @override
  State<_QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<_QuranPage> {
  List<Segment> _segments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rows = ayahRows.where((r) {
      final pn = r['page_number'];
      // some values might be strings; do safe compare
      if (pn is int) return pn == widget.pageNumber;
      if (pn is String) return int.tryParse(pn) == widget.pageNumber;
      return false;
    });

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
                '${widget.pageImagePath}${widget.pageNumber}.png',
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
                    widget.onAyahTap!(s.sura, s.ayah, widget.pageNumber);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(
                        color: Colors.transparent,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
