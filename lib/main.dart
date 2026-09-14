import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'repositories/business_repository.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/materials/materials_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/recipes/recipes_screen.dart';
import 'screens/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppDatabase.instance.database;
    await BusinessRepository().getOrCreateBusiness();
  } catch (error, stackTrace) {
    debugPrint('DATABASE STARTUP ERROR: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const ManufacturingManagerApp());
}

class ManufacturingManagerApp extends StatelessWidget {
  const ManufacturingManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manufacturing Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'Dashboard',
    'Materials',
    'Recipes',
    'Products',
    'Settings',
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    MaterialsScreen(),
    RecipesScreen(),
    ProductsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Materials',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}