# Quran Pages with Ayah Detector

A Flutter package that shows Quran pages and allows detecting ayah taps.

## Important Installations

Install Quran Images using this Repo and add them to your project assets folder.
Example: pageImagePath: "asset/pages/", INCLUDE ONLY THE PATH TO ALL IMAGES.

```
https://github.com/Yosuef-Sayed/quran_pages/archive/refs/heads/main.zip
```

## Usage

```dart
QuranPageView(
  pathImagePath: "assets/pages/",
  onAyahTap: (sura, ayah, page) {
    // Custom logic when an ayah is tapped
  },
)
```
