import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:quran_pages_with_ayah_detector/quran_pages_with_ayah_detector.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: QuranPageView(
          //! ALL IMAGES IN "assets/pages/1.png~604.png"
          pageImagePath: "assets/pages/",
          onAyahTap: (sura, ayah, pageNumber) {
            log("Sura: ${sura.toString()}");
            log("Ayah: ${ayah.toString()}");
            log("PageNumber: ${pageNumber.toString()}");
          },
        ),
      ),
    );
  }
}
