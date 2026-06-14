import 'package:flutter/material.dart';

void main() {
  runApp(const ManajudgeApp());
}

/// Root of the manajudge companion app.
///
/// Phase 0 placeholder: the app builds and launches on Android and iOS but ships
/// no user-facing behavior yet. The dark theme, design system and the three
/// surfaces (Companion, Judge, Card Search) arrive in later slices.
class ManajudgeApp extends StatelessWidget {
  const ManajudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'manajudge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6E56CF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PlaceholderScreen(),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  static const _surfaces = <(IconData, String)>[
    (Icons.casino_outlined, 'Companion'),
    (Icons.balance_outlined, 'Judge'),
    (Icons.search_outlined, 'Card Search'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('⚖️ manajudge', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Companion app — coming soon',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (icon, label) in _surfaces)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Icon(icon, size: 32, color: theme.colorScheme.primary),
                        const SizedBox(height: 8),
                        Text(label, style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
