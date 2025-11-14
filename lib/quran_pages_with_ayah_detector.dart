// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quran_pages_with_ayah_detector/ayah_data.dart';

/// Ayah segment info (a rectangular piece of an ayah on a single line).
class Segment {
  /// Sura number for this segment.
  final int sura;

  /// Ayah number for this segment.
  final int ayah;

  /// Line index on the page for this segment.
  final int line;

  /// Bounding box coordinates in image-space (original image pixels).
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

  /// Width of the segment (image-space).
  double get width => maxX - minX;

  /// Height of the segment (image-space).
  double get height => maxY - minY;

  /// Area of the bounding box (for sorting/filtering).
  double get area => width * height;
}

/// A page viewer that displays Quran page images and tappable ayah segments.
///
/// Use [onAyahTap] to receive callbacks when the user long-presses an ayah.
/// The widget will highlight all segments that belong to the same ayah.
class QuranPageView extends StatefulWidget {
  /// Path prefix for page images. The widget will load `${pageImagePath}{pageNumber}.png`.
  final String pageImagePath;

  /// If true, shows debugging overlays (red boxes) for segments.
  final bool debuggingMode;

  /// If true, the page image color will adapt to the surrounding icon/theme color.
  final bool themeModeAdaption;

  /// Color used to tint the page image when [themeModeAdaption] is active.
  final Color textColor;

  /// Called when the user long-presses an ayah. Provides (sura, ayah, pageNumber).
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  /// Highlight color used when an ayah is selected (semi-transparent overlay).
  final Color highlightColor;

  /// Duration for highlight fade-in/out animation.
  final Duration highlightDuration;

  const QuranPageView({
    super.key,
    this.onAyahTap,
    this.pageImagePath = "assets/pages/",
    this.debuggingMode = false,
    this.themeModeAdaption = true,
    this.textColor = Colors.black,
    this.highlightColor = Colors.blue,
    this.highlightDuration = const Duration(milliseconds: 220),
  });

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
        debuggingMode: widget.debuggingMode,
        themeModeAdaption: widget.themeModeAdaption,
        textColor: widget.textColor,
        highlightColor: widget.highlightColor,
        highlightDuration: widget.highlightDuration,
      ),
    );
  }
}

/// Internal widget that renders a single page and per-line ayah segments.
class _QuranPage extends StatefulWidget {
  /// Page number to render (1-based).
  final int pageNumber;

  /// Path prefix for page images.
  final String pageImagePath;

  /// Debugging mode to show raw segment boxes.
  final bool debuggingMode;

  /// Whether to tint the page image with theme color.
  final bool themeModeAdaption;

  /// Tint color used if [themeModeAdaption] is true.
  final Color textColor;

  /// Callback for ayah long-press.
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  /// Highlight color for selection overlays.
  final Color highlightColor;

  /// Duration for highlight animation.
  final Duration highlightDuration;

  const _QuranPage({
    required this.pageNumber,
    this.onAyahTap,
    required this.pageImagePath,
    required this.debuggingMode,
    required this.themeModeAdaption,
    required this.textColor,
    required this.highlightColor,
    required this.highlightDuration,
  });

  @override
  State<_QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<_QuranPage> {
  List<Segment> _segments = [];

  /// Currently selected ayah key in the form "sura_ayah" (e.g. "2_255").
  String? _selectedAyahKey;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Loads ayah segments for the current page and resolves tiny overlaps per line.
  Future<void> _loadData() async {
    final rows = ayahRows.where((r) {
      final pn = r['page_number'];
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

    // Resolve overlaps within the same line (unchanged).
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

    // Keep per-line segments (so no large merged boxes that overlap)
    resolved.sort((a, b) => a.area.compareTo(b.area));

    if (!mounted) return;
    setState(() {
      _segments = resolved;
    });
  }

  /// Clears the current selection (used for tap-to-clear anywhere).
  void _clearSelection() {
    if (_selectedAyahKey != null) {
      setState(() {
        _selectedAyahKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerW = constraints.maxWidth;
        final containerH = constraints.maxHeight;
        // NOTE: keep these image dims consistent with your image assets.
        final imgW = 1920.0;
        final imgH = 3106.0;
        final scale = min(containerW / imgW, containerH / imgH);
        final dispW = imgW * scale;
        final dispH = imgH * scale;
        final offsetX = (containerW - dispW) / 2.0;
        final offsetY = (containerH - dispH) / 2.0;

        // Top-level GestureDetector: single tap anywhere clears selection.
        // Use translucent behavior so children still receive gestures.
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _clearSelection,
          child: Stack(
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: dispW,
                height: dispH,
                child: Image.asset(
                  '${widget.pageImagePath}${widget.pageNumber}.png',
                  fit: BoxFit.fill,
                  color: widget.themeModeAdaption
                      ? IconTheme.of(context).color
                      : widget.textColor,
                ),
              ),

              // Render every segment (per-line). Long-pressing any segment toggles highlight for whole ayah.
              for (final s in _segments)
                Positioned(
                  left: offsetX + s.minX * scale,
                  top: offsetY + s.minY * scale,
                  width: s.width * scale,
                  height: s.height * scale,
                  child: GestureDetector(
                    // Long-press toggles selection of the ayah (all segments with same sura+ayah).
                    onLongPress: () {
                      final key = '${s.sura}_${s.ayah}';
                      setState(() {
                        if (_selectedAyahKey == key) {
                          _selectedAyahKey = null; // toggle off
                        } else {
                          _selectedAyahKey = key; // select this ayah
                        }
                      });
                      if (widget.onAyahTap != null) {
                        widget.onAyahTap!(s.sura, s.ayah, widget.pageNumber);
                      }
                    },
                    child: Stack(
                      children: [
                        // AnimatedOpacity drives fade in/out of the highlight overlay.
                        AnimatedOpacity(
                          opacity: widget.debuggingMode
                              ? 1.0
                              : (_selectedAyahKey == '${s.sura}_${s.ayah}'
                                  ? 1.0
                                  : 0.0),
                          duration: widget.highlightDuration,
                          curve: Curves.easeInOut,
                          child: Container(
                            decoration: BoxDecoration(
                              // Debugging mode shows a red overlay; otherwise use highlight color.
                              color: widget.debuggingMode
                                  ? Colors.red.withOpacity(.22)
                                  : widget.highlightColor.withOpacity(.22),
                              border: Border.all(
                                color: widget.debuggingMode
                                    ? Colors.red.withOpacity(.5)
                                    : (_selectedAyahKey == '${s.sura}_${s.ayah}'
                                        ? widget.highlightColor.withOpacity(.5)
                                        : Colors.transparent),
                                width: 1,
                              ),
                            ),
                          ),
                        ),

                        // Transparent container on top to ensure the region is hittable
                        // and to maintain layout even when highlight opacity is 0.
                        Container(
                          color: Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
