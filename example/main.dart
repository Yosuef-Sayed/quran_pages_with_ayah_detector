import 'package:flutter/material.dart';
import 'package:quran_pages_with_ayah_detector/quran_pages_with_ayah_detector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QuranPageView(
        onAyahTap: (sura, ayah, page) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Tapped Sura $sura, Ayah $ayah, Page $page')),
          );
        },
      ),
    );
  }
}
