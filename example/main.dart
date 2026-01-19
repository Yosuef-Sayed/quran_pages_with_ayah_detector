import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:quran_pages_with_ayah_detector/quran_pages_with_ayah_detector.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      // theme: ThemeData.dark(), //? Use ThemeModes with themeModeAdaption = true
      home: Scaffold(
        body: QuranPageView(
          /// ALL IMAGES IN "assets/pages/1.png~604.png"
          /// Default path. Change if needed based on images path
          pageImagePath: "assets/pages/",
          debuggingMode: false, // Set to true to see ayah bounding boxes
          themeModeAdaption: true, // Automatically adapt to dark mode
          showPageTopBar: true,
          showPageNumber: true,
          showSearchIcon: true, // Enable the new search feature
          searchHintText: "Search for verses...",
          searchSheetBackgroundColor: Colors.white,
          searchResultTextColor: Colors.black87,
          searchResultInfoColor: Colors.grey, // Custom info text color
          searchResultSelectionColor:
              Colors.teal.withOpacity(0.1), // Custom selection color
          searchIconColor: Colors.teal,
          highlightColor: Colors.teal,
          // NOTE: The search feature requires QCF fonts to be registered in pubspec.yaml.
          // The 'quran_assets_cli' tool handles this automatically.
          highlightDuration: const Duration(milliseconds: 300),
          onAyahTap: (sura, ayah, pageNumber) {
            log("Sura: $sura, Ayah: $ayah, Page: $pageNumber");
          },
          onSuraNameTap: () {
            log("Sura Name Tapped");
          },
          onJuzNumberTap: () {
            log("Juz Number Tapped");
          },
        ),
      ),
    );
  }
}
