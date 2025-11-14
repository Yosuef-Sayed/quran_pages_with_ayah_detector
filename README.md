# Quran Pages with Ayah Detector

A Flutter package that shows Quran pages and allows detecting ayah taps.

## Important Installations

Install Quran Images using this Executable Command.
Example: pageImagePath: "asset/pages/", INCLUDE ONLY THE PATH TO ALL IMAGES.

```
dart run quran_pages_with_ayah_detector:quran_pages_cli fetch-pages
```

This command will install QuranPages to your assets/pages/ automatically and will do important modifications to your pubspec.yaml to have the assets imported and ready to use for the package.

## Usage

```dart
QuranPageView(
  pathImagePath: "assets/pages/", // Default but can be modified based on images path
  onAyahTap: (sura, ayah, page) {
    // Custom logic when an ayah is tapped
  },
)
```
