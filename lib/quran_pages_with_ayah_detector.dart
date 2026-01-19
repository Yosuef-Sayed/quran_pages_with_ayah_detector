// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quran_pages_with_ayah_detector/data/arabic_numbers.dart';
import 'package:quran_pages_with_ayah_detector/data/ayah_data.dart';
import 'package:quran_pages_with_ayah_detector/data/juz_glyph.dart';
import 'package:quran_pages_with_ayah_detector/data/sura_glyph.dart';
import 'package:quran_pages_with_ayah_detector/data/quran_clean_plain.dart';
import 'package:quran_pages_with_ayah_detector/data/sura_ayah_to_page.dart';
import 'package:quran_pages_with_ayah_detector/data/quran_text_data.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;

/// Represents a rectangular segment (part) of an ayah on a single line of a
/// Quran page image.
class Segment {
  /// The surah number this segment belongs to.
  final int sura;

  /// The ayah number this segment belongs to.
  final int ayah;

  /// The line number on the page this segment is located on.
  final int line;

  /// The minimum X coordinate of the segment's bounding box.
  double minX;

  /// The minimum Y coordinate of the segment's bounding box.
  double minY;

  /// The maximum X coordinate of the segment's bounding box.
  double maxX;

  /// The maximum Y coordinate of the segment's bounding box.
  double maxY;

  /// Creates a new [Segment] with the specified coordinates and metadata.
  Segment({
    required this.sura,
    required this.ayah,
    required this.line,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  /// Returns the width of the segment.
  double get width => maxX - minX;

  /// Returns the height of the segment.
  double get height => maxY - minY;

  /// Returns the area of the segment.
  double get area => width * height;
}

/// A widget that displays Quran pages and allows for ayah detection and interaction.
class QuranPageView extends StatefulWidget {
  /// The base path to the Quran page images.
  final String pageImagePath;

  /// The font family name used for Surah and Juz names.
  final String fontFamilyName;

  /// Enables a debugging mode that shows bounding boxes for all detected ayahs.
  final bool debuggingMode;

  /// Enables automatic theme mode adaption (light/dark colors).
  final bool themeModeAdaption;

  /// Whether to show the top bar containing Juz and Surah names.
  final bool showPageTopBar;

  /// Whether to show the page number at the bottom of the page.
  final bool showPageNumber;

  /// The text color used for page numbers and top bar text when [themeModeAdaption] is off.
  final Color textColor;

  /// Callback function triggered when an ayah is tapped.
  /// Provides the surah number, ayah number, and the current page number.
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  /// Callback function triggered when the Surah name in the top bar is tapped.
  final void Function()? onSuraNameTap;

  /// Callback function triggered when the Juz number in the top bar is tapped.
  final void Function()? onJuzNumberTap;

  /// The color used to highlight the selected or tapped ayah.
  final Color highlightColor;

  /// The duration of the highlight animation.
  final Duration highlightDuration;

  /// Whether to show a search icon in the top bar.
  final bool showSearchIcon;

  /// Custom color for the search icon.
  final Color? searchIconColor;

  /// Background color for the search overlay sheet.
  final Color searchSheetBackgroundColor;

  /// Text color for search results in the overlay.
  final Color searchResultTextColor;

  /// Color for supplementary info in search results (e.g., Surah name, page number).
  final Color? searchResultInfoColor;

  /// Hint text displayed in the search input field.
  final String searchHintText;

  /// Background color for the search input field.
  final Color? searchFieldBackgroundColor;

  /// Background color for the currently selected search result item.
  final Color? searchResultSelectionColor;

  /// Creates a [QuranPageView] with customizable behavior and styling.
  const QuranPageView({
    super.key,
    this.onAyahTap,
    this.onSuraNameTap,
    this.onJuzNumberTap,
    this.pageImagePath = "assets/pages/",
    this.fontFamilyName = "suraNameFont",
    this.debuggingMode = false,
    this.themeModeAdaption = true,
    this.showPageTopBar = true,
    this.showPageNumber = true,
    this.textColor = Colors.black,
    this.highlightColor = Colors.blue,
    this.highlightDuration = const Duration(milliseconds: 220),
    this.showSearchIcon = true,
    this.searchIconColor,
    this.searchSheetBackgroundColor = Colors.white,
    this.searchResultTextColor = Colors.black87,
    this.searchResultInfoColor,
    this.searchHintText = "البحث عن آية...",
    this.searchFieldBackgroundColor,
    this.searchResultSelectionColor,
  });

  @override

  /// Creates the state for this [QuranPageView].
  State<QuranPageView> createState() => _QuranPageViewState();
}

/// State class for [QuranPageView] that manages page navigation and search state.
class _QuranPageViewState extends State<QuranPageView> {
  /// Controller for the [PageView] that handles page transitions.
  late PageController _pageController;

  /// Whether the search overlay is currently visible.
  bool _isSearchOpen = false;

  /// List of current search results.
  List<dynamic> _searchResults = [];

  /// Timer used to debounce search input to avoid excessive computation.
  Timer? _debounce;

  /// A map that caches surah/ayah locations for each page.
  final Map<int, List<Map<String, int>>> _pageAyahMap = {};

  /// The key of the currently highlighted ayah (e.g., "sura_ayah").
  String? _highlightedAyahKey;

  /// The page number of the currently highlighted ayah.
  int? _highlightedPage;

  @override

  /// Initializes the page controller and builds the search location map.
  void initState() {
    super.initState();
    _pageController = PageController();
    _buildPageAyahMap();
  }

  @override

  /// Disposes resources used by the search and page navigation.
  void dispose() {
    _pageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Builds the internal [_pageAyahMap] from [suraAyahToPage].
  void _buildPageAyahMap() {
    suraAyahToPage.forEach((surah, ayahs) {
      ayahs.forEach((ayah, page) {
        _pageAyahMap.putIfAbsent(page, () => []).add({
          'surah': surah,
          'ayah': ayah,
        });
      });
    });
    _pageAyahMap.forEach((page, ayahs) {
      ayahs.sort((a, b) {
        if (a['surah'] != b['surah']) return a['surah']!.compareTo(b['surah']!);
        return a['ayah']!.compareTo(b['ayah']!);
      });
    });
  }

  /// Handles changes to the search query text, applying a debounce delay.
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmed);
    });
  }

  /// Executes the search logic against [quranCleanPlain].
  void _performSearch(String query) {
    final results = quranCleanPlain.where((verse) {
      final content = verse['content'] as String;
      return content.contains(query);
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

  /// Retrieves the QFC-encoded verse text for a given surah, ayah, and page.
  String _getQfcVerse(int surah, int ayah, int page) {
    final pageAyahs = _pageAyahMap[page];
    if (pageAyahs == null) return '';

    final indexOnPage = pageAyahs.indexWhere(
      (e) => e['surah'] == surah && e['ayah'] == ayah,
    );
    if (indexOnPage != -1 && indexOnPage < quranTextData[page - 1].length) {
      return quranTextData[page - 1][indexOnPage];
    }

    return pageAyahs.isNotEmpty && quranTextData[page - 1].isNotEmpty
        ? quranTextData[page - 1]
            [indexOnPage.clamp(0, quranTextData[page - 1].length - 1)]
        : '';
  }

  /// Handles tapping a search result by navigating to the page and highlighting the verse.
  void _handleSearchResultTap(int page, int surah, int ayah) {
    if (mounted) {
      setState(() {
        _isSearchOpen = false;
        _searchResults = [];
        _highlightedAyahKey = '${surah}_${ayah}';
        _highlightedPage = page;
      });
    }
    _pageController.jumpToPage(page - 1);
  }

  @override

  /// Builds the top-level view containing the Quran pages and search overlay.
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: PageView.builder(
            controller: _pageController,
            itemCount: 604,
            reverse: true,
            itemBuilder: (c, i) => _QuranPage(
              pageNumber: i + 1,
              onAyahTap: (s, a, p) {
                if (widget.onAyahTap != null) widget.onAyahTap!(s, a, p);
                setState(() {
                  _highlightedAyahKey = null;
                  _highlightedPage = null;
                });
              },
              onSuraNameTap: widget.onSuraNameTap,
              onJuzNumberTap: widget.onJuzNumberTap,
              onSearchTap: () {
                setState(() {
                  _isSearchOpen = true;
                  _searchResults = [];
                });
              },
              pageImagePath: widget.pageImagePath,
              fontFamilyName: widget.fontFamilyName,
              debuggingMode: widget.debuggingMode,
              themeModeAdaption: widget.themeModeAdaption,
              showPageTopBar: widget.showPageTopBar,
              showPageNumber: widget.showPageNumber,
              textColor: widget.textColor,
              highlightColor: widget.highlightColor,
              highlightDuration: widget.highlightDuration,
              showSearchIcon: widget.showSearchIcon,
              searchIconColor: widget.searchIconColor,
              highlightedAyahKey:
                  _highlightedPage == (i + 1) ? _highlightedAyahKey : null,
            ),
          ),
        ),
        if (_isSearchOpen) _buildSearchOverlay(),
      ],
    );
  }

  /// Builds the search overlay sheet when [_isSearchOpen] is true.
  Widget _buildSearchOverlay() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double sheetHeight =
        _searchResults.isEmpty ? 150 : (screenHeight * 0.6).clamp(150, 500);

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isSearchOpen = false;
              _searchResults = [];
            });
          },
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.only(top: 10, left: 16, right: 16),
              decoration: BoxDecoration(
                color: widget.searchSheetBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      textDirection: TextDirection.rtl,
                      cursorColor: widget.highlightColor,
                      style: TextStyle(color: widget.searchResultTextColor),
                      decoration: InputDecoration(
                        hintText: widget.searchHintText,
                        hintTextDirection: TextDirection.rtl,
                        hintStyle: TextStyle(
                            color:
                                widget.searchResultTextColor.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search,
                            color: widget.searchIconColor ?? widget.textColor),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _isSearchOpen = false;
                              _searchResults = [];
                            });
                          },
                        ),
                        filled: true,
                        fillColor: widget.searchFieldBackgroundColor ??
                            Colors.grey.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: sheetHeight - 80),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final verse = _searchResults[index];
                          final surah = verse['surah_number'] as int;
                          final ayah = verse['verse_number'] as int;
                          final page = suraAyahToPage[surah]?[ayah] ?? 1;
                          final qfcText = _getQfcVerse(surah, ayah, page);
                          final fontFamily =
                              'QCF_P${page.toString().padLeft(3, '0')}';

                          return FutureBuilder(
                            future: FontManager.loadFont(page),
                            builder: (context, snapshot) {
                              return InkWell(
                                onTap: () =>
                                    _handleSearchResultTap(page, surah, ayah),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color:
                                                Colors.grey.withOpacity(0.1))),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Text(
                                          qfcText,
                                          style: TextStyle(
                                            fontFamily: fontFamily,
                                            fontSize: 22,
                                            color: widget.searchResultTextColor,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        textDirection: TextDirection.rtl,
                                        children: [
                                          Text(
                                            'سورة ${quran.getSurahNameArabic(surah)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: widget
                                                      .searchResultInfoColor ??
                                                  widget.highlightColor,
                                            ),
                                          ),
                                          Text(
                                            'صفحة ${ArabicNumbers().convert(page)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: widget
                                                  .searchResultTextColor
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An internal widget that represents a single page of the Quran.
class _QuranPage extends StatefulWidget {
  /// The page number to display.
  final int pageNumber;

  /// The path to the page image assets.
  final String pageImagePath;

  /// The font family used for top bar text.
  final String fontFamilyName;

  /// Whether to show debugging information.
  final bool debuggingMode;

  /// Whether to adapt colors based on the current theme.
  final bool themeModeAdaption;

  /// Whether to show the top bar.
  final bool showPageTopBar;

  /// Whether to show the page number.
  final bool showPageNumber;

  /// The text color to use.
  final Color textColor;

  /// Callback for tapping an ayah.
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  /// Callback for tapping the surah name.
  final void Function()? onSuraNameTap;

  /// Callback for tapping the juz number.
  final void Function()? onJuzNumberTap;

  /// The color for highlighting ayahs.
  final Color highlightColor;

  /// The duration of the highlight animation.
  final Duration highlightDuration;

  /// Whether to show the search icon.
  final bool showSearchIcon;

  /// Custom color for the search icon.
  final Color? searchIconColor;

  /// Callback when the search icon is tapped.
  final VoidCallback? onSearchTap;

  /// The key of the ayah currently highlighted on this page.
  final String? highlightedAyahKey;

  /// Creates a [_QuranPage] with the given configuration.
  const _QuranPage({
    required this.pageNumber,
    this.onAyahTap,
    this.onSuraNameTap,
    this.onJuzNumberTap,
    this.onSearchTap,
    required this.pageImagePath,
    required this.fontFamilyName,
    required this.debuggingMode,
    required this.themeModeAdaption,
    required this.showPageTopBar,
    required this.showPageNumber,
    required this.textColor,
    required this.highlightColor,
    required this.highlightDuration,
    required this.showSearchIcon,
    this.searchIconColor,
    this.highlightedAyahKey,
  });

  @override

  /// Creates the state for this [_QuranPage].
  State<_QuranPage> createState() => _QuranPageState();
}

/// State class for [_QuranPage] that handles data loading and touch interactions.
class _QuranPageState extends State<_QuranPage> {
  /// The list of ayah segments found on this page.
  List<Segment> _segments = [];

  /// The key of the currently selected ayah.
  String? _selectedAyahKey;

  @override

  /// Updates the selection state when the parent widget changes.
  void didUpdateWidget(_QuranPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedAyahKey != oldWidget.highlightedAyahKey) {
      setState(() {
        _selectedAyahKey = widget.highlightedAyahKey;
      });
    }
  }

  @override

  /// Initializes the page and loads the ayah segment data.
  void initState() {
    super.initState();
    _selectedAyahKey = widget.highlightedAyahKey;
    _loadData();
  }

  /// Loads ayah segment coordinates for this page from [ayahRows].
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

  /// Clears the current ayah selection.
  void _clearSelection() {
    if (_selectedAyahKey != null) {
      setState(() {
        _selectedAyahKey = null;
      });
    }
  }

  @override

  /// Builds the single page view with ayah detection and highlighting.
  Widget build(BuildContext context) {
    const imgW = 1920.0;
    const imgH = 3106.0;
    const double scrollThreshold = 520.0;
    const double topTextHeight = 60.0;
    const double bottomTextHeight = 30.0;

    return LayoutBuilder(builder: (context, constraints) {
      final containerW = constraints.maxWidth;
      final containerH = constraints.maxHeight;
      final availableHeight = containerH - topTextHeight - bottomTextHeight;
      final scaleWidth = containerW / imgW;
      final scaleHeight = availableHeight / imgH;
      final normalScale = min(scaleWidth, scaleHeight);
      final normalDispW = imgW * normalScale;
      final normalDispH = imgH * normalScale;
      final shouldScrollMode = normalDispH < scrollThreshold;

      if (shouldScrollMode) {
        final scrollScale = scaleWidth;
        final scrollDispH = imgH * scrollScale;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _clearSelection,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                widget.showPageTopBar
                    ? SizedBox(
                        height: topTextHeight,
                        width: containerW,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (widget.onJuzNumberTap != null) {
                                    widget.onJuzNumberTap!();
                                  }
                                },
                                child: Text(
                                  "\uFC38${juzGlyph[widget.pageNumber]}",
                                  style: TextStyle(
                                      fontSize: 22,
                                      color: widget.themeModeAdaption
                                          ? IconTheme.of(context).color
                                          : widget.textColor,
                                      fontFamily: widget.fontFamilyName),
                                ),
                              ),
                              if (widget.showSearchIcon)
                                GestureDetector(
                                  onTap: widget.onSearchTap,
                                  child: Icon(
                                    Icons.search,
                                    color: widget.searchIconColor ??
                                        (widget.themeModeAdaption
                                            ? IconTheme.of(context).color
                                            : widget.textColor),
                                    size: 26,
                                  ),
                                ),
                              GestureDetector(
                                onTap: () {
                                  if (widget.onSuraNameTap != null) {
                                    widget.onSuraNameTap!();
                                  }
                                },
                                child: Text(
                                  "${suraGlyph[widget.pageNumber]}\u005C",
                                  style: TextStyle(
                                      fontSize: 22,
                                      color: widget.themeModeAdaption
                                          ? IconTheme.of(context).color
                                          : widget.textColor,
                                      fontFamily: widget.fontFamilyName),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(),
                SizedBox(
                  width: containerW,
                  height: scrollDispH,
                  child: Stack(
                    children: [
                      Image.asset(
                        '${widget.pageImagePath}${widget.pageNumber}.png',
                        width: containerW,
                        height: scrollDispH,
                        fit: BoxFit.fill,
                        color: widget.themeModeAdaption
                            ? IconTheme.of(context).color
                            : widget.textColor,
                      ),
                      for (final s in _segments)
                        Positioned(
                          left: s.minX * scrollScale,
                          top: s.minY * scrollScale,
                          width: s.width * scrollScale,
                          height: s.height * scrollScale,
                          child: GestureDetector(
                            onLongPress: () {
                              final key = '${s.sura}_${s.ayah}';
                              setState(() {
                                _selectedAyahKey =
                                    _selectedAyahKey == key ? null : key;
                              });
                              if (widget.onAyahTap != null) {
                                widget.onAyahTap!(
                                    s.sura, s.ayah, widget.pageNumber);
                              }
                            },
                            child: Stack(
                              children: [
                                AnimatedOpacity(
                                  opacity: widget.debuggingMode
                                      ? 1.0
                                      : (_selectedAyahKey ==
                                              '${s.sura}_${s.ayah}'
                                          ? 1.0
                                          : 0.0),
                                  duration: widget.highlightDuration,
                                  curve: Curves.easeInOut,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: widget.debuggingMode
                                          ? Colors.red.withOpacity(.22)
                                          : widget.highlightColor
                                              .withOpacity(.22),
                                      border: Border.all(
                                        color: widget.debuggingMode
                                            ? Colors.red.withOpacity(.5)
                                            : (_selectedAyahKey ==
                                                    '${s.sura}_${s.ayah}'
                                                ? widget.highlightColor
                                                    .withOpacity(.5)
                                                : Colors.transparent),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(color: Colors.transparent),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                widget.showPageNumber
                    ? SizedBox(
                        height: bottomTextHeight,
                        child: Center(
                          child: Text(
                            ArabicNumbers()
                                .convert(widget.pageNumber)
                                .toString(),
                            style: TextStyle(
                                fontSize: 18,
                                color: widget.themeModeAdaption
                                    ? IconTheme.of(context).color
                                    : widget.textColor),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      )
                    : const SizedBox(),
              ],
            ),
          ),
        );
      }

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _clearSelection,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            widget.showPageTopBar
                ? SizedBox(
                    height: topTextHeight,
                    width: normalDispW,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (widget.onJuzNumberTap != null) {
                                widget.onJuzNumberTap!();
                              }
                            },
                            child: Text(
                              "\uFC38${juzGlyph[widget.pageNumber]}",
                              style: TextStyle(
                                  fontSize: 22,
                                  color: widget.themeModeAdaption
                                      ? IconTheme.of(context).color
                                      : widget.textColor,
                                  fontFamily: widget.fontFamilyName),
                            ),
                          ),
                          if (widget.showSearchIcon)
                            GestureDetector(
                              onTap: widget.onSearchTap,
                              child: Icon(
                                Icons.search,
                                color: widget.searchIconColor ??
                                    (widget.themeModeAdaption
                                        ? IconTheme.of(context).color
                                        : widget.textColor),
                                size: 26,
                              ),
                            ),
                          GestureDetector(
                            onTap: () {
                              if (widget.onSuraNameTap != null) {
                                widget.onSuraNameTap!();
                              }
                            },
                            child: Text(
                              "${suraGlyph[widget.pageNumber]}\u005C",
                              style: TextStyle(
                                  fontSize: 22,
                                  color: widget.themeModeAdaption
                                      ? IconTheme.of(context).color
                                      : widget.textColor,
                                  fontFamily: widget.fontFamilyName),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(),
            SizedBox(
              width: containerW,
              height: normalDispH,
              child: Stack(
                children: [
                  Positioned(
                    left: (containerW - normalDispW) / 2,
                    top: 0,
                    width: normalDispW,
                    height: normalDispH,
                    child: Image.asset(
                      '${widget.pageImagePath}${widget.pageNumber}.png',
                      fit: BoxFit.contain,
                      color: widget.themeModeAdaption
                          ? IconTheme.of(context).color
                          : widget.textColor,
                    ),
                  ),
                  for (final s in _segments)
                    Positioned(
                      left:
                          (containerW - normalDispW) / 2 + s.minX * normalScale,
                      top: s.minY * normalScale,
                      width: s.width * normalScale,
                      height: s.height * normalScale,
                      child: GestureDetector(
                        onLongPress: () {
                          final key = '${s.sura}_${s.ayah}';
                          setState(() {
                            _selectedAyahKey =
                                _selectedAyahKey == key ? null : key;
                          });
                          if (widget.onAyahTap != null) {
                            widget.onAyahTap!(
                                s.sura, s.ayah, widget.pageNumber);
                          }
                        },
                        child: Stack(
                          children: [
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
                                  color: widget.debuggingMode
                                      ? Colors.red.withOpacity(.22)
                                      : widget.highlightColor.withOpacity(.22),
                                  border: Border.all(
                                    color: widget.debuggingMode
                                        ? Colors.red.withOpacity(.5)
                                        : (_selectedAyahKey ==
                                                '${s.sura}_${s.ayah}'
                                            ? widget.highlightColor
                                                .withOpacity(.5)
                                            : Colors.transparent),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            Container(color: Colors.transparent),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            widget.showPageNumber
                ? SizedBox(
                    height: bottomTextHeight,
                    child: Center(
                      child: Text(
                        ArabicNumbers().convert(widget.pageNumber).toString(),
                        style: TextStyle(
                            fontSize: 18,
                            color: widget.themeModeAdaption
                                ? IconTheme.of(context).color
                                : widget.textColor),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  )
                : const SizedBox(),
          ],
        ),
      );
    });
  }
}

/// Helper class to manage dynamic loading of QFC (Quranic Font Code) fonts.
class FontManager {
  /// Set of font families that have already been loaded.
  static final Set<String> _loadedFamilies = {};

  /// Dynamically loads the custom QFC font for a specific page if it's not already loaded.
  ///
  /// This helps keep the initial app size small while providing the correct calligraphic
  /// fonts for search results.
  static Future<void> loadFont(int page) async {
    final family = 'QCF_P${page.toString().padLeft(3, '0')}';
    if (_loadedFamilies.contains(family)) return;

    try {
      final fontData = await rootBundle.load('fonts/$family.TTF');
      final loader = FontLoader(family);
      loader.addFont(Future.value(fontData));
      await loader.load();
      _loadedFamilies.add(family);
      debugPrint('Loaded font: $family');
    } catch (e) {
      debugPrint('Error loading font $family: $e');
    }
  }
}
