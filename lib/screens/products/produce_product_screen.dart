import 'package:flutter/material.dart';

import '../../repositories/product_repository.dart';
import '../../repositories/recipe_repository.dart';

class ProduceProductScreen extends StatefulWidget {
  const ProduceProductScreen({super.key});

  @override
  State<ProduceProductScreen> createState() =>
      _ProduceProductScreenState();
}

class _ProduceProductScreenState
    extends State<ProduceProductScreen> {
  final ProductRepository _productRepository =
      ProductRepository();

  final RecipeRepository _recipeRepository =
      RecipeRepository();

  final TextEditingController _productNameController =
      TextEditingController();

  final TextEditingController _makerNameController =
      TextEditingController();

  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  final TextEditingController
      _productionExpenseController =
      TextEditingController(text: '0');

  final TextEditingController _profitMarginController =
      TextEditingController(text: '40');

  List<Map<String, Object?>> _recipes =
      <Map<String, Object?>>[];

  String? _selectedRecipeId;

  bool _isLoading = true;
  bool _isSaving = false;

  double _materialCostPerUnit = 0;
  double _labourCostPerUnit = 0;
  double _recipeCostPerUnit = 0;
  double _totalProductionCost = 0;
  double _totalCostPerUnit = 0;
  double _targetSellingPrice = 0;

  @override
  void initState() {
    super.initState();

    _loadRecipes();

    _profitMarginController.addListener(
      _calculateTargetPrice,
    );

    _productionExpenseController.addListener(
      _calculateTotalCost,
    );
  }

  Future<void> _loadRecipes() async {
    try {
      final List<Map<String, Object?>> recipes =
          await _productRepository.getAvailableRecipes();

      if (!mounted) {
        return;
      }

      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load recipes: $error',
          ),
        ),
      );
    }
  }

  Future<void> _onRecipeChanged(
    String? recipeId,
  ) async {
    if (recipeId == null) {
      return;
    }

    final Map<String, Object?> selectedRecipe =
        _recipes.firstWhere(
      (recipe) => recipe['id'] == recipeId,
    );

    final String recipeName =
        selectedRecipe['name'] as String? ?? '';

    setState(() {
      _selectedRecipeId = recipeId;

      _productNameController.text = recipeName;

      _materialCostPerUnit = 0;
      _labourCostPerUnit = 0;
      _recipeCostPerUnit = 0;
      _totalProductionCost = 0;
      _totalCostPerUnit = 0;
      _targetSellingPrice = 0;
    });

    try {
      final Map<String, double> cost =
          await _recipeRepository.calculateRecipeCost(
        recipeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _materialCostPerUnit =
            cost['materialCost'] ?? 0;

        _labourCostPerUnit =
            cost['labourCost'] ?? 0;

        _recipeCostPerUnit =
            cost['totalCost'] ?? 0;
      });

      _calculateTotalCost();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not calculate recipe cost: $error',
          ),
        ),
      );
    }
  }

  void _calculateTotalCost() {
    final double quantity =
        double.tryParse(
              _quantityController.text.trim(),
            ) ??
            0;

    final double productionExpense =
        double.tryParse(
              _productionExpenseController.text.trim(),
            ) ??
            0;

    if (quantity <= 0) {
      setState(() {
        _totalProductionCost = 0;
        _totalCostPerUnit = 0;
      });

      _calculateTargetPrice();
      return;
    }

    final double recipeCostPerUnit =
        _recipeCostPerUnit;

    final double recipeCostForBatch =
        recipeCostPerUnit * quantity;

    final double totalProductionCost =
        recipeCostForBatch + productionExpense;

    final double totalCostPerUnit =
        totalProductionCost / quantity;

    setState(() {
      _totalProductionCost = totalProductionCost;
      _totalCostPerUnit = totalCostPerUnit;
    });

    _calculateTargetPrice();
  }

  void _calculateTargetPrice() {
    final double margin =
        double.tryParse(
              _profitMarginController.text.trim(),
            ) ??
            0;

    if (margin >= 100 || margin < 0) {
      setState(() {
        _targetSellingPrice = 0;
      });

      return;
    }

    if (_totalCostPerUnit <= 0) {
      setState(() {
        _targetSellingPrice = 0;
      });

      return;
    }

    final double targetPrice =
        _totalCostPerUnit /
            (1 - (margin / 100));

    setState(() {
      _targetSellingPrice = targetPrice;
    });
  }

  Future<void> _produceProduct() async {
    if (_selectedRecipeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a recipe.',
          ),
        ),
      );

      return;
    }

    final String productName =
        _productNameController.text.trim();

    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a product name.',
          ),
        ),
      );

      return;
    }

    final double quantity =
        double.tryParse(
              _quantityController.text.trim(),
            ) ??
            0;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid production quantity.',
          ),
        ),
      );

      return;
    }

    final double productionExpense =
        double.tryParse(
              _productionExpenseController.text.trim(),
            ) ??
            0;

    if (productionExpense < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Production expense cannot be negative.',
          ),
        ),
      );

      return;
    }

    if (_totalProductionCost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Production cost must be greater than zero.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Current product workflow uses Piece as
      // the finished-product unit.
      const String productUnitId = 'unit_pc';

      await _productRepository.produceProduct(
        recipeId: _selectedRecipeId!,
        productName: productName,
        unitId: productUnitId,
        quantity: quantity,
        makerName:
            _makerNameController.text.trim().isEmpty
                ? null
                : _makerNameController.text.trim(),
        materialCost: _materialCostPerUnit,
        labourCost: _labourCostPerUnit,
        productionExpense: productionExpense,
        totalCost: _totalProductionCost,
        targetSellingPrice: _targetSellingPrice,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product produced successfully.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not produce product: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _makerNameController.dispose();
    _quantityController.dispose();
    _productionExpenseController.dispose();
    _profitMarginController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produce Product'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedRecipeId,
            decoration: const InputDecoration(
              labelText: 'Recipe',
              border: OutlineInputBorder(),
            ),
            items: _recipes.map((recipe) {
              return DropdownMenuItem<String>(
                value: recipe['id'] as String,
                child: Text(
                  recipe['name'] as String,
                ),
              );
            }).toList(),
            onChanged: _onRecipeChanged,
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _productNameController,
            decoration: const InputDecoration(
              labelText: 'Product Name',
              border: OutlineInputBorder(),
              helperText:
                  'You can change product name.',
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _makerNameController,
            decoration: const InputDecoration(
              labelText: "Maker's Name",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _quantityController,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onChanged: (_) {
              _calculateTotalCost();
            },
            decoration: const InputDecoration(
              labelText: 'Quantity to Produce',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Production Cost',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          _buildCostRow(
            'Material Cost / Unit',
            _materialCostPerUnit,
          ),

          const SizedBox(height: 8),

          _buildCostRow(
            'Labour Cost / Unit',
            _labourCostPerUnit,
          ),

          const SizedBox(height: 16),

          TextField(
            controller:
                _productionExpenseController,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText:
                  'Production Expense (Whole Batch)',
              border: OutlineInputBorder(),
              prefixText: '৳ ',
              helperText:
                  'expense for the entire batch.',
            ),
          ),

          const SizedBox(height: 16),

          _buildCostRow(
            'Recipe Cost / Unit',
            _recipeCostPerUnit,
          ),

          const SizedBox(height: 8),

          _buildCostRow(
            'Total Production Cost',
            _totalProductionCost,
            bold: true,
          ),

          const SizedBox(height: 8),

          _buildCostRow(
            'Total Cost / Unit',
            _totalCostPerUnit,
            bold: true,
          ),

          const SizedBox(height: 24),

          const Text(
            'Profit Target',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _profitMarginController,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Desired Profit Margin',
              border: OutlineInputBorder(),
              suffixText: '%',
              
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TARGET SELLING PRICE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '৳${_targetSellingPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                  'You can change the actual selling price later.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  _selectedRecipeId == null ||
                          _isSaving
                      ? null
                      : _produceProduct,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.precision_manufacturing,
                    ),
              label: Text(
                _isSaving
                    ? 'PRODUCING...'
                    : 'PRODUCE',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(
    String label,
    double amount, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: bold ? 20 : 16,
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}