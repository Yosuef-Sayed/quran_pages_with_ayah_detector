## Support Me

If you enjoy my work and want to support me, you can contribute via [Patreon](https://www.patreon.com/CodeJoint), [PayPal](https://paypal.me/yosfsyd), or [Buy me a coffee](https://www.buymeacoffee.com/youssef_sayed).  
Your support helps me keep creating and improving my projects!

[![Support me on Patreon](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://www.patreon.com/CodeJoint)
[<img src="https://img.shields.io/badge/Donate-PayPal-blue?style=for-the-badge&logo=paypal" width="300" />](https://paypal.me/yosfsyd)
[<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" width="180" />](https://www.buymeacoffee.com/youssef_sayed)

# Quran Pages with Ayah Detector

A Flutter package to display Quran pages (image-based) with tapable/selectable ayahs. This package also includes a modern Search UI and an Assets CLI tool for easy configuration.

## Features

- **Quran Page Rendering**: Display full Quran pages with high-quality images.
- **Ayah Detection**: Tap or long-press on any ayah to get its Surah/Ayah number and highlighted selection.
- **Search Functionality**: A built-in search overlay that allows users to find verses across the entire Quran and navigate directly to them.
- **Customizable UI**: Fully themeable components, including search input, status bar integration (SafeArea), and highlight colors.
- **Assets CLI**: Automated tool to fetch page images and fonts from remote repositories and configure them in `pubspec.yaml`.

## Installation

### 1. Make sure you're using flutter_lints v6

```yaml
dev_dependencies:
  flutter_lints: ^6.0.0
```

### 2. Add to pubspec.yaml

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  quran_pages_with_ayah_detector: ^1.1.1
```

or use

```bash
flutter pub add quran_pages_with_ayah_detector
```

## Setup (Assets CLI)

To fetch the required Quran pages (604 images) and fonts (605 files), use the included CLI tool:

```bash
# Register the CLI
dart pub global activate --source path ./bin

# Run the fetch command
quran_assets_cli fetch-assets --pages-dest assets/pages --fonts-dest assets/fonts -y
```

or

```bash
dart run quran_pages_with_ayah_detector:quran_assets_cli fetch-assets
```

This will:

1. Fetch 604 page images from the official repository.
2. Fetch 605 Quranic fonts.
3. Automatically update your `pubspec.yaml` with all 605 font declarations and asset paths.

## Preview

Should look like that in your project after installing the package & required assets:

![Preview](quranPageView.png)

## Usage

```dart
import 'package:quran_pages_with_ayah_detector/quran_pages_with_ayah_detector.dart';

// ... inside your widget tree
QuranPageView(
  onAyahTap: (surah, ayah, page) {
    print('Tapped on Surah $surah, Ayah $ayah on Page $page');
  },
  // Customization Examples:
  quranTextColor: Colors.black87,
  topBarTextColor: Colors.blueAccent,
  searchSheetIconsColor: Colors.blueAccent,
  searchFieldHintTextColor: Colors.grey,
  searchFieldTextColor: Colors.black,
  searchFieldHandleColor: Colors.blue,
  searchSheetBackgroundColor: Colors.white,
  searchSheetDarkBackgroundColor: Color(0xFF1E1E1E),
  searchFieldBackgroundColor: Color(0xFFF5F5F5),
  searchFieldDarkBackgroundColor: Color(0xFF2C2C2C),
  searchSheetHeightMultiplier: 0.6, // 60% of screen height
  pageNumberColor: Colors.grey,
  searchResultGroupTitleColor: Colors.black87,
  themeModeAdaption: true, // Automatically adapt colors for Dark/Light mode
)
```

## UI Customization

The `QuranPageView` offers extensive customization options for colors and layout:

| Parameter                        | Default             | Description                                                                                  |
| -------------------------------- | ------------------- | -------------------------------------------------------------------------------------------- |
| `quranTextColor`                 | `Colors.black`      | The color applied to the Quran page images.                                                  |
| `topBarTextColor`                | `Colors.black`      | Color for Surah and Juz names in the top bar.                                                |
| `pageNumberColor`                | `Colors.black`      | Color for the page number text at the bottom.                                                |
| `searchSheetIconsColor`          | `Colors.black`      | Color for icons inside the search sheet.                                                     |
| `searchFieldHintTextColor`       | `Colors.grey`       | Hint text color in the search field.                                                         |
| `searchFieldTextColor`           | `Colors.black`      | Input text color in the search field.                                                        |
| `searchFieldHandleColor`         | `Colors.black`      | Cursor and selection handle color.                                                           |
| `searchSheetBackgroundColor`     | `Colors.white`      | Background color for the search sheet (Light).                                               |
| `searchSheetDarkBackgroundColor` | `Color(0xFF1E1E1E)` | Background color for the search sheet (Dark).                                                |
| `searchFieldBackgroundColor`     | `Color(0xFFF5F5F5)` | Background color for the search field (Light).                                               |
| `searchFieldDarkBackgroundColor` | `Color(0xFF2C2C2C)` | Background color for the search field (Dark).                                                |
| `searchResultGroupTitleColor`    | `Colors.black87`    | Color for the result count titles in search.                                                 |
| `searchSheetHeightMultiplier`    | `0.4`               | Max height of the search results sheet (0.0 to 1.0).                                         |
| `themeModeAdaption`              | `true`              | If true, colors automatically toggle between black/white or light/dark pairs based on theme. |
| `highlightColor`                 | `Colors.black`      | Color used to highlight the selected ayah.                                                   |
