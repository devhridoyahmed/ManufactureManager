import 'package:flutter/material.dart';

import '../../repositories/recipe_repository.dart';
import 'add_recipe_screen.dart';

class RecipeDetailsScreen extends StatefulWidget {
  const RecipeDetailsScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  final RecipeRepository _recipeRepository = RecipeRepository();

  Map<String, Object?>? _recipe;
  List<Map<String, Object?>> _ingredients = [];

  double _materialCost = 0;
  double _labourCost = 0;
  double _totalCost = 0;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recipe = await _recipeRepository.getRecipe(widget.recipeId);

      if (recipe == null) {
        throw StateError('Recipe not found.');
      }

      final ingredients = await _recipeRepository.getRecipeIngredients(
        widget.recipeId,
      );

      final cost = await _recipeRepository.calculateRecipeCost(widget.recipeId);

      if (!mounted) {
        return;
      }

      setState(() {
        _recipe = recipe;
        _ingredients = ingredients;
        _materialCost = cost['materialCost'] ?? 0;
        _labourCost = cost['labourCost'] ?? 0;
        _totalCost = cost['totalCost'] ?? 0;
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

  Future<void> _editRecipe() async {
    if (_recipe == null) {
      return;
    }

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddRecipeScreen(recipeId: widget.recipeId),
      ),
    );

    if (saved == true) {
      await _loadRecipe();
    }
  }

  Future<void> _deleteRecipe() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Recipe'),
          content: const Text('Are you sure you want to delete this recipe?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _recipeRepository.deleteRecipe(widget.recipeId);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete recipe: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe?['name'] as String? ?? 'Recipe Details'),
        actions: [
          if (!_isLoading && _recipe != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editRecipe();
                }

                if (value == 'delete') {
                  _deleteRecipe();
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ];
              },
            ),
        ],
      ),
      body: _buildBody(),
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
                'Could not load recipe.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRecipe,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recipe == null) {
      return const Center(child: Text('Recipe not found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadRecipe,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildRecipeHeader(),
          const SizedBox(height: 16),
          _buildIngredientsSection(),
          const SizedBox(height: 16),
          _buildCostSection(),
          const SizedBox(height: 16),
          _buildLabourSection(),
          if (_recipe!['notes'] != null &&
              (_recipe!['notes'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipeHeader() {
    final String name = _recipe!['name'] as String? ?? 'Unnamed Recipe';

    final String? description = _recipe!['description'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_ingredients.isEmpty)
              const Text('No materials added to this recipe.')
            else
              ..._ingredients.map((ingredient) {
                final String materialName =
                    ingredient['material_name'] as String? ??
                    ingredient['component_recipe_name'] as String? ??
                    'Unknown material';

                final double quantity =
                    (ingredient['quantity'] as num?)?.toDouble() ?? 0;

                final String symbol =
                    ingredient['unit_symbol'] as String? ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          materialName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text('${_formatNumber(quantity)} $symbol'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCostRow('Material Cost', _materialCost),
            const SizedBox(height: 12),
            _buildCostRow('Labour Cost', _labourCost),
            const Divider(height: 24),
            _buildCostRow(
              'Total Manufacturing Cost',
              _totalCost,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabourSection() {
    final double labourHours =
        (_recipe!['labour_hours'] as num?)?.toDouble() ?? 0;

    final double labourRate =
        (_recipe!['labour_rate'] as num?)?.toDouble() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Labour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Hours', '${_formatNumber(labourHours)} hours'),
            const SizedBox(height: 8),
            _buildInfoRow('Rate', '৳${_formatNumber(labourRate)} / hour'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    final String? notes = _recipe!['notes'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (notes != null && notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double value, {bool isTotal = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
            softWrap: true,
          ),
        ),
        const SizedBox(width: 24),
        Text(
          '৳${_formatNumber(value)}',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
