# Changelog

## Initial Releases

## 1.2.2

- **Advanced Ayah Action Sheet**:
  - Fixed coloring attributes.
  - Added control for nonQuranic font.
  - Added access controller for initPage.
  - Added "Copy Verse with Reference" action to copy the verse text with the surah and ayah numbers.

## 1.2.1

- **Selection Sheet Improvements**:
  - Fixed text direction for Surah and Juz names in the selection sheet.
  - Added "Surah", "Juz", and "Page" labels for better context.

## 1.2.0

- **Enhanced Page Scrubbing**:
  - Implemented YouTube-style page scrubbing for smooth and fast navigation.
  - Added visual feedback with page previews during scrubbing.
  - Optimized gesture handling for better responsiveness.
- **Advanced UI Customization**:
  - **Page Number Customization**: Added extensive options to customize the page number container, including colors, design styles, and vertical expansion.
  - **Selection Sheet Improvements**: improved context by showing "Surah", "Juz", and "Page" labels.
- **Search Enhancements**:
  - Stylized calligraphic glyphs for Surah names in search results.
  - Improved mapping logic for accurate Surah and Ayah navigation.
- **Performance & Fixes**:
  - Resolved font rendering issues in page number previews.
  - Fixed implicit animation bugs causing crashes during resizing.
  - General performance improvements and bug fixes.

## 1.1.1

- **Search Enhancements**:
  - Added Surah name search (prioritized in results).
  - **Enhanced Search Functionality**:
  - Prioritized Surah names in search results with stylized calligraphic glyphs.
  - Implemented a robust Surah-to-glyph mapping logic that correctly identifies Surahs even when multiple Surahs start on the same page (e.g., Al-Ikhlas, Al-Falaq, An-Nas).
  - Tapping a Surah result accurately navigates to its specific starting page.
- **Improved UI Customization**:
  - Refactored color parameters for granular control.
  - Added parameters: `topBarTextColor`, `pageNumberColor`, `searchResultGroupTitleColor`, `searchSheetIconsColor`, `searchFieldHintTextColor`, `searchFieldTextColor`, `searchFieldHandleColor`, `searchSheetBackgroundColor`, `searchSheetDarkBackgroundColor`, `searchFieldBackgroundColor`, `searchFieldDarkBackgroundColor`, and `searchSheetHeightMultiplier`.
  - Upgraded `themeModeAdaption` to apply consistently across all text, icons, and background elements.
- **Search UI Enhancements**:
  - Added centered result count headings for Surahs and Verses (e.g., "عدد نتائج السور: ١٢").
  - Resolved persistent highlighting bug when clearing selection and navigating back.
- **Optimization**:
  - Granular color control for different search result elements (verse vs. info).

## 1.1.0

- **Integrated Search Functionality**:
  - Added a modern Search UI (Top Sheet Overlay).
  - Middle-positioned search icon in the top bar.
  - Arabic Surah names and page numbers in search results.
  - Smooth navigation and immediate ayah highlighting from search results.
- **CLI Enhancements**:
  - Upgraded `quran_assets_cli` to support dual repositories (pages and fonts).
  - Automated registration of 605 fonts in `pubspec.yaml`.
  - Added `suraNameFont` mapping for `QCF_P000.TTF`.
  - Added portability fallbacks (git, curl, http) to CLI.
- **Data Reorganization**:
  - Consolidated all data modules into `lib/data/`.
- **Bug Fixes**:
  - Fixed highlight rendering issue after navigation.
  - Added SafeArea support for search overlay.

## 1.0.5

- TextColor Attribute fix.

### 1.0.4

- Update installation instructions.
- CLI & version bugs fix.

### 1.0.3

- Update CLI from quran_pages_cli to quran_assets_cli.
- Bugs fix.

### 1.0.2

- quran_pages_cli bug fix.

### 1.0.1

- Edit some variables names.
- Sura Name and Juz Number in top bar are clickable now!

### 1.0.0

- First initial stable release of **quran_pages_with_ayah_detector**.
- Fix bugs and logic.
- Ready to be integrated into other Flutter apps.
- Added Top Bar and Page Number Bottom Bar.
- Added scroll mode on height over-decrease.

## Beta Releases

### 0.1.2

- Bug fix.

### 0.1.1

- Ayah Selection highlight fix.
- Highlight customizations availability.

### 0.1.0

- Added UI customizations and Ayah long-press splash effect.

## Alpha Releases

### Alpha 0.0.2

- Internal testing and optimization.
- Integrating executable command for cloning QuranPages easily to your project.
- Handling assets installing and `pubspec.yaml` modifying.

### Alpha 0.0.1

- Under-testing version.
- Core ayah detection logic implemented.
- Basic logic for QuranPageView & pages repo.
