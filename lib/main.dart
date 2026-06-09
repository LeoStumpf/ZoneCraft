import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/map_screen.dart';

void main() {
  runApp(const ProviderScope(child: ZonecraftApp()));
}

class ZonecraftApp extends StatelessWidget {
  const ZonecraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zonecraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
