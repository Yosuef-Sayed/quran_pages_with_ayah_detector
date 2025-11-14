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
          debuggingMode: false,
          themeModeAdaption: false,
          textColor: Colors.black,
          highlightColor: Colors.blue,
          highlightDuration: Duration(milliseconds: 100),
          onAyahTap: (sura, ayah, pageNumber) {
            log("Sura Number: ${sura.toString()}");
            log("Ayah Number: ${ayah.toString()}");
            log("Page Number: ${pageNumber.toString()}");
          },
        ),
      ),
    );
  }
}
