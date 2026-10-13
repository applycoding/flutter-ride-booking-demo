import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quay_rides/core/theme.dart';
import 'package:quay_rides/ui/home_screen.dart';

class QuayApp extends StatelessWidget {
  const QuayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quay',
      debugShowCheckedModeBanner: false,
      theme: quayTheme(),
      home: const HomeScreen(),
    );
  }
}

class QuayRoot extends StatelessWidget {
  const QuayRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: QuayApp());
  }
}
