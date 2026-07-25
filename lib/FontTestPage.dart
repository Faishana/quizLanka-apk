import 'package:flutter/material.dart';

class FontTestPage extends StatelessWidget {
  const FontTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Font Test")),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Poppins English",
              style: TextStyle(fontFamily: "AbhayaLibre", fontSize: 28),
            ),
            SizedBox(height: 20),
            Text(
              "අභය ලිබ්රේ",
              style: TextStyle(fontFamily: "AbhayaLibre", fontSize: 28),
            ),
          ],
        ),
      ),
    );
  }
}
