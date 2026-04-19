// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'package:quran_pages_with_ayah_detector/data/arabic_numbers.dart';
import 'package:quran_pages_with_ayah_detector/data/ayah_data.dart';
import 'package:quran_pages_with_ayah_detector/data/image_surah_glyph.dart';
import 'package:quran_pages_with_ayah_detector/data/juz_glyph.dart';
import 'package:quran_pages_with_ayah_detector/data/sura_glyph.dart';
import 'package:quran_pages_with_ayah_detector/data/quran_clean_plain.dart';
import 'package:quran_pages_with_ayah_detector/data/sura_ayah_to_page.dart';
import 'package:quran_pages_with_ayah_detector/data/quran_text_data.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_pages_with_ayah_detector/data/surah_number_of_ayahs.dart';
import 'package:quran_pages_with_ayah_detector/data/is_madani.dart';
import 'package:quran_pages_with_ayah_detector/data/hizb_quarters_data.dart';
import 'package:quran_pages_with_ayah_detector/data/quran_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirMuyassarData.dart'
    as muyassar;
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirAlBaghawiData.dart'
    as baghawi;
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirAlQurtubiData.dart'
    as qurtubi;
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirAlSaddiData.dart'
    as saddi;
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirAlTabariData.dart'
    as tabari;
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirAlWasitData.dart'
    as wasit;
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirIbnKathirData.dart'
    as ibn_kathir;
import 'package:quran_pages_with_ayah_detector/data/tafsir/surahAyahTafsirTanwirAlMiqbasData.dart'
    as tanwir;

/// Represents a custom action option for the ayah long-press menu.
class AyahActionOption {
  /// The title/label of the action.
  final String title;

  /// The icon to display for this action.
  final IconData icon;

  /// Callback function when this action is tapped.
  /// Provides surah number, ayah number, and page number.
  final void Function(int surah, int ayah, int pageNumber) onPress;

  /// Creates an [AyahActionOption] with the specified properties.
  const AyahActionOption({
    required this.title,
    required this.icon,
    required this.onPress,
  });
}

/// Defines the visual style of the page number container.
enum PageNumberDesign {
  /// No container, just text.
  none,

  /// Simple rounded rectangle with light background.
  classic,

  /// Pill-shaped container.
  pill,

  /// Container with a border but no background (Now the default).
  outlined,

  /// Glassmorphism effect.
  glass,
}

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

/// A controller for [QuranPageView] to programmatically control its behavior.
class QuranPageController {
  _QuranPageViewState? _state;

  /// Attaches the state to this controller. Internal use only.
  void _attach(_QuranPageViewState state) {
    _state = state;
  }

  /// Detaches the state from this controller. Internal use only.
  void _detach() {
    _state = null;
  }

  /// Opens the search overlay.
  void showSearch() {
    _state?._showSearch();
  }

  /// Closes the search overlay.
  void closeSearch() {
    _state?._closeSearch();
  }

  /// Returns the current page index (1-604).
  int get currentPage => _state?._currentPage ?? 0;

  /// Navigates to a specific page (1-604).
  void jumpToPage(int page) {
    _state?._jumpToPage(page);
  }

  /// Animates to a specific page (1-604).
  Future<void> animateToPage(int page,
      {required Duration duration, required Curve curve}) async {
    await _state?._animateToPage(page, duration: duration, curve: curve);
  }

  /// Opens the Juz/Surah selection sheet.
  void showSelectionSheet({int? initialSurah, int? initialJuz}) {
    _state?._showSelectionSheet(
        initialSurah: initialSurah, initialJuz: initialJuz);
  }
}

/// A widget that displays Quran pages and allows for ayah detection and interaction.
class QuranPageView extends StatefulWidget {
  /// A controller to programmatically control the [QuranPageView].
  final QuranPageController? controller;

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

  /// The text color used for Quran page background image itself when [themeModeAdaption] is off.
  final Color quranTextColor;

  /// The color for the text in the top bar (Juz and Surah names).
  final Color topBarTextColor;

  /// Callback function triggered when an ayah is tapped.
  /// Provides the surah number, ayah number, and the current page number.
  final void Function(int sura, int ayah, int pageNumber)? onAyahTap;

  /// Callback function triggered when the Surah name in the top bar is tapped.
  final void Function()? onSuraNameTap;

  /// Callback function triggered when the Juz number in the top bar is tapped.
  final void Function()? onJuzNumberTap;

  /// Whether to reverse the page view.
  final bool isReversed;

  /// The color used to highlight the selected or tapped ayah.
  final Color highlightColor;

  /// The duration of the highlight animation.
  final Duration highlightDuration;

  /// Whether to show a search icon in the top bar.
  final bool showSearchIcon;

  /// Custom color for the search icon in the top bar.
  final Color searchIconColor;

  /// Background color for the search overlay sheet.
  final Color searchSheetBackgroundColor;

  /// Color for the "X" and "Lens" icons in the search sheet.
  final Color searchSheetIconsColor;

  /// Text color for the verse text in search results.
  final Color searchResultTextColor;

  /// Color for supplementary info in search results (Surah name, page number).
  final Color searchResultInfoColor;

  /// Hint text displayed in the search input field.
  final String searchHintText;

  /// Color for the hint text inside the search field.
  final Color searchFieldHintTextColor;

  /// Color for the user input text in the search field.
  final Color searchFieldTextColor;

  /// Color for the selection highlight, cursor, and selection handles in the search field.
  final Color searchFieldHandleColor;

  /// Background color for the search input field.
  final Color searchFieldBackgroundColor;

  /// The height multiplier for the search result sheet when expanded (0.0 to 1.0).
  final double searchSheetHeightMultiplier;

  /// The color for the grouping titles in search results (e.g., "Number of Surahs").
  final Color searchResultGroupTitleColor;

  /// The text color of the page number at the bottom.
  final Color pageNumberColor;

  /// The design style for the page number container.
  final PageNumberDesign pageNumberDesign;

  /// The background color for the page number container.
  final Color? pageNumberBackgroundColor;

  /// The border color for the page number container.
  final Color? pageNumberBorderColor;

  /// Background color for the search overlay sheet in dark mode.
  final Color searchSheetDarkBackgroundColor;

  /// Background color for the search input field in dark mode.
  final Color searchFieldDarkBackgroundColor;

  /// Background color for the selection sheet.
  final Color selectionSheetBackgroundColor;

  /// Background color for the selection sheet in dark mode.
  final Color selectionSheetDarkBackgroundColor;

  /// Text color for items in the selection sheet.
  final Color selectionResultTextColor;

  /// Color for supplementary info in the selection sheet.
  final Color selectionResultInfoColor;

  /// Color for grouping titles in the selection sheet.
  final Color selectionResultGroupTitleColor;

  /// Background color for the search field in the selection sheet.
  final Color selectionSearchFieldBackgroundColor;

  /// Background color for the search field in the selection sheet in dark mode.
  final Color selectionSearchFieldDarkBackgroundColor;

  /// Hint text for the search field in the selection sheet.
  final String selectionSearchHintText;

  /// The color used to highlight the current Surah or Juz in the selection sheet.
  final Color selectionSheetHighlightColor;

  /// The highlight color for the selection sheet in dark mode.
  final Color selectionSheetDarkHighlightColor;

  /// The text color for the page number scrubbing overlay.
  /// If null, defaults to white.
  final Color? pageNumberScrubbingTextColor;

  /// The background color for the page number scrubbing overlay.

  /// The background color for the page number scrubbing overlay.
  /// If null, defaults to [pageNumberBackgroundColor] or black.
  final Color? pageNumberScrubbingBackgroundColor;

  /// Custom width for the popup.
  final double? popupWidth;

  /// Custom height for the popup.
  final double? popupHeight;

  /// Background color for the ayah action menu card.
  final Color ayahMenuBackgroundColor;

  /// Background color for the ayah action menu card in dark mode.
  final Color ayahMenuDarkBackgroundColor;

  /// Text color for ayah menu items.
  final Color ayahMenuTextColor;

  /// Icon color for ayah menu items.
  final Color ayahMenuIconColor;

  /// Divider color in the ayah menu.
  final Color ayahMenuDividerColor;

  /// List of custom action options to add to the ayah menu.
  /// These will be displayed alongside the default "Copy" and "Save Image" options.
  final List<AyahActionOption> customAyahActions;

  /// Whether to show the default ayah menu options (Copy, Save Image).
  final bool showDefaultAyahMenu;

  /// The font family used for the normal text inside the whole app.
  final String? nonQuranFont;

  /// The initial page number to display (1-604).
  final int initialPage;

  // ── Tafsir sheet colors ──────────────────────────────────────────────────

  /// Background color for the tafsir bottom sheet.
  final Color tafsirSheetBackgroundColor;

  /// Background color for the tafsir bottom sheet in dark mode.
  final Color tafsirSheetDarkBackgroundColor;

  /// Text color for tafsir body text.
  final Color tafsirTextColor;

  /// Text color for tafsir body text in dark mode.
  final Color tafsirDarkTextColor;

  /// Color for the selected ayah text shown at the top of the tafsir sheet.
  final Color tafsirAyahTextColor;

  /// Accent color for the selected tafsir tab indicator and label.
  final Color tafsirTabSelectedColor;

  /// Color for unselected tafsir tab labels.
  final Color tafsirTabUnselectedColor;

  /// Color for the overlay / scrim behind the tafsir sheet.
  final Color tafsirOverlayColor;

  /// Callback function that is invoked when the user scrolls to a new page.
  ///
  /// The [pageNumber] parameter represents the 1-based index of the page that
  /// the user has scrolled to.
  ///
  /// This callback is useful for synchronizing other UI elements (such as a
  /// bottom navigation bar or a page indicator) with the current page.
  final void Function(int pageNumber)? onPageChanged;

  /// Creates a [QuranPageView] with customizable behavior and styling.
  const QuranPageView({
    super.key,
    this.onAyahTap,
    this.onSuraNameTap,
    this.onJuzNumberTap,
    this.isReversed = true,
    this.pageImagePath = "assets/pages/",
    this.fontFamilyName = "suraNameFont",
    this.debuggingMode = false,
    this.themeModeAdaption = false,
    this.showPageTopBar = true,
    this.showPageNumber = true,
    this.quranTextColor = Colors.black,
    this.topBarTextColor = Colors.black,
    this.highlightColor = Colors.blue,
    this.highlightDuration = const Duration(milliseconds: 220),
    this.showSearchIcon = true,
    this.searchIconColor = Colors.black,
    this.searchSheetBackgroundColor = Colors.white,
    this.searchSheetDarkBackgroundColor = const Color(0xFF1E1E1E),
    this.searchSheetIconsColor = Colors.black,
    this.searchResultTextColor = Colors.black,
    this.searchResultInfoColor = Colors.blue,
    this.searchHintText = "البحث في القرآن...",
    this.searchFieldHintTextColor = Colors.black54,
    this.searchFieldTextColor = Colors.black,
    this.searchFieldHandleColor = Colors.black,
    this.searchFieldBackgroundColor = const Color(0xFFF5F5F5),
    this.searchFieldDarkBackgroundColor = const Color(0xFF2C2C2C),
    this.searchSheetHeightMultiplier = 0.6,
    this.pageNumberColor = Colors.black,
    this.searchResultGroupTitleColor = Colors.black87,
    this.selectionSheetBackgroundColor = Colors.white,
    this.selectionSheetDarkBackgroundColor = const Color(0xFF1E1E1E),
    this.selectionResultTextColor = Colors.black,
    this.selectionResultInfoColor = Colors.blue,
    this.selectionResultGroupTitleColor = Colors.black87,
    this.selectionSearchFieldBackgroundColor = const Color(0xFFF5F5F5),
    this.selectionSearchFieldDarkBackgroundColor = const Color(0xFF2C2C2C),
    this.selectionSearchHintText = "ابحث عن سورة...",
    this.selectionSheetHighlightColor = const Color(0xFFE3F2FD),
    this.selectionSheetDarkHighlightColor = const Color(0xFF1E88E5),
    this.pageNumberDesign = PageNumberDesign.outlined,
    this.pageNumberBackgroundColor,
    this.pageNumberScrubbingBackgroundColor,
    this.pageNumberScrubbingTextColor,
    this.pageNumberBorderColor,
    this.popupWidth,
    this.popupHeight,
    this.ayahMenuBackgroundColor = Colors.white,
    this.ayahMenuDarkBackgroundColor = const Color(0xFF1E1E1E),
    this.ayahMenuTextColor = Colors.black,
    this.ayahMenuIconColor = Colors.blue,
    this.ayahMenuDividerColor = const Color(0xFFE0E0E0),
    this.customAyahActions = const [],
    this.showDefaultAyahMenu = true,
    this.nonQuranFont = "nonQuranFont",
    this.onPageChanged,
    this.controller,
    this.initialPage = 0,
    this.tafsirSheetBackgroundColor = Colors.white,
    this.tafsirSheetDarkBackgroundColor = const Color(0xFF1E1E1E),
    this.tafsirTextColor = Colors.black87,
    this.tafsirDarkTextColor = Colors.white70,
    this.tafsirAyahTextColor = Colors.black,
    this.tafsirTabSelectedColor = Colors.blue,
    this.tafsirTabUnselectedColor = Colors.grey,
    this.tafsirOverlayColor = const Color(0x80000000),
  });

  @override

  /// Creates the state for this [QuranPageView].
  State<QuranPageView> createState() => _QuranPageViewState();
}

/// State class for [QuranPageView] that manages page navigation and search state.
class _QuranPageViewState extends State<QuranPageView>
    with SingleTickerProviderStateMixin {
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

  /// A map that caches which surahs start on each page.
  final Map<int, List<int>> _surasStartingOnPage = {};

  /// A map that caches which quarters of a hizb start on each page.
  final Map<int, List<int>> _pageToQuarters = {};

  int get _currentPage {
    if (_pageController.hasClients) {
      return _pageController.page!.round();
    }
    return widget.initialPage;
  }

  late AnimationController _scrubController;
  late Animation<double> _scrubScaleAnimation;
  late Animation<double> _scrubOpacityAnimation;

  @override

  /// Initializes the page controller and builds the search location map.
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    widget.controller?._attach(this);
    _buildPageAyahMap();
    _buildSurasStartingOnPageMap();
    _initQuartersMap();

    // Scrubbing animation controller
    _scrubController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scrubScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scrubController, curve: Curves.easeOutBack),
    );
    _scrubOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scrubController, curve: Curves.easeIn),
    );
  }

  void _initQuartersMap() {
    _pageToQuarters.clear();
    for (int q = 1; q < hizbQuartersData.length; q++) {
      final start = hizbQuartersData[q];
      final s = start[0];
      final a = start[1];
      final p = suraAyahToPage[s]?[a] ?? 0;
      if (p != 0) {
        _pageToQuarters.putIfAbsent(p, () => []).add(q);
      }
    }
  }

  @override
  void didUpdateWidget(QuranPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override

  /// Disposes resources used by the search and page navigation.
  void dispose() {
    _scrubController.dispose();
    widget.controller?._detach();
    _pageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Builds the internal [_pageAyahMap] from [ayahRows].
  /// This ensures the mapping matches the actual visual layout of ayahs on each page.
  void _buildPageAyahMap() {
    // Use ayahRows as the source of truth for which ayahs are on which page
    for (final row in ayahRows) {
      final page = row['page_number'];
      final surah = row['sura_number'];
      final ayah = row['ayah_number'];

      if (page is! int || surah is! int || ayah is! int) continue;

      final ayahList = _pageAyahMap.putIfAbsent(page, () => []);

      // Check if this ayah is already in the list (avoid duplicates)
      final exists =
          ayahList.any((e) => e['surah'] == surah && e['ayah'] == ayah);
      if (!exists) {
        ayahList.add({
          'surah': surah,
          'ayah': ayah,
        });
      }
    }

    // Sort ayahs on each page by surah number, then ayah number
    _pageAyahMap.forEach((page, ayahs) {
      ayahs.sort((a, b) {
        if (a['surah'] != b['surah']) return a['surah']!.compareTo(b['surah']!);
        return a['ayah']!.compareTo(b['ayah']!);
      });
    });
  }

  /// Builds the internal [_surasStartingOnPage] map.
  void _buildSurasStartingOnPageMap() {
    for (int s = 1; s <= 114; s++) {
      final p = suraAyahToPage[s]?[1] ?? 1;
      _surasStartingOnPage.putIfAbsent(p, () => []).add(s);
    }
    _surasStartingOnPage.forEach((page, suras) {
      suras.sort();
    });
  }

  /// Retrieves the first page of a given Juz.
  int _getJuzStartPage(int juzNumber) {
    // Juz glyphs: 1-23 use 0xFC39-0xFC4F, 24-30 use 0xFC30-0xFC36
    final int targetCode =
        juzNumber <= 23 ? 0xFC38 + juzNumber : 0xFC30 + (juzNumber - 24);

    for (int p = 1; p <= 604; p++) {
      final glyph = juzGlyph[p];
      if (glyph != null && glyph.codeUnitAt(0) == targetCode) {
        return p;
      }
    }
    return 1;
  }

  /// Gets the current Juz number for a given page.
  int _getCurrentJuzForPage(int page) {
    for (int j = 1; j <= 30; j++) {
      int start = _getJuzStartPage(j);
      int nextStart = (j < 30) ? _getJuzStartPage(j + 1) : 605;
      if (page >= start && page < nextStart) return j;
    }
    return 1;
  }

  /// Gets the current Surah number for a given page.
  int _getCurrentSurahForPage(int page) {
    // Check suras starting on this page
    final starts = _surasStartingOnPage[page];
    if (starts != null && starts.isNotEmpty) return starts[0];

    // Otherwise find the surah that includes this page
    for (int s = 1; s <= 114; s++) {
      final startP = suraAyahToPage[s]?[1] ?? 1;
      final lastAyah = quran.getVerseCount(s);
      final endP = suraAyahToPage[s]?[lastAyah] ?? startP;
      if (page >= startP && page <= endP) return s;
    }
    return 1;
  }

  /// Builds a centered title for grouping search results (e.g., "Number of Surahs").
  Widget _buildGroupTitle(String title, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: widget.nonQuranFont,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  /// Returns the stylized glyph for a given surah number.
  /// Handles cases where multiple surahs share a page by applying an offset
  /// to the page's base glyph.
  String _getSurahGlyph(int suraNumber) {
    final int page = suraAyahToPage[suraNumber]?[1] ?? 1;
    final String baseGlyph = suraGlyph[page] ?? "";
    if (baseGlyph.isEmpty) return "";

    // Find the first surah that STARTS on this page
    final int firstSuraStartingOnPage =
        _surasStartingOnPage[page]?[0] ?? suraNumber;

    // The glyphs are sequential by surah number
    final int offset = suraNumber - firstSuraStartingOnPage;
    return String.fromCharCode(baseGlyph.codeUnitAt(0) + offset);
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

  /// Executes the search logic against [quranCleanPlain] and Surah names.
  void _performSearch(String query) {
    // 1. Search for Surah names
    final List<Map<String, dynamic>> suraResults = [];
    for (int i = 1; i <= 114; i++) {
      final suraName = quran.getSurahNameArabic(i);
      if (suraName.contains(query)) {
        suraResults.add({
          'type': 'surah',
          'surah_number': i,
          'surah_name': suraName,
        });
      }
    }

    // 2. Search for verses
    final verseResults = quranCleanPlain
        .where((verse) {
          final content = verse['content'] as String;
          return content.contains(query);
        })
        .map((v) => {...v, 'type': 'verse'})
        .toList();

    setState(() {
      _searchResults = [...suraResults, ...verseResults];
    });
  }

  /// Retrieves the QFC-encoded verse text for a given surah, ayah, and page.
  String _getQfcVerse(int surah, int ayah, int page) {
    final pageAyahs = _pageAyahMap[page];
    if (pageAyahs == null || pageAyahs.isEmpty) return '';

    if (page < 1 || page > quranTextData.length) return '';
    final pageTexts = quranTextData[page - 1];
    if (pageTexts.isEmpty) return '';

    // Find the index of this specific ayah on the page
    final indexOnPage = pageAyahs.indexWhere(
      (e) => e['surah'] == surah && e['ayah'] == ayah,
    );

    if (indexOnPage == -1) return '';
    if (indexOnPage >= pageTexts.length) return '';

    return pageTexts[indexOnPage];
  }

  /// Handles tapping a search result by navigating to the page and highlighting the verse.
  void _handleSearchResultTap(int page, int surah, int ayah) {
    if (mounted) {
      setState(() {
        _isSearchOpen = false;
        _searchResults = [];
        _highlightedAyahKey = '${surah}_$ayah';
        _highlightedPage = page;
      });
    }
    _pageController.jumpToPage(page - 1);
  }

  // Internal methods exposed to the controller
  void _showSearch() {
    if (mounted) {
      setState(() {
        _isSearchOpen = true;
        _searchResults = [];
      });
    }
  }

  void _closeSearch() {
    if (mounted) {
      setState(() {
        _isSearchOpen = false;
        _searchResults = [];
      });
    }
  }

  void _jumpToPage(int page) {
    _pageController.jumpToPage(page - 1);
  }

  Future<void> _animateToPage(int page,
      {required Duration duration, required Curve curve}) async {
    await _pageController.animateToPage(page - 1,
        duration: duration, curve: curve);
  }

  void _showSelectionSheet({int? initialSurah, int? initialJuz}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color effectiveSheetBg = widget.themeModeAdaption
        ? (isDark
            ? widget.selectionSheetDarkBackgroundColor
            : widget.selectionSheetBackgroundColor)
        : widget.selectionSheetBackgroundColor;
    final Color effectiveHighlightColor = widget.themeModeAdaption
        ? (isDark
            ? widget.selectionSheetDarkHighlightColor
            : widget.selectionSheetHighlightColor)
        : widget.selectionSheetHighlightColor;
    final Color effectiveResultTextColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.selectionResultTextColor;
    final Color effectiveResultInfoColor = widget.themeModeAdaption
        ? (isDark ? Colors.white70 : Colors.blue)
        : widget.selectionResultInfoColor;
    final Color effectiveGroupTitleColor = widget.themeModeAdaption
        ? (isDark ? Colors.white70 : Colors.black87)
        : widget.selectionResultGroupTitleColor;
    final Color effectiveIconsColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.searchSheetIconsColor;
    final Color effectiveFieldHintColor = widget.themeModeAdaption
        ? (isDark
            ? Colors.white.withOpacity(0.5)
            : Colors.black.withOpacity(0.5))
        : widget.searchFieldHintTextColor;
    final Color effectiveFieldTextColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.searchFieldTextColor;
    final Color effectiveFieldBg = widget.themeModeAdaption
        ? (isDark
            ? widget.searchFieldDarkBackgroundColor
            : widget.searchFieldBackgroundColor)
        : widget.searchFieldBackgroundColor;
    final Color effectiveHandleColor = widget.searchFieldHandleColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String sheetSearchQuery = "";
        final scrollState = {'hasScrolled': false};

        // Define key maps
        final Map<int, GlobalKey> juzKeys = {
          for (int i = 1; i <= 30; i++) i: GlobalKey()
        };
        final Map<int, GlobalKey> surahKeys = {
          for (int i = 1; i <= 114; i++) i: GlobalKey()
        };

        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Trigger scroll once after frame
            if (!scrollState['hasScrolled']!) {
              scrollState['hasScrolled'] = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Determine target context
                BuildContext? targetCtx;

                if (initialSurah != null) {
                  targetCtx = surahKeys[initialSurah]?.currentContext;
                } else if (initialJuz != null) {
                  targetCtx = juzKeys[initialJuz]?.currentContext;
                }

                if (targetCtx != null) {
                  Scrollable.ensureVisible(targetCtx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment:
                          0.1); // Small top alignment padding as requested
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: effectiveSheetBg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: TextSelectionThemeData(
                              cursorColor: effectiveHandleColor,
                              selectionColor:
                                  effectiveHandleColor.withOpacity(0.3),
                              selectionHandleColor: effectiveHandleColor,
                            ),
                          ),
                          child: TextField(
                            onChanged: (val) {
                              setSheetState(() {
                                sheetSearchQuery = val.trim();
                              });
                            },
                            textDirection: TextDirection.rtl,
                            style: TextStyle(color: effectiveFieldTextColor),
                            decoration: InputDecoration(
                              hintText: widget.selectionSearchHintText,
                              hintTextDirection: TextDirection.rtl,
                              hintStyle: TextStyle(
                                  color:
                                      effectiveFieldHintColor.withOpacity(0.4),
                                  fontFamily: widget.nonQuranFont),
                              prefixIcon: Icon(Icons.search,
                                  color: effectiveIconsColor.withOpacity(0.5)),
                              filled: true,
                              fillColor: effectiveFieldBg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int juzIndex = 0; juzIndex < 30; juzIndex++)
                                Builder(
                                  builder: (context) {
                                    final juzNum = juzIndex + 1;
                                    final juzStartPage =
                                        _getJuzStartPage(juzNum);

                                    // Key for the Juz header
                                    final juzKey = juzKeys[juzNum];

                                    // Get all surahs in this juz according to quran package
                                    final juzData =
                                        quran.getSurahAndVersesFromJuz(juzNum);
                                    final juzSuras = juzData.keys.toList();

                                    // Filter: Only show surah if its START juz is this juz
                                    final filteredSuras = juzSuras.where((s) {
                                      final startJuz = quran.getJuzNumber(s, 1);
                                      if (startJuz != juzNum) return false;

                                      if (sheetSearchQuery.isNotEmpty) {
                                        final name =
                                            quran.getSurahNameArabic(s);
                                        return name.contains(sheetSearchQuery);
                                      }
                                      return true;
                                    }).toList();

                                    if (sheetSearchQuery.isNotEmpty &&
                                        filteredSuras.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        GestureDetector(
                                          key: juzKey,
                                          onTap: () {
                                            Navigator.pop(context);
                                            _jumpToPage(juzStartPage);
                                          },
                                          child: Container(
                                            margin:
                                                const EdgeInsets.only(top: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white
                                                      .withOpacity(0.05)
                                                  : Colors.black
                                                      .withOpacity(0.03),
                                              border: Border(
                                                bottom: BorderSide(
                                                    color: Colors.grey
                                                        .withOpacity(0.1)),
                                                top: BorderSide(
                                                    color: Colors.grey
                                                        .withOpacity(0.1)),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              textDirection: TextDirection.rtl,
                                              children: [
                                                Text(
                                                  "\uFC38${String.fromCharCode(juzNum <= 23 ? 0xFC38 + juzNum : 0xFC30 + (juzNum - 24))}",
                                                  style: TextStyle(
                                                    fontFamily:
                                                        widget.fontFamilyName,
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        effectiveGroupTitleColor,
                                                  ),
                                                ),
                                                // Page number removed for Juz row as requested
                                              ],
                                            ),
                                          ),
                                        ),
                                        for (int s in filteredSuras) ...[
                                          () {
                                            final suraKey = surahKeys[s];
                                            final isHighlighted = s ==
                                                    initialSurah ||
                                                (initialJuz == juzNum &&
                                                    initialSurah == null &&
                                                    s == filteredSuras.first);

                                            return InkWell(
                                              key: suraKey,
                                              onTap: () {
                                                Navigator.pop(context);
                                                final p =
                                                    suraAyahToPage[s]?[1] ?? 1;
                                                // Highlight the first ayah of the selected Surah
                                                if (mounted) {
                                                  setState(() {
                                                    _highlightedAyahKey =
                                                        '${s}_1';
                                                    _highlightedPage = p;
                                                  });
                                                }
                                                _jumpToPage(p);
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 32,
                                                        vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: isHighlighted
                                                      ? effectiveHighlightColor
                                                          .withValues(
                                                              alpha: 0.16)
                                                      : Colors.transparent,
                                                  border: Border(
                                                      bottom: BorderSide(
                                                          color: Colors.grey
                                                              .withOpacity(
                                                                  0.05))),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  textDirection:
                                                      TextDirection.rtl,
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        final ayahsCount =
                                                            suraNumberOfAyahs[
                                                                    s] ??
                                                                0;
                                                        final madani =
                                                            isMadani[s] ??
                                                                false;
                                                        final typeStr = madani
                                                            ? "مَدَنِيَّة"
                                                            : "مَكِّيَّة";
                                                        final detailStr =
                                                            "رقمها ${ArabicNumbers().convert(s)} - آياتها ${ArabicNumbers().convert(ayahsCount)} - $typeStr";
                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "${_getSurahGlyph(s)}\u005C",
                                                              style: TextStyle(
                                                                fontFamily: widget
                                                                    .fontFamilyName,
                                                                fontSize: 22,
                                                                color:
                                                                    effectiveResultTextColor,
                                                              ),
                                                              textDirection:
                                                                  TextDirection
                                                                      .ltr,
                                                            ),
                                                            Text(
                                                              detailStr,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: effectiveResultTextColor
                                                                    .withOpacity(
                                                                        0.6),
                                                                fontFamily: widget
                                                                    .nonQuranFont,
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                    Text(
                                                      'صفحة  ${ArabicNumbers().convert(suraAyahToPage[s]?[1] ?? 1)}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            effectiveResultInfoColor,
                                                        fontFamily:
                                                            widget.nonQuranFont,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }(),
                                        ],
                                      ],
                                    );
                                  },
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
          },
        );
      },
    );
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
            reverse: widget.isReversed ? true : false,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (c, i) {
              final page = i + 1;
              return _QuranPage(
                pageNumber: page,
                onAyahTap: (s, a, p) {
                  if (widget.onAyahTap != null) widget.onAyahTap!(s, a, p);
                  if (mounted) {
                    setState(() {
                      _highlightedAyahKey = null;
                      _highlightedPage = null;
                    });
                  }
                },
                onSuraNameTap: widget.onSuraNameTap ??
                    () => _showSelectionSheet(
                        initialSurah: _getCurrentSurahForPage(page)),
                onJuzNumberTap: widget.onJuzNumberTap ??
                    () => _showSelectionSheet(
                        initialJuz: _getCurrentJuzForPage(page)),
                onSearchTap: () => _showSearch(),
                pageImagePath: widget.pageImagePath,
                fontFamilyName: widget.fontFamilyName,
                debuggingMode: widget.debuggingMode,
                themeModeAdaption: widget.themeModeAdaption,
                showPageTopBar: widget.showPageTopBar,
                showPageNumber: widget.showPageNumber,
                quranTextColor: widget.quranTextColor,
                topBarTextColor: widget.topBarTextColor,
                pageNumberColor: widget.pageNumberColor,
                pageNumberDesign: widget.pageNumberDesign,
                pageNumberBackgroundColor: widget.pageNumberBackgroundColor,
                pageNumberBorderColor: widget.pageNumberBorderColor,
                searchResultGroupTitleColor: widget.searchResultGroupTitleColor,
                highlightColor: widget.highlightColor,
                highlightDuration: widget.highlightDuration,
                showSearchIcon: widget.showSearchIcon,
                searchIconColor: widget.searchIconColor,
                highlightedAyahKey:
                    _highlightedPage == page ? _highlightedAyahKey : null,
                onClearSelection: () {
                  if (mounted) {
                    setState(() {
                      _highlightedAyahKey = null;
                      _highlightedPage = null;
                    });
                  }
                },
                quarters: _pageToQuarters[page] ?? [],
                ayahMenuBackgroundColor: widget.ayahMenuBackgroundColor,
                ayahMenuDarkBackgroundColor: widget.ayahMenuDarkBackgroundColor,
                ayahMenuTextColor: widget.ayahMenuTextColor,
                ayahMenuIconColor: widget.ayahMenuIconColor,
                ayahMenuDividerColor: widget.ayahMenuDividerColor,
                customAyahActions: widget.customAyahActions,
                showDefaultAyahMenu: widget.showDefaultAyahMenu,
                nonQuranFont: widget.nonQuranFont,
                tafsirSheetBackgroundColor: widget.tafsirSheetBackgroundColor,
                tafsirSheetDarkBackgroundColor:
                    widget.tafsirSheetDarkBackgroundColor,
                tafsirTextColor: widget.tafsirTextColor,
                tafsirDarkTextColor: widget.tafsirDarkTextColor,
                tafsirAyahTextColor: widget.tafsirAyahTextColor,
                tafsirTabSelectedColor: widget.tafsirTabSelectedColor,
                tafsirTabUnselectedColor: widget.tafsirTabUnselectedColor,
                tafsirOverlayColor: widget.tafsirOverlayColor,
              );
            },
          ),
        ),
        // Scrubbing Touch Area & Static Page Number Container
        // Scrubbing Touch Area
        if (widget.showPageNumber)
          Positioned(
            left: 0,
            right: 0,
            bottom: 25,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: _handleScrubStart,
              onLongPressMoveUpdate: _handleScrubUpdate,
              onLongPressEnd: _handleScrubEnd,
              child: Container(
                height: 60, // Touch target height
                alignment: Alignment.center,
                // Page Number Popup (Animated)
                child: AnimatedBuilder(
                  animation: _scrubController,
                  builder: (context, child) {
                    if (_scrubController.value == 0) {
                      return const SizedBox.shrink();
                    }

                    return Transform.scale(
                      scale: _scrubScaleAnimation.value,
                      child: Opacity(
                        opacity: _scrubOpacityAnimation.value,
                        child: Material(
                          elevation: 6.0,
                          borderRadius: BorderRadius.circular(25),
                          color: widget.pageNumberScrubbingBackgroundColor ??
                              (widget.themeModeAdaption &&
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                  ? Colors.blue.withOpacity(0.9)
                                  : (widget.pageNumberScrubbingBackgroundColor ??
                                          widget.pageNumberBackgroundColor ??
                                          Colors.black)
                                      .withOpacity(0.9)),
                          child: SizedBox(
                            width: widget.popupWidth ?? 80,
                            height: widget.popupHeight ?? 40,
                            child: Center(
                              child: Text(
                                // Use 1-based index (0-based + 1)
                                ArabicNumbers().convert(
                                    (_scrubPage.round() + 1).clamp(1, 604)),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: widget.pageNumberScrubbingTextColor ??
                                      Colors.white,
                                  fontFamily: widget.nonQuranFont,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        if (_isSearchOpen) _buildSearchOverlay(),
      ],
    );
  }

  // --- Scrubbing Logic --
  // 0-based index for logic, 0 to 603
  double _scrubPage = 0.0;
  double _startScrubPage = 0.0; // To store initial page at scrub start

  void _handleScrubStart(LongPressStartDetails details) {
    setState(() {
      // Capture current page (0-based)
      _startScrubPage = _pageController.page ?? 0.0;
      _scrubPage = _startScrubPage;
    });
    _scrubController.forward();
    HapticFeedback.selectionClick();
  }

  void _handleScrubUpdate(LongPressMoveUpdateDetails details) {
    // Reverse logic: PageView(reverse: true) means swipe left (-dx) goes to NEXT page (Index++)
    // So -dx adds to index.

    // Sensitivity: 150px drag = 10 pages? ~0.06 pages/px
    // YouTube style is quite sensitive. Let's try 0.1
    const double sensitivity = 0.1;

    // Note: details.localOffsetFromOrigin is the cumulated offset from start
    double delta = details.localOffsetFromOrigin.dx;

    // If delta is negative (left swipe), we increase page index
    double newPage = _startScrubPage - (delta * sensitivity);

    // Clamp 0 to 603 (Page count is 604)
    newPage = newPage.clamp(0.0, 603.0);

    setState(() {
      if (newPage.round() != _scrubPage.round()) {
        HapticFeedback.selectionClick();
      }
      _scrubPage = newPage;
    });
  }

  void _handleScrubEnd(LongPressEndDetails details) {
    _scrubController.reverse();

    if (!_pageController.hasClients) return;

    final int targetIndex = _scrubPage.round().clamp(0, 603);
    final int currentIndex = _pageController.page?.round() ?? 0;

    // Only animate if changed
    if (targetIndex != currentIndex) {
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Builds the search overlay sheet when [_isSearchOpen] is true.
  Widget _buildSearchOverlay() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double sheetHeight = _searchResults.isEmpty
        ? 150
        : (screenHeight * widget.searchSheetHeightMultiplier)
            .clamp(150, screenHeight * 0.9);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color effectiveSheetBg = widget.themeModeAdaption
        ? (isDark
            ? widget.searchSheetDarkBackgroundColor
            : widget.searchSheetBackgroundColor)
        : widget.searchSheetBackgroundColor;
    final Color effectiveIconsColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.searchSheetIconsColor;
    final Color effectiveResultTextColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.searchResultTextColor;
    final Color effectiveResultInfoColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.searchResultInfoColor;
    final Color effectiveFieldHintColor = widget.themeModeAdaption
        ? (isDark
            ? Colors.white.withOpacity(0.5)
            : Colors.black.withOpacity(0.5))
        : widget.searchFieldHintTextColor;
    final Color effectiveFieldTextColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.searchFieldTextColor;
    final Color effectiveFieldBg = widget.themeModeAdaption
        ? (isDark
            ? widget.searchFieldDarkBackgroundColor
            : widget.searchFieldBackgroundColor)
        : widget.searchFieldBackgroundColor;
    final Color effectiveGroupTitleColor = widget.themeModeAdaption
        ? (isDark ? Colors.white70 : Colors.black87)
        : widget.searchResultGroupTitleColor;
    final Color effectiveHandleColor = widget.searchFieldHandleColor;

    final suraCount = _searchResults.where((r) => r['type'] == 'surah').length;
    final verseCount = _searchResults.where((r) => r['type'] == 'verse').length;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _closeSearch(),
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
                color: effectiveSheetBg,
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
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textSelectionTheme: TextSelectionThemeData(
                          cursorColor: effectiveHandleColor,
                          selectionColor: effectiveHandleColor.withOpacity(0.3),
                          selectionHandleColor: effectiveHandleColor,
                        ),
                      ),
                      child: TextField(
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: effectiveFieldTextColor),
                        decoration: InputDecoration(
                          hintText: widget.searchHintText,
                          hintTextDirection: TextDirection.rtl,
                          hintStyle: TextStyle(
                              color: effectiveFieldHintColor.withOpacity(0.4),
                              fontFamily: widget.nonQuranFont),
                          prefixIcon:
                              Icon(Icons.search, color: effectiveIconsColor),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close, color: effectiveIconsColor),
                            onPressed: () => _closeSearch(),
                          ),
                          filled: true,
                          fillColor: effectiveFieldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: sheetHeight - 80),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _searchResults.length +
                            (suraCount > 0 ? 1 : 0) +
                            (verseCount > 0 ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Logic to decide if we show a header or a result
                          if (suraCount > 0 && index == 0) {
                            return _buildGroupTitle(
                                "عدد نتائج السور: ${ArabicNumbers().convert(suraCount)}",
                                effectiveGroupTitleColor);
                          }

                          if (suraCount > 0 &&
                              verseCount > 0 &&
                              index == suraCount + 1) {
                            return _buildGroupTitle(
                                "عدد نتائج الآيات: ${ArabicNumbers().convert(verseCount)}",
                                effectiveGroupTitleColor);
                          }

                          if (suraCount == 0 && verseCount > 0 && index == 0) {
                            return _buildGroupTitle(
                                "عدد نتائج الآيات: ${ArabicNumbers().convert(verseCount)}",
                                effectiveGroupTitleColor);
                          }

                          // Calculate the actual result index
                          int resultIndex = index;
                          if (suraCount > 0) {
                            resultIndex--; // Adjust for sura title
                            if (verseCount > 0 && index > suraCount) {
                              resultIndex--; // Adjust for verse title
                            }
                          } else if (verseCount > 0) {
                            resultIndex--; // Adjust for verse title
                          }

                          final result = _searchResults[resultIndex];
                          final isSurah = result['type'] == 'surah';

                          if (isSurah) {
                            final surahNum = result['surah_number'] as int;
                            // Find the first page of this surah
                            final firstAyahPage =
                                suraAyahToPage[surahNum]?[1] ?? 1;
                            final int page = firstAyahPage;

                            return InkWell(
                              onTap: () {
                                if (mounted) {
                                  setState(() {
                                    _isSearchOpen = false;
                                    _searchResults = [];
                                    _highlightedAyahKey = '${surahNum}_1';
                                    _highlightedPage = page;
                                  });
                                }
                                _pageController.jumpToPage(page - 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.withOpacity(0.1))),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Text(
                                      "${_getSurahGlyph(surahNum)}\u005C",
                                      style: TextStyle(
                                        fontFamily: widget.fontFamilyName,
                                        fontSize: 24,
                                        color: effectiveResultTextColor,
                                      ),
                                      textDirection: TextDirection.ltr,
                                    ),
                                    Text(
                                      'صفحة  ${ArabicNumbers().convert(page)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: effectiveResultInfoColor,
                                        fontFamily: widget.nonQuranFont,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            final surah = result['surah_number'] as int;
                            final ayah = result['verse_number'] as int;
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
                                              color: Colors.grey
                                                  .withOpacity(0.1))),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Directionality(
                                          textDirection: TextDirection.rtl,
                                          child: Text(
                                            qfcText,
                                            style: TextStyle(
                                              fontFamily: fontFamily,
                                              fontSize: 22,
                                              color: effectiveResultTextColor,
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
                                              "${_getSurahGlyph(surah)}\u005C",
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontFamily:
                                                    widget.fontFamilyName,
                                                color: effectiveResultInfoColor,
                                              ),
                                              textDirection: TextDirection.ltr,
                                            ),
                                            Text(
                                              'صفحة  ${ArabicNumbers().convert(page)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: effectiveResultInfoColor,
                                                fontFamily: widget.nonQuranFont,
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
                          }
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

  /// The text color used for the Quran page image.
  final Color quranTextColor;

  /// The text color used for top bar text (Juz and Surah names).
  final Color topBarTextColor;

  /// The text color used for the page number text at the bottom.
  final Color pageNumberColor;

  /// The design style for the page number container.
  final PageNumberDesign pageNumberDesign;

  /// The background color for the page number container.
  final Color? pageNumberBackgroundColor;

  /// The border color for the page number container.
  final Color? pageNumberBorderColor;

  /// The color for the grouping titles in search results.
  final Color searchResultGroupTitleColor;

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
  final Color searchIconColor;

  /// Callback when the search icon is tapped.
  final VoidCallback? onSearchTap;

  /// The key of the ayah currently highlighted on this page.
  final String? highlightedAyahKey;

  /// Callback when the ayah selection is cleared.
  final VoidCallback? onClearSelection;

  /// Quarters of hizb that start on this page.
  final List<int>? quarters;

  /// Background color for the ayah action menu.
  final Color ayahMenuBackgroundColor;

  /// Background color for the ayah action menu in dark mode.
  final Color ayahMenuDarkBackgroundColor;

  /// Text color for ayah menu items.
  final Color ayahMenuTextColor;

  /// Icon color for ayah menu items.
  final Color ayahMenuIconColor;

  /// Divider color in the ayah menu.
  final Color ayahMenuDividerColor;

  /// List of custom action options for the ayah menu.
  final List<AyahActionOption> customAyahActions;

  /// Whether to show the default ayah menu.
  final bool showDefaultAyahMenu;

  /// The font family used for normal text.
  final String? nonQuranFont;

  // ── Tafsir sheet colors ──────────────────────────────────────────────────
  final Color tafsirSheetBackgroundColor;
  final Color tafsirSheetDarkBackgroundColor;
  final Color tafsirTextColor;
  final Color tafsirDarkTextColor;
  final Color tafsirAyahTextColor;
  final Color tafsirTabSelectedColor;
  final Color tafsirTabUnselectedColor;
  final Color tafsirOverlayColor;

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
    required this.quranTextColor,
    required this.topBarTextColor,
    required this.pageNumberColor,
    required this.pageNumberDesign,
    this.pageNumberBackgroundColor,
    this.pageNumberBorderColor,
    required this.searchResultGroupTitleColor,
    required this.highlightColor,
    required this.highlightDuration,
    required this.showSearchIcon,
    required this.searchIconColor,
    this.highlightedAyahKey,
    this.onClearSelection,
    this.quarters,
    required this.ayahMenuBackgroundColor,
    required this.ayahMenuDarkBackgroundColor,
    required this.ayahMenuTextColor,
    required this.ayahMenuIconColor,
    required this.ayahMenuDividerColor,
    required this.customAyahActions,
    required this.showDefaultAyahMenu,
    required this.nonQuranFont,
    required this.tafsirSheetBackgroundColor,
    required this.tafsirSheetDarkBackgroundColor,
    required this.tafsirTextColor,
    required this.tafsirDarkTextColor,
    required this.tafsirAyahTextColor,
    required this.tafsirTabSelectedColor,
    required this.tafsirTabUnselectedColor,
    required this.tafsirOverlayColor,
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

  /// Whether the ayah menu is currently visible.

  /// Global key for the ayah menu overlay.
  final GlobalKey _menuKey = GlobalKey();

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
      if (widget.onClearSelection != null) {
        widget.onClearSelection!();
      }
    }
  }

  /// Gets the plain text of an ayah from quranText data.
  String _getAyahText(int surah, int ayah) {
    try {
      final verse = quranText.firstWhere(
        (v) => v['surah_number'] == surah && v['verse_number'] == ayah,
        orElse: () => {'content': ''},
      );
      return verse['content'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Gets the QFC text for an ayah on its specific page.
  Future<String> _getAyahQfcText(int surah, int ayah) async {
    final page = suraAyahToPage[surah]?[ayah] ?? 1;
    await FontManager.loadFont(page);
    if (page >= 1 && page <= quranTextData.length) {
      final pageLines = quranTextData[page - 1];
      final Set<String> seen = {};
      final List<Map<String, int>> pageAyahs = [];
      for (final row in ayahRows) {
        if (row['page_number'] == page) {
          final s = row['sura_number'] as int;
          final a = row['ayah_number'] as int;
          final key = '$s:$a';
          if (!seen.contains(key)) {
            seen.add(key);
            pageAyahs.add({'surah': s, 'ayah': a});
          }
        }
      }
      pageAyahs.sort((a, b) {
        if (a['surah'] != b['surah']) return a['surah']!.compareTo(b['surah']!);
        return a['ayah']!.compareTo(b['ayah']!);
      });
      final index =
          pageAyahs.indexWhere((e) => e['surah'] == surah && e['ayah'] == ayah);
      if (index != -1 && index < pageLines.length) return pageLines[index];
    }
    return '';
  }

  /// Copies a range of ayahs to clipboard.
  Future<void> _copyAyahRangeToClipboard(int surah, int start, int end) async {
    List<String> lines = [];
    for (int i = start; i <= end; i++) {
      final text = _getAyahText(surah, i);
      if (text.isNotEmpty) {
        lines.add("$text \uFD3F${ArabicNumbers().convert(i)}\uFD3E");
      }
    }
    if (lines.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: lines.join(" ")));
    }
  }

  /// Saves a range of ayahs as an image.
  Future<void> _saveAyahRangeAsImage(
      int surah, int start, int end, Color bgColor, Color textColor) async {
    try {
      List<({String text, String font})> ayahItems = [];
      for (int i = start; i <= end; i++) {
        final page = suraAyahToPage[surah]?[i] ?? 1;
        final qfc = await _getAyahQfcText(surah, i);
        if (qfc.isNotEmpty) {
          ayahItems.add(
              (text: qfc, font: 'QCF_P${page.toString().padLeft(3, '0')}'));
        }
      }
      if (ayahItems.isEmpty) return;

      final surahGlyphChar = imageSuraGlyph[surah] ?? '';
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const width = 800.0;
      const padding = 50.0;

      final bgPaint = Paint()..color = bgColor;
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, 5000), bgPaint);

      final containerPainter = TextPainter(
        text: TextSpan(
          text: '\u00F2',
          style: TextStyle(
              fontFamily: widget.fontFamilyName,
              fontSize: 80,
              color: textColor),
        ),
        textDirection: TextDirection.rtl,
      );
      containerPainter.layout(maxWidth: width - padding * 2);
      containerPainter.paint(
          canvas, Offset((width - containerPainter.width) / 2, padding - 40));

      final namePainter = TextPainter(
        text: TextSpan(
          text: "\u005C$surahGlyphChar",
          style: TextStyle(
              fontFamily: widget.fontFamilyName,
              fontSize: 50,
              color: textColor),
        ),
        textDirection: TextDirection.rtl,
      );
      namePainter.layout(maxWidth: width - padding * 2);
      namePainter.paint(
          canvas, Offset((width - namePainter.width) / 2, padding));

      double currentY =
          padding + max(containerPainter.height, namePainter.height) + 50;

      List<TextSpan> spans = [];
      for (var item in ayahItems) {
        spans.add(TextSpan(
          text: item.text.replaceAll('\n', ' ').replaceAll('\r', '').trim() +
              (item == ayahItems.last ? '' : ' '),
          style: TextStyle(
              fontFamily: item.font,
              fontSize: 49,
              color: textColor,
              height: 1.8),
        ));
      }

      final ayahPainter = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );
      ayahPainter.layout(maxWidth: width - padding * 2);
      ayahPainter.paint(
          canvas, Offset((width - ayahPainter.width) / 2, currentY - 80));
      currentY += ayahPainter.height;

      final finalHeight = currentY + padding - 40;
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), finalHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final fileName =
          'ayah_${surah}_${start}_${end}_${DateTime.now().millisecondsSinceEpoch}.png';

      final permission = await PhotoManager.requestPermissionExtend();

      if (!(permission.isAuth || permission.hasAccess)) {
        await PhotoManager.openSetting();
        throw Exception("Permission denied");
      }

      await PhotoManager.editor.saveImage(
        buffer,
        title: fileName,
        filename: fileName,
      );

      File? file;

      if (Platform.isAndroid) {
        final directory =
            Directory('/storage/emulated/0/Download/LightOfImaan');

        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        file = File('${directory.path}/$fileName');
        await file.writeAsBytes(buffer);
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();

        file = File('${directory.path}/$fileName');
        await file.writeAsBytes(buffer);
      }

      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              '📖 آية رقم ${start == end ? start : '$start-$end'} من سورة ${quran.getSurahName(surah)}',
        );
      }
    } catch (e) {
      developer.log('Error saving image: $e');
    }
  }

  void _showShareSheet({required int initialSurah, required int initialAyah}) {
    final isDark = widget.themeModeAdaption &&
        Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: widget.tafsirOverlayColor,
      builder: (ctx) {
        return _ShareSheet(
          initialSurah: initialSurah,
          initialAyah: initialAyah,
          widget: widget,
          isDark: isDark,
          getAyahText: _getAyahText,
          onCopy: (s, start, end) {
            _copyAyahRangeToClipboard(s, start, end);
          },
          onSaveImage: (s, start, end, bg, text) {
            _saveAyahRangeAsImage(s, start, end, bg, text);
          },
        );
      },
    );
  }

  /// Shows the ayah action menu using a dialog so the scrim covers the full
  /// screen (including SafeArea / status bar area).
  void _showAyahMenu(int surah, int ayah) {
    // Highlight the pressed ayah immediately.
    setState(() {
      _selectedAyahKey = '${surah}_$ayah';
    });

    final isDark = widget.themeModeAdaption &&
        Theme.of(context).brightness == Brightness.dark;
    final effectiveBgColor = isDark
        ? widget.ayahMenuDarkBackgroundColor
        : widget.ayahMenuBackgroundColor;
    final effectiveTextColor = widget.themeModeAdaption
        ? (isDark ? Colors.white : Colors.black)
        : widget.ayahMenuTextColor;
    final effectiveIconColor = widget.themeModeAdaption
        ? (isDark ? Colors.white70 : Colors.blue)
        : widget.ayahMenuIconColor;
    final effectiveDividerColor = widget.themeModeAdaption
        ? (isDark ? Colors.white24 : const Color(0xFFE0E0E0))
        : widget.ayahMenuDividerColor;

    // Tafsir option (always shown)
    final Map<String, dynamic> tafsirOption = {
      'title': 'تفسير',
      'icon': Icons.auto_stories_rounded,
      'onTap': (BuildContext ctx) {
        Navigator.pop(ctx);
        _showTafsirSheet(surah, ayah);
      },
    };

    // Share option (replaces separate copy + image options)
    final List<Map<String, dynamic>> defaultOptions = widget.showDefaultAyahMenu
        ? [
            {
              'title': 'مشاركة',
              'icon': Icons.ios_share_rounded,
              'onTap': (BuildContext ctx) {
                Navigator.pop(ctx);
                _showShareSheet(initialSurah: surah, initialAyah: ayah);
              },
            },
          ]
        : [];

    final List<Map<String, dynamic>> allOptions = [
      tafsirOption,
      ...defaultOptions,
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      barrierDismissible: true,
      builder: (ctx) => Align(
        alignment: const Alignment(0, 0.85),
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: _menuKey,
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Built-in options
                for (int i = 0; i < allOptions.length; i++) ...[
                  InkWell(
                    onTap: () =>
                        (allOptions[i]['onTap'] as Function(BuildContext))(ctx),
                    borderRadius: i == 0 &&
                            widget.customAyahActions.isEmpty &&
                            allOptions.length == 1
                        ? BorderRadius.circular(16)
                        : i == 0
                            ? const BorderRadius.vertical(
                                top: Radius.circular(16))
                            : i == allOptions.length - 1 &&
                                    widget.customAyahActions.isEmpty
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(16))
                                : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(
                            allOptions[i]['icon'] as IconData,
                            color: effectiveIconColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            allOptions[i]['title'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: effectiveTextColor,
                              fontFamily: widget.nonQuranFont,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < allOptions.length - 1 ||
                      widget.customAyahActions.isNotEmpty)
                    Divider(
                      color: effectiveDividerColor,
                      height: 1,
                      thickness: 0.5,
                      indent: 20,
                      endIndent: 20,
                    ),
                ],
                // Custom options
                for (int i = 0; i < widget.customAyahActions.length; i++) ...[
                  InkWell(
                    onTap: () {
                      widget.customAyahActions[i].onPress(
                        surah,
                        ayah,
                        widget.pageNumber,
                      );
                      Navigator.pop(ctx);
                    },
                    borderRadius: i == widget.customAyahActions.length - 1
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(16))
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(
                            widget.customAyahActions[i].icon,
                            color: effectiveIconColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.customAyahActions[i].title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: effectiveTextColor,
                              fontFamily: widget.nonQuranFont,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < widget.customAyahActions.length - 1)
                    Divider(
                      color: effectiveDividerColor,
                      height: 1,
                      thickness: 0.5,
                      indent: 20,
                      endIndent: 20,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedAyahKey = null;
        });
      }
    });
  }

  /// Shows the tafsir bottom sheet for the given [surah] and [ayah].
  Future<void> _showTafsirSheet(int surah, int ayah) async {
    final isDark = widget.themeModeAdaption &&
        Theme.of(context).brightness == Brightness.dark;

    final Color sheetBg = isDark
        ? widget.tafsirSheetDarkBackgroundColor
        : widget.tafsirSheetBackgroundColor;
    final Color bodyText =
        isDark ? widget.tafsirDarkTextColor : widget.tafsirTextColor;

    // Fix 3: Preload QCF font and text for the selected ayah
    final page = suraAyahToPage[surah]?[ayah] ?? 1;
    await FontManager.loadFont(page);
    final String ayahQfc = await _getAyahQfcText(surah, ayah);
    final String ayahFontFamily = 'QCF_P${page.toString().padLeft(3, '0')}';

    // Fix 5: Get all ayahs on current page for "Read More"
    final List<({int surah, int ayah, String qfc, String font})> pageAyahs = [];
    final Set<String> seen = {};
    for (final s in _segments) {
      final key = '${s.sura}:${s.ayah}';
      if (!seen.contains(key)) {
        seen.add(key);
        final qfcText = await _getAyahQfcText(s.sura, s.ayah);
        final p = suraAyahToPage[s.sura]?[s.ayah] ?? 1;
        pageAyahs.add((
          surah: s.sura,
          ayah: s.ayah,
          qfc: qfcText,
          font: 'QCF_P${p.toString().padLeft(3, '0')}'
        ));
      }
    }

    // Sort ayahs by surah then ayah (Fix: Order & Completeness)
    pageAyahs.sort((a, b) {
      if (a.surah != b.surah) return a.surah.compareTo(b.surah);
      return a.ayah.compareTo(b.ayah);
    });

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: widget.tafsirOverlayColor,
      builder: (ctx) {
        return _TafsirSheet(
          surah: surah,
          ayah: ayah,
          ayahQfc: ayahQfc,
          ayahFontFamily: ayahFontFamily,
          pageAyahs: pageAyahs,
          sheetBg: sheetBg,
          bodyTextColor: bodyText,
          ayahTextColor: widget.tafsirAyahTextColor,
          tabSelectedColor: widget.tafsirTabSelectedColor,
          tabUnselectedColor: widget.tafsirTabUnselectedColor,
          nonQuranFont: widget.nonQuranFont,
          fontFamilyName: widget.fontFamilyName,
          tafsirOverlayColor: widget.tafsirOverlayColor,
        );
      },
    );
  }

  /// Hides the ayah action menu and unhighlights the ayah (kept for compat).

  /// Returns a formatted string describing the Hizb and Quarter for a given [q].
  String _getQuarterDetail(int q) {
    final hizbNum = ((q - 1) ~/ 4) + 1;
    final quarterInHizb = (q - 1) % 4;
    final hizbStr = ArabicNumbers().convert(hizbNum);

    switch (quarterInHizb) {
      case 0:
        return "بداية الحزب $hizbStr";
      case 1:
        return "الربع الأول من الحزب $hizbStr";
      case 2:
        return "نصف الحزب $hizbStr";
      case 3:
        return "الربع الثالث من الحزب $hizbStr";
      default:
        return "";
    }
  }

  @override

  /// Builds the single page view with ayah detection and highlighting.
  Widget build(BuildContext context) {
    const imgW = 1920.0;
    const imgH = 3106.0;
    const double scrollThreshold = 520.0;
    const double topTextHeight = 60.0;
    const double bottomTextHeight = 100.0; // Increased to avoid overflow

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

        return Stack(
          children: [
            GestureDetector(
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 30),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: GestureDetector(
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
                                                  : widget.topBarTextColor,
                                              fontFamily:
                                                  widget.fontFamilyName),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.showSearchIcon)
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: widget.onSearchTap,
                                        child: Icon(
                                          Icons.search,
                                          color: widget.searchIconColor,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: GestureDetector(
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
                                                  : widget.topBarTextColor,
                                              fontFamily:
                                                  widget.fontFamilyName),
                                          textDirection: TextDirection.ltr,
                                        ),
                                      ),
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
                                : widget.quranTextColor,
                          ),
                          for (final s in _segments)
                            Positioned(
                              left: s.minX * scrollScale,
                              top: s.minY * scrollScale,
                              width: s.width * scrollScale,
                              height: s.height * scrollScale,
                              child: GestureDetector(
                                onLongPress: () {
                                  _showAyahMenu(s.sura, s.ayah);
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
                            child: Align(
                              alignment: widget.pageNumber % 2 == 0
                                  ? Alignment.bottomLeft
                                  : Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: widget.pageNumber % 2 == 0
                                      ? CrossAxisAlignment.start
                                      : CrossAxisAlignment.end,
                                  children: [
                                    if (widget.quarters != null &&
                                        widget.quarters!.isNotEmpty)
                                      for (int q in widget.quarters!)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            _getQuarterDetail(q),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: widget.themeModeAdaption
                                                  ? IconTheme.of(context).color
                                                  : widget.pageNumberColor,
                                              fontFamily: widget.nonQuranFont,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: widget.themeModeAdaption
                                            ? (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black
                                                    .withOpacity(0.05))
                                            : widget.pageNumberColor
                                                .withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: widget.themeModeAdaption
                                                ? (Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white24
                                                    : Colors.black12)
                                                : widget.pageNumberColor
                                                    .withOpacity(0.1)),
                                      ),
                                      child: Text(
                                        ArabicNumbers()
                                            .convert(widget.pageNumber)
                                            .toString(),
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: widget.themeModeAdaption
                                                ? IconTheme.of(context).color
                                                : widget.pageNumberColor,
                                            fontFamily: widget.nonQuranFont),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return Stack(
        children: [
          GestureDetector(
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
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
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
                                              : widget.topBarTextColor,
                                          fontFamily: widget.fontFamilyName),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.showSearchIcon)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: widget.onSearchTap,
                                    child: Icon(
                                      Icons.search,
                                      color: widget.themeModeAdaption
                                          ? IconTheme.of(context).color
                                          : widget.searchIconColor,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
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
                                              : widget.topBarTextColor,
                                          fontFamily: widget.fontFamilyName),
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ),
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
                              : widget.quranTextColor,
                        ),
                      ),
                      for (final s in _segments)
                        Positioned(
                          left: (containerW - normalDispW) / 2 +
                              s.minX * normalScale,
                          top: s.minY * normalScale,
                          width: s.width * normalScale,
                          height: s.height * normalScale,
                          child: GestureDetector(
                            onLongPress: () {
                              _showAyahMenu(s.sura, s.ayah);
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
                        child: Align(
                          alignment: widget.pageNumber % 2 == 0
                              ? Alignment.bottomLeft
                              : Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: widget.pageNumber % 2 == 0
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.end,
                              children: [
                                (() {
                                  // Helper to build the quarter text widgets
                                  List<Widget> quarterWidgets = [];
                                  if (widget.quarters != null &&
                                      widget.quarters!.isNotEmpty) {
                                    for (int q in widget.quarters!) {
                                      quarterWidgets.add(
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Text(
                                            _getQuarterDetail(q),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: widget.themeModeAdaption
                                                  ? IconTheme.of(context).color
                                                  : widget.pageNumberColor,
                                              fontFamily: widget.nonQuranFont,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  if (widget.pageNumberDesign ==
                                      PageNumberDesign.none) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          widget.pageNumber % 2 == 0
                                              ? CrossAxisAlignment.start
                                              : CrossAxisAlignment.end,
                                      children: [
                                        ...quarterWidgets,
                                        Text(
                                          ArabicNumbers()
                                              .convert(widget.pageNumber)
                                              .toString(),
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: widget.themeModeAdaption
                                                  ? IconTheme.of(context).color
                                                  : widget.pageNumberColor,
                                              fontFamily: widget.nonQuranFont),
                                          textDirection: TextDirection.rtl,
                                        ),
                                      ],
                                    );
                                  }

                                  final bool isDark =
                                      Theme.of(context).brightness ==
                                          Brightness.dark;

                                  // Effective colors
                                  final Color effectiveBg = widget
                                          .pageNumberBackgroundColor ??
                                      (widget.themeModeAdaption
                                          ? (isDark
                                              ? Colors.white.withOpacity(0.12)
                                              : Colors.black.withOpacity(0.06))
                                          : widget.pageNumberColor
                                              .withOpacity(0.06));

                                  final Color effectiveBorder =
                                      widget.pageNumberBorderColor ??
                                          (widget.themeModeAdaption
                                              ? (isDark
                                                  ? Colors.white24
                                                  : Colors.black12)
                                              : widget.pageNumberColor
                                                  .withOpacity(0.15));

                                  BoxDecoration deco;
                                  switch (widget.pageNumberDesign) {
                                    case PageNumberDesign.pill:
                                      deco = BoxDecoration(
                                        color: effectiveBg,
                                        borderRadius: BorderRadius.circular(24),
                                        border:
                                            Border.all(color: effectiveBorder),
                                      );
                                      break;
                                    case PageNumberDesign.classic:
                                      deco = BoxDecoration(
                                        color: effectiveBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border:
                                            Border.all(color: effectiveBorder),
                                      );
                                      break;
                                    case PageNumberDesign.glass:
                                      deco = BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.white.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.2)),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.04),
                                            blurRadius: 8,
                                          )
                                        ],
                                      );
                                      break;
                                    case PageNumberDesign.outlined:
                                    default:
                                      deco = BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: widget
                                                    .pageNumberBorderColor ??
                                                (widget.themeModeAdaption
                                                    ? (isDark
                                                        ? Colors.white70
                                                        : Colors.black54)
                                                    : widget.pageNumberColor)),
                                      );
                                      break;
                                  }

                                  return IntrinsicWidth(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: deco,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          ...quarterWidgets,
                                          Text(
                                            ArabicNumbers()
                                                .convert(widget.pageNumber)
                                                .toString(),
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: widget.themeModeAdaption
                                                    ? IconTheme.of(context)
                                                        .color
                                                    : widget.pageNumberColor,
                                                fontFamily:
                                                    widget.nonQuranFont),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }()),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ],
            ),
          ),
        ],
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
      final fontData = await rootBundle.load('assets/fonts/$family.TTF');
      final loader = FontLoader(family);
      loader.addFont(Future.value(fontData));
      await loader.load();
      _loadedFamilies.add(family);
      developer.log('Loaded font: $family');
    } catch (e) {
      developer.log('Error loading font $family: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QuranTafsir — External utility class
// ─────────────────────────────────────────────────────────────────────────────

/// Available tafsir indices used with [QuranTafsir.getText].
enum QuranTafsirType {
  /// التفسير الميسر (index 0)
  muyassar,

  /// تفسير البغوي (index 1)
  baghawi,

  /// تفسير القرطبي (index 2)
  qurtubi,

  /// تفسير السعدي (index 3)
  saddi,

  /// تفسير الطبري (index 4)
  tabari,

  /// تفسير الواسط (index 5)
  wasit,

  /// تفسير ابن كثير (index 6)
  ibnKathir,

  /// تنوير المقباس (index 7)
  tanwirAlMiqbas,
}

class _TafsirSource {
  final String name;
  final String bookName;
  final List<Map<int, String>> data;
  _TafsirSource(
      {required this.name, required this.bookName, required this.data});
}

/// A utility class that provides external access to Quran tafsir data.
///
/// Usage:
/// ```dart
/// final text = QuranTafsir.getText(surah: 1, ayah: 1,
///     type: QuranTafsirType.muyassar);
/// ```
class QuranTafsir {
  // Private data lookup list — same order as [QuranTafsirType].
  static final List<_TafsirSource> _sources = [
    _TafsirSource(
        name: muyassar.tafsirName,
        bookName: muyassar.tafsirBookName,
        data: muyassar.surahAyahTafsirMuyassarData),
    _TafsirSource(
        name: baghawi.tafsirName,
        bookName: baghawi.tafsirBookName,
        data: baghawi.surahAyahTafsirAlBaghawiData),
    _TafsirSource(
        name: qurtubi.tafsirName,
        bookName: qurtubi.tafsirBookName,
        data: qurtubi.surahAyahTafsirAlQurtubiData),
    _TafsirSource(
        name: saddi.tafsirName,
        bookName: saddi.tafsirBookName,
        data: saddi.surahAyahTafsirAlSaddiData),
    _TafsirSource(
        name: tabari.tafsirName,
        bookName: tabari.tafsirBookName,
        data: tabari.surahAyahTafsirAlTabariData),
    _TafsirSource(
        name: wasit.tafsirName,
        bookName: wasit.tafsirBookName,
        data: wasit.surahAyahTafsirAlWasitData),
    _TafsirSource(
        name: ibn_kathir.tafsirName,
        bookName: ibn_kathir.tafsirBookName,
        data: ibn_kathir.surahAyahTafsirIbnKathirData),
    _TafsirSource(
        name: tanwir.tafsirName,
        bookName: tanwir.tafsirBookName,
        data: tanwir.surahAyahTafsirTanwirAlMiqbasData),
  ];

  /// Returns the tafsir text for a specific [surah] (1-114) and [ayah].
  ///
  /// [type] selects which tafsir to use (default: [QuranTafsirType.muyassar]).
  /// Returns an empty string if the surah/ayah is out of range or not found.
  static String getText({
    required int surah,
    required int ayah,
    QuranTafsirType type = QuranTafsirType.muyassar,
  }) {
    final idx = type.index;
    if (idx < 0 || idx >= _sources.length) return '';
    final surahData = _sources[idx].data;
    if (surah < 1 || surah > surahData.length) return '';
    return surahData[surah - 1][ayah] ?? '';
  }

  /// Returns the display name for a given [QuranTafsirType].
  static String getName(QuranTafsirType type) => _sources[type.index].name;

  /// Returns the book name for a given [QuranTafsirType].
  static String getBookName(QuranTafsirType type) =>
      _sources[type.index].bookName;

  /// Returns the list of all available tafsir names (8 items).
  static List<String> get allNames =>
      List.unmodifiable(_sources.map((e) => e.name));
}

// ─────────────────────────────────────────────────────────────────────────────
// _TafsirSheet — private bottom sheet widget
// ─────────────────────────────────────────────────────────────────────────────

class _TafsirSheet extends StatefulWidget {
  final int surah;
  final int ayah;
  final String ayahQfc;
  final String ayahFontFamily;
  final List<({int surah, int ayah, String qfc, String font})> pageAyahs;
  final Color sheetBg;
  final Color bodyTextColor;
  final Color ayahTextColor;
  final Color tabSelectedColor;
  final Color tabUnselectedColor;
  final Color tafsirOverlayColor;
  final String? nonQuranFont;
  final String fontFamilyName;

  const _TafsirSheet({
    required this.surah,
    required this.ayah,
    required this.ayahQfc,
    required this.ayahFontFamily,
    required this.pageAyahs,
    required this.sheetBg,
    required this.bodyTextColor,
    required this.ayahTextColor,
    required this.tabSelectedColor,
    required this.tabUnselectedColor,
    required this.tafsirOverlayColor,
    required this.nonQuranFont,
    required this.fontFamilyName,
  });

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  late final PageController _pageCtrl;
  int _selectedTab = 0;
  final ScrollController _tabScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _tabScrollCtrl.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => _selectedTab = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showReadMore() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: widget.tafsirOverlayColor,
      builder: (ctx) {
        return _TafsirReadMoreSheet(
          pageAyahs: widget.pageAyahs,
          source: QuranTafsir._sources[_selectedTab],
          sheetBg: widget.sheetBg,
          bodyTextColor: widget.bodyTextColor,
          ayahTextColor: widget.ayahTextColor,
          tabSelectedColor: widget.tabSelectedColor,
          nonQuranFont: widget.nonQuranFont,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.75, // Fix 1: Fixed height scrollable sheet
      decoration: BoxDecoration(
        color: widget.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Fix 2: TabBar with Name + BookName
          SizedBox(
            height: 54,
            child: ListView.builder(
              controller: _tabScrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: QuranTafsir._sources.length,
              itemBuilder: (_, i) {
                final isSelected = _selectedTab == i;
                final source = QuranTafsir._sources[i];
                return GestureDetector(
                  onTap: () => _onTabTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.only(left: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.tabSelectedColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? widget.tabSelectedColor
                            : widget.tabUnselectedColor.withOpacity(0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          source.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? widget.tabSelectedColor
                                : widget.tabUnselectedColor,
                            fontFamily: widget.nonQuranFont,
                          ),
                        ),
                        Text(
                          source.bookName,
                          style: TextStyle(
                            fontSize: 10,
                            color: (isSelected
                                    ? widget.tabSelectedColor
                                    : widget.tabUnselectedColor)
                                .withOpacity(0.6),
                            fontFamily: widget.nonQuranFont,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Divider(height: 1, thickness: 0.5),
          ),

          // ViewPager content
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: QuranTafsir._sources.length,
              onPageChanged: (i) => setState(() => _selectedTab = i),
              itemBuilder: (ctx, idx) {
                final text = idx < QuranTafsir._sources.length
                    ? (QuranTafsir._sources[idx].data[widget.surah - 1]
                            [widget.ayah] ??
                        '')
                    : '';

                // Fix 1: Ayah Box inside ScrollView so it scrolls with tafsir
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    // Ayah QFC Box (Fix 3)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: widget.tabSelectedColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: widget.tabSelectedColor.withOpacity(0.15)),
                      ),
                      child: Text(
                        widget.ayahQfc,
                        style: TextStyle(
                          fontSize: 22,
                          color: widget.ayahTextColor,
                          fontFamily: widget.ayahFontFamily,
                          height: 1.8,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      text.isEmpty ? 'لا يوجد تفسير متاح' : text,
                      style: TextStyle(
                        fontSize: 17,
                        color: widget.bodyTextColor,
                        fontFamily: widget.nonQuranFont,
                        height: 1.9,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                );
              },
            ),
          ),

          // Fix 5: Read More Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showReadMore,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text('إقرأ تفسير الصفحة بالكامل',
                      style: TextStyle(
                          fontFamily: widget.nonQuranFont,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.tabSelectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TafsirReadMoreSheet extends StatefulWidget {
  final List<({int surah, int ayah, String qfc, String font})> pageAyahs;
  final _TafsirSource source;
  final Color sheetBg;
  final Color bodyTextColor;
  final Color ayahTextColor;
  final Color tabSelectedColor;
  final String? nonQuranFont;

  const _TafsirReadMoreSheet({
    required this.pageAyahs,
    required this.source,
    required this.sheetBg,
    required this.bodyTextColor,
    required this.ayahTextColor,
    required this.tabSelectedColor,
    required this.nonQuranFont,
  });

  @override
  State<_TafsirReadMoreSheet> createState() => _TafsirReadMoreSheetState();
}

class _TafsirReadMoreSheetState extends State<_TafsirReadMoreSheet> {
  late _TafsirSource _selectedSource;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.source;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: widget.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Updated Title: Dropdown for Tafsir selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_TafsirSource>(
                isExpanded: true,
                value: _selectedSource,
                dropdownColor: widget.sheetBg,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: widget.tabSelectedColor),
                items: QuranTafsir._sources.map((source) {
                  return DropdownMenuItem<_TafsirSource>(
                    value: source,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            source.name,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.tabSelectedColor,
                                fontFamily: widget.nonQuranFont),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            source.bookName,
                            style: TextStyle(
                                fontSize: 10,
                                color: widget.tabSelectedColor.withOpacity(0.7),
                                fontFamily: widget.nonQuranFont),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSource = val);
                },
                alignment: Alignment.center,
                selectedItemBuilder: (ctx) {
                  return QuranTafsir._sources.map((source) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedSource.name,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.tabSelectedColor,
                                fontFamily: widget.nonQuranFont),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _selectedSource.bookName,
                            style: TextStyle(
                                fontSize: 12,
                                color: widget.tabSelectedColor.withOpacity(0.7),
                                fontFamily: widget.nonQuranFont),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),

          const Divider(height: 20),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              itemCount: widget.pageAyahs.length,
              separatorBuilder: (_, __) => const Divider(height: 40),
              itemBuilder: (ctx, i) {
                final item = widget.pageAyahs[i];
                final text =
                    _selectedSource.data[item.surah - 1][item.ayah] ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.tabSelectedColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.qfc,
                        style: TextStyle(
                            fontSize: 20,
                            fontFamily: item.font,
                            color: widget.ayahTextColor,
                            height: 1.7),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      text,
                      style: TextStyle(
                          fontSize: 16,
                          color: widget.bodyTextColor,
                          fontFamily: widget.nonQuranFont,
                          height: 1.8),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  final int initialSurah;
  final int initialAyah;
  final _QuranPage widget;
  final bool isDark;
  final String Function(int, int) getAyahText;
  final Function(int, int, int) onCopy;
  final Function(int, int, int, Color, Color) onSaveImage;

  const _ShareSheet({
    required this.initialSurah,
    required this.initialAyah,
    required this.widget,
    required this.isDark,
    required this.getAyahText,
    required this.onCopy,
    required this.onSaveImage,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabPageCtrl;
  late int selectedSurah;
  late int startAyah;
  late int endAyah;
  Color selectedBgColor = Colors.white;
  Color selectedTextColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _tabPageCtrl = TabController(length: 2, vsync: this);
    selectedSurah = widget.initialSurah;
    startAyah = widget.initialAyah;
    endAyah = widget.initialAyah;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = widget.isDark
        ? widget.widget.ayahMenuDarkBackgroundColor
        : widget.widget.ayahMenuBackgroundColor;
    final effectiveTextColor = widget.widget.themeModeAdaption
        ? (widget.isDark ? Colors.white : Colors.black)
        : widget.widget.ayahMenuTextColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabPageCtrl,
            labelColor: widget.widget.ayahMenuIconColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: widget.widget.ayahMenuIconColor,
            labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: widget.widget.nonQuranFont),
            tabs: const [
              Tab(text: 'نسخ ومشاركة'),
              Tab(text: 'حفظ ومشاركة'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabPageCtrl,
              children: [
                _buildActionContent(false, effectiveTextColor),
                _buildActionContent(true, effectiveTextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionContent(bool isImage, Color textColor) {
    int totalAyahs = quran.getVerseCount(selectedSurah);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          _buildDropdownRow(
              'السورة:',
              selectedSurah,
              List.generate(114, (i) => i + 1),
              (val) => setState(() {
                    selectedSurah = val!;
                    startAyah = 1;
                    endAyah = 1;
                  }),
              (val) => quran.getSurahNameArabic(val),
              textColor,
              widget.widget.nonQuranFont,
              widget.widget.themeModeAdaption && widget.isDark
                  ? widget.widget.ayahMenuDarkBackgroundColor
                  : widget.widget.ayahMenuBackgroundColor,
              context),
          _buildDropdownRow(
              'من آية:',
              startAyah,
              List.generate(totalAyahs, (i) => i + 1),
              (val) => setState(() {
                    startAyah = val!;
                    if (endAyah < startAyah) endAyah = startAyah;
                  }),
              (val) => ArabicNumbers().convert(val),
              textColor,
              widget.widget.nonQuranFont,
              widget.widget.themeModeAdaption && widget.isDark
                  ? widget.widget.ayahMenuDarkBackgroundColor
                  : widget.widget.ayahMenuBackgroundColor,
              context),
          _buildDropdownRow(
              'إلى آية:',
              endAyah,
              List.generate(totalAyahs - startAyah + 1, (i) => i + startAyah),
              (val) => setState(() => endAyah = val!),
              (val) => ArabicNumbers().convert(val),
              textColor,
              widget.widget.nonQuranFont,
              widget.widget.themeModeAdaption && widget.isDark
                  ? widget.widget.ayahMenuDarkBackgroundColor
                  : widget.widget.ayahMenuBackgroundColor,
              context),
          if (isImage) ...[
            const SizedBox(height: 15),
            _buildColorPicker('لون الخلفية:', selectedBgColor, (c) {
              setState(() {
                selectedBgColor = c;
                if (c == Colors.white && selectedTextColor == Colors.white) {
                  selectedTextColor = Colors.black;
                }
                if (c == Colors.black && selectedTextColor == Colors.black) {
                  selectedTextColor = Colors.white;
                }
              });
            }, textColor, false, widget.widget.nonQuranFont,
                widget.widget.ayahMenuIconColor),
            _buildColorPicker('لون النص:', selectedTextColor, (c) {
              setState(() {
                selectedTextColor = c;
                if (c == Colors.white && selectedBgColor == Colors.white) {
                  selectedBgColor = Colors.black;
                }
                if (c == Colors.black && selectedBgColor == Colors.black) {
                  selectedBgColor = Colors.white;
                }
              });
            }, textColor, true, widget.widget.nonQuranFont,
                widget.widget.ayahMenuIconColor),
          ],
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (isImage) {
                  widget.onSaveImage(selectedSurah, startAyah, endAyah,
                      selectedBgColor, selectedTextColor);
                } else {
                  widget.onCopy(selectedSurah, startAyah, endAyah);
                  // Fixed: copy also triggers share
                  List<String> lines = [];
                  for (int i = startAyah; i <= endAyah; i++) {
                    final text = widget.getAyahText(selectedSurah, i);
                    if (text.isNotEmpty) {
                      lines.add(
                          "$text \uFD3F${ArabicNumbers().convert(i)}\uFD3E");
                    }
                  }
                  if (lines.isNotEmpty) {
                    Share.share(lines.join(" "));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.widget.ayahMenuIconColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text(isImage ? 'حفظ ومشاركة الصورة' : 'نسخ ومشاركة النص',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: widget.widget.nonQuranFont)),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildDropdownRow(
    String label,
    int value,
    List<int> items,
    ValueChanged<int?> onChanged,
    String Function(int) itemLabel,
    Color textColor,
    String? font,
    Color dropdownColor,
    BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: font),
                textDirection: TextDirection.rtl)),
        Expanded(
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            dropdownColor: dropdownColor,
            items: items
                .map((i) => DropdownMenuItem(
                    value: i,
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(itemLabel(i),
                            style: TextStyle(
                                color: textColor, fontFamily: font)))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

Widget _buildColorPicker(
    String label,
    Color selected,
    ValueChanged<Color> onSelect,
    Color textColor,
    bool isTextPalette,
    String? font,
    Color indicatorColor) {
  final bgColors = [
    Colors.white,
    Colors.black,
    const Color(0xFFF5E6CA),
    Colors.grey[200]!,
    Colors.blue[100]!,
    Colors.green[100]!
  ];
  final textColors = [
    Colors.white,
    Colors.black,
    const Color(0xFF8B6B3D),
    Colors.grey[800]!,
    Colors.blue[900]!,
    Colors.green[900]!
  ];
  final colors = isTextPalette ? textColors : bgColors;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: font),
                textDirection: TextDirection.rtl)),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: colors
                .map((c) => GestureDetector(
                      onTap: () => onSelect(c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected == c
                                    ? indicatorColor
                                    : Colors.grey,
                                width: selected == c ? 2 : 1)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    ),
  );
}
