import 'package:flutter/material.dart';

import '../../repositories/recipe_repository.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key, this.recipeId});

  final String? recipeId;

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final RecipeRepository _recipeRepository = RecipeRepository();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _labourHoursController = TextEditingController(
    text: '0',
  );

  final TextEditingController _labourRateController = TextEditingController(
    text: '0',
  );

  final TextEditingController _notesController = TextEditingController();

  List<Map<String, Object?>> _materials = [];
  List<Map<String, Object?>> _recipes = [];

  final List<_RecipeIngredientInput> _ingredients = [];

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.recipeId != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _loadRecipeForEditing();
    } else {
      _loadMaterials();
    }
  }

  Future<void> _loadRecipeForEditing() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final materials = await _recipeRepository.getAvailableMaterials();

      final recipes = await _recipeRepository.getAvailableRecipes(
        excludeRecipeId: widget.recipeId,
      );

      final recipe = await _recipeRepository.getRecipe(widget.recipeId!);

      if (recipe == null) {
        throw StateError('Recipe not found.');
      }

      final ingredients = await _recipeRepository.getRecipeIngredients(
        widget.recipeId!,
      );

      _materials = materials;
      _recipes = recipes;

      _nameController.text = recipe['name'] as String? ?? '';

      _descriptionController.text = recipe['description'] as String? ?? '';

      _labourHoursController.text =
          ((recipe['labour_hours'] as num?)?.toDouble() ?? 0).toString();

      _labourRateController.text =
          ((recipe['labour_rate'] as num?)?.toDouble() ?? 0).toString();

      _notesController.text = recipe['notes'] as String? ?? '';

      for (final ingredient in ingredients) {
        final input = _RecipeIngredientInput();

        final String? materialId = ingredient['material_id'] as String?;

        final String? componentRecipeId =
            ingredient['component_recipe_id'] as String?;

        if (materialId != null) {
          input.type = _IngredientType.material;

          input.materialId = materialId;

          input.unitName = ingredient['material_unit_name'] as String?;

          input.unitSymbol = ingredient['material_unit_symbol'] as String?;
        } else if (componentRecipeId != null) {
          input.type = _IngredientType.recipe;

          input.componentRecipeId = componentRecipeId;

          input.unitName = ingredient['unit_name'] as String?;

          input.unitSymbol = ingredient['unit_symbol'] as String?;
        }

        input.unitId = ingredient['unit_id'] as String?;

        input.quantityController.text =
            ((ingredient['quantity'] as num?)?.toDouble() ?? 0).toString();

        _ingredients.add(input);
      }

      if (_ingredients.isEmpty) {
        _addIngredient();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load recipe: $error')));
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await _recipeRepository.getAvailableMaterials();

      final recipes = await _recipeRepository.getAvailableRecipes();

      if (!mounted) {
        return;
      }

      setState(() {
        _materials = materials;
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
        SnackBar(content: Text('Could not load materials: $error')),
      );
    }
  }

  void _addIngredient() {
    if (_materials.isEmpty && _recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a material or recipe first.')),
      );
      return;
    }

    setState(() {
      _ingredients.insert(0, _RecipeIngredientInput());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      final ingredient = _ingredients.removeAt(index);

      ingredient.dispose();
    });
  }

  void _changeIngredientType(
    _RecipeIngredientInput ingredient,
    _IngredientType? type,
  ) {
    if (type == null) {
      return;
    }

    setState(() {
      ingredient.type = type;

      ingredient.materialId = null;
      ingredient.componentRecipeId = null;
      ingredient.unitId = null;
      ingredient.unitName = null;
      ingredient.unitSymbol = null;
    });
  }

  void _selectMaterial(_RecipeIngredientInput ingredient, String? materialId) {
    if (materialId == null) {
      return;
    }

    final material = _materials.firstWhere((item) => item['id'] == materialId);

    setState(() {
      ingredient.materialId = materialId;
      ingredient.componentRecipeId = null;

      ingredient.unitId = material['unit_id'] as String?;

      ingredient.unitName = material['unit_name'] as String?;

      ingredient.unitSymbol = material['unit_symbol'] as String?;
    });
  }

  void _selectRecipe(_RecipeIngredientInput ingredient, String? recipeId) {
    if (recipeId == null) {
      return;
    }

    setState(() {
      ingredient.materialId = null;
      ingredient.componentRecipeId = recipeId;

      ingredient.unitId = 'unit_pc';
      ingredient.unitName = 'Piece';
      ingredient.unitSymbol = 'pc';
    });
  }

  double get _labourHours {
    return double.tryParse(_labourHoursController.text.trim()) ?? 0;
  }

  double get _labourRate {
    return double.tryParse(_labourRateController.text.trim()) ?? 0;
  }

  double get _labourCost {
    return _labourHours * _labourRate;
  }

  Future<void> _saveRecipe() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one material or recipe component.'),
        ),
      );
      return;
    }

    for (final ingredient in _ingredients) {
      if (!ingredient.isValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete all ingredient entries.'),
          ),
        );
        return;
      }
    }

    final double labourHours =
        double.tryParse(_labourHoursController.text.trim()) ?? 0;

    final double labourRate =
        double.tryParse(_labourRateController.text.trim()) ?? 0;

    setState(() {
      _isSaving = true;
    });

    try {
      if (!_isEditing) {
        final String recipeId = await _recipeRepository.createRecipe(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          labourHours: labourHours,
          labourRate: labourRate,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        for (final ingredient in _ingredients) {
          await _saveIngredient(recipeId, ingredient);
        }
      } else {
        await _recipeRepository.updateRecipe(
          recipeId: widget.recipeId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          labourHours: labourHours,
          labourRate: labourRate,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        final existingIngredients = await _recipeRepository
            .getRecipeIngredients(widget.recipeId!);

        for (final ingredient in existingIngredients) {
          await _recipeRepository.deleteIngredient(ingredient['id'] as String);
        }

        for (final ingredient in _ingredients) {
          await _saveIngredient(widget.recipeId!, ingredient);
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Recipe updated successfully.'
                : 'Recipe created successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save recipe: $error')));
    }
  }

  Future<void> _saveIngredient(
    String recipeId,
    _RecipeIngredientInput ingredient,
  ) async {
    await _recipeRepository.addIngredient(
      recipeId: recipeId,
      materialId: ingredient.type == _IngredientType.material
          ? ingredient.materialId
          : null,
      componentRecipeId: ingredient.type == _IngredientType.recipe
          ? ingredient.componentRecipeId
          : null,
      quantity: ingredient.quantity,
      unitId: ingredient.unitId!,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _labourHoursController.dispose();
    _labourRateController.dispose();
    _notesController.dispose();

    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Recipe' : 'Add Recipe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildBasicInformation(),

                  const SizedBox(height: 24),

                  _buildIngredientsSection(),

                  const SizedBox(height: 24),

                  _buildLabourSection(),

                  const SizedBox(height: 24),

                  _buildNotesSection(),

                  const SizedBox(height: 32),

                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recipe Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Recipe Name',
            hintText: 'Example: Macrame Leaf Hanging',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Recipe name is required.';
            }

            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Materials & Components',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _isSaving ? null : _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (_ingredients.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No materials or recipe components added yet.',
              textAlign: TextAlign.center,
            ),
          ),

        ...List.generate(_ingredients.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildIngredientCard(index, _ingredients[index]),
          );
        }),
      ],
    );
  }

  Widget _buildIngredientCard(int index, _RecipeIngredientInput ingredient) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_IngredientType>(
                    initialValue: ingredient.type,
                    decoration: const InputDecoration(
                      labelText: 'Ingredient Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _IngredientType.material,
                        child: Text('Raw Material'),
                      ),
                      DropdownMenuItem(
                        value: _IngredientType.recipe,
                        child: Text('Recipe Component'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            _changeIngredientType(ingredient, value);
                          },
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _removeIngredient(index);
                        },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (ingredient.type == _IngredientType.material)
              _buildMaterialSelector(ingredient),

            if (ingredient.type == _IngredientType.recipe)
              _buildRecipeSelector(ingredient),

            const SizedBox(height: 12),

            TextFormField(
              controller: ingredient.quantityController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quantity',
                suffixText: ingredient.unitSymbol ?? '',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final quantity = double.tryParse(value?.trim() ?? '');

                if (quantity == null || quantity <= 0) {
                  return 'Enter a valid quantity.';
                }

                return null;
              },
            ),

            if (ingredient.type == _IngredientType.recipe &&
                ingredient.componentRecipeId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'This uses the complete recipe as a component.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialSelector(_RecipeIngredientInput ingredient) {
    return DropdownButtonFormField<String>(
      initialValue: ingredient.materialId,
      decoration: const InputDecoration(
        labelText: 'Raw Material',
        border: OutlineInputBorder(),
      ),
      items: _materials.map((material) {
        return DropdownMenuItem<String>(
          value: material['id'] as String,
          child: Text(material['name'] as String),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              _selectMaterial(ingredient, value);
            },
      validator: (value) {
        if (ingredient.type == _IngredientType.material && value == null) {
          return 'Select a raw material.';
        }

        return null;
      },
    );
  }

  Widget _buildRecipeSelector(_RecipeIngredientInput ingredient) {
    return DropdownButtonFormField<String>(
      initialValue: ingredient.componentRecipeId,
      decoration: const InputDecoration(
        labelText: 'Recipe Component',
        border: OutlineInputBorder(),
      ),
      items: _recipes.map((recipe) {
        return DropdownMenuItem<String>(
          value: recipe['id'] as String,
          child: Text(recipe['name'] as String),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              _selectRecipe(ingredient, value);
            },
      validator: (value) {
        if (ingredient.type == _IngredientType.recipe && value == null) {
          return 'Select a recipe component.';
        }

        return null;
      },
    );
  }

  Widget _buildLabourSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Labour',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _labourHoursController,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'Labour Hours',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final hours = double.tryParse(value?.trim() ?? '');

                  if (hours == null || hours < 0) {
                    return 'Enter valid hours.';
                  }

                  return null;
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: TextFormField(
                controller: _labourRateController,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'Rate / Hour',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final rate = double.tryParse(value?.trim() ?? '');

                  if (rate == null || rate < 0) {
                    return 'Enter valid rate.';
                  }

                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Labour Cost',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '৳${_formatNumber(_labourCost)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return TextFormField(
      controller: _notesController,
      enabled: !_isSaving,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Notes',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveRecipe,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _isSaving
              ? 'Saving...'
              : _isEditing
              ? 'Update Recipe'
              : 'Save Recipe',
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

enum _IngredientType { material, recipe }

class _RecipeIngredientInput {
  _IngredientType type = _IngredientType.material;

  String? materialId;
  String? componentRecipeId;

  String? unitId;
  String? unitName;
  String? unitSymbol;

  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );

  double get quantity {
    return double.tryParse(quantityController.text.trim()) ?? 0;
  }

  bool isValid() {
    if (quantity <= 0 || unitId == null) {
      return false;
    }

    if (type == _IngredientType.material) {
      return materialId != null;
    }

    if (type == _IngredientType.recipe) {
      return componentRecipeId != null;
    }

    return false;
  }

  void dispose() {
    quantityController.dispose();
  }
}
