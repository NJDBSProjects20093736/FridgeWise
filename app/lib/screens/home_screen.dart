import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'fridge_screen.dart';
import 'ingredient_similarity_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'scan_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.restaurant_menu, label: 'Recipes'),
    (icon: Icons.kitchen, label: 'Fridge'),
    (icon: Icons.qr_code_scanner, label: 'Scan'),
    (icon: Icons.swap_horiz, label: 'Substitute'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    const pages = [
      RecommendationsScreen(),
      FridgeScreen(),
      ScanScreen(),
      IngredientSimilarityScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.glacierHeroGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.ac_unit, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('FridgeWise AI'),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: ApiStatusIndicator()),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide) ...[
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: _tabs
                  .map((t) => NavigationRailDestination(icon: Icon(t.icon), label: Text(t.label)))
                  .toList(),
            ),
            const VerticalDivider(width: 1, color: AppTheme.cardBorder),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: pages[_index],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: _tabs
                  .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
                  .toList(),
            ),
    );
  }
}
