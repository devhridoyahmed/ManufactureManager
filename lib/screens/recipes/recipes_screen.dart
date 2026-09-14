import 'package:flutter/material.dart';

import '../../repositories/recipe_repository.dart';
import 'add_recipe_screen.dart';
import 'recipe_details_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final RecipeRepository _recipeRepository = RecipeRepository();

  List<Map<String, Object?>> _recipes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recipes = await _recipeRepository.getRecipes();

      final List<Map<String, Object?>> recipesWithDetails = [];

      for (final recipe in recipes) {
        final String recipeId = recipe['id'] as String;

        final ingredients = await _recipeRepository.getRecipeIngredients(
          recipeId,
        );

        final cost = await _recipeRepository.calculateRecipeCost(recipeId);

        recipesWithDetails.add({
          ...recipe,
          'ingredient_count': ingredients.length,
          'total_cost': cost['totalCost'] ?? 0,
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _recipes = recipesWithDetails;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddRecipe() async {
    final bool? saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const AddRecipeScreen()));

    if (saved == true) {
      await _loadRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddRecipe,
        tooltip: 'Add Recipe',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Could not load recipes.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRecipes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadRecipes,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          return _buildRecipeCard(_recipes[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'No recipes yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first recipe to define the '
              'materials and labour needed to make a product.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openAddRecipe,
              icon: const Icon(Icons.add),
              label: const Text('Add Recipe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, Object?> recipe) {
    final String name = recipe['name'] as String? ?? 'Unnamed Recipe';

    final double labourHours =
        (recipe['labour_hours'] as num?)?.toDouble() ?? 0;

    final int ingredientCount = (recipe['ingredient_count'] as int?) ?? 0;

    final double totalCost = (recipe['total_cost'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final String recipeId = recipe['id'] as String;

          final bool? deleted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => RecipeDetailsScreen(recipeId: recipeId),
            ),
          );

          if (deleted == true) {
            await _loadRecipes();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('$ingredientCount materials'),
                  const SizedBox(width: 20),
                  const Icon(Icons.schedule_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('${_formatNumber(labourHours)} hours'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Cost',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '৳${_formatNumber(totalCost)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
