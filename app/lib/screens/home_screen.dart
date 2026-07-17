import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'fridge_screen.dart';
import 'ingredient_similarity_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'scan_screen.dart';
import 'shopping_list_screen.dart';
import 'more_hub_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/responsive_container.dart';
import '../widgets/thrifty_chef_logo.dart';

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
    (icon: Icons.apps_outlined, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    final state = context.watch<AppState>();
    const pages = [
      RecommendationsScreen(),
      FridgeScreen(),
      ScanScreen(),
      IngredientSimilarityScreen(),
      MoreHubScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        toolbarHeight: 76,
        title: const ThriftyChefLogo.compact(),
        titleSpacing: 8,
        centerTitle: false,
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Center(child: ApiStatusIndicator(compact: true)),
          ),
          IconButton(
            tooltip: state.themeMode == 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(state.themeMode == 'dark' ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () {
              state.setThemeMode(state.themeMode == 'dark' ? 'light' : 'dark');
            },
          ),
          IconButton(
            tooltip: 'Shopping list',
            icon: Badge(
              isLabelVisible: state.shoppingList.where((i) => !i.checked).isNotEmpty,
              label: Text('${state.shoppingList.where((i) => !i.checked).length}'),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
            ),
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
              groupAlignment: -0.85,
              minWidth: 78,
              minExtendedWidth: 160,
              indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              destinations: _tabs
                  .map(
                    (t) => NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.icon),
                      label: Text(t.label),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  )
                  .toList(),
            ),
            VerticalDivider(width: 1, thickness: 1, color: AppTheme.cardBorder),
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
