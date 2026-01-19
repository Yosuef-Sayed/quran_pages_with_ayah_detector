# Changelog

## Initial Releases

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
