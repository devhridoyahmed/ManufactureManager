import 'package:flutter/material.dart';

import '../../repositories/materials_repository.dart';

class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({
    super.key,
    this.material,
  });

  final Map<String, Object?>? material;

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  final MaterialsRepository _repository = MaterialsRepository();

  bool get _isEditing => widget.material != null;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _minimumStockController =
      TextEditingController(text: '0');

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  List<Map<String, Object?>> _units = [];
  List<Map<String, Object?>> _categories = [];

  String? _selectedUnitId;
  String? _selectedCategoryId;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final units = await _repository.getUnits();
      final categories = await _repository.getCategories();

      String? selectedUnitId;
      String? selectedCategoryId;

      if (_isEditing) {
        final material = widget.material!;

        final String? existingUnitId =
            material['unit_id'] as String?;

        final String? existingCategoryId =
            material['category_id'] as String?;

        if (units.any(
          (unit) => unit['id'] == existingUnitId,
        )) {
          selectedUnitId = existingUnitId;
        }

        if (categories.any(
          (category) => category['id'] == existingCategoryId,
        )) {
          selectedCategoryId = existingCategoryId;
        }

        _nameController.text =
            material['name'] as String? ?? '';

        _minimumStockController.text =
            ((material['minimum_stock'] as num?)?.toDouble() ?? 0)
                .toString();

        _descriptionController.text =
            material['description'] as String? ?? '';

        _notesController.text =
            material['notes'] as String? ?? '';
      } else {
        if (units.isNotEmpty) {
          selectedUnitId = units.first['id'] as String;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _units = units;
        _categories = categories;
        _selectedUnitId = selectedUnitId;
        _selectedCategoryId = selectedCategoryId;
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
            'Could not load form data: $error',
          ),
        ),
      );
    }
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a unit.'),
        ),
      );
      return;
    }

    final double minimumStock =
        double.tryParse(
              _minimumStockController.text.trim(),
            ) ??
            0;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await _repository.updateMaterial(
          materialId: widget.material!['id'] as String,
          name: _nameController.text.trim(),
          unitId: _selectedUnitId!,
          minimumStock: minimumStock,
          categoryId: _selectedCategoryId,
          description:
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
          imagePath:
              widget.material!['image_path'] as String?,
        );
      } else {
        await _repository.createMaterial(
          name: _nameController.text.trim(),
          unitId: _selectedUnitId!,
          minimumStock: minimumStock,
          categoryId: _selectedCategoryId,
          description:
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Could not update material: $error'
                : 'Could not save material: $error',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minimumStockController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Material' : 'Add Material',
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Material name',
                      hintText: 'e.g. 3.5 mm Cotton Rope',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Enter a material name.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue:
                        _units.any(
                          (unit) =>
                              unit['id'] == _selectedUnitId,
                        )
                            ? _selectedUnitId
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: _units.map((unit) {
                      final String id =
                          unit['id'] as String;

                      final String name =
                          unit['name'] as String;

                      final String symbol =
                          unit['symbol'] as String;

                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          '$name ($symbol)',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUnitId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a unit.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue:
                        _categories.any(
                          (category) =>
                              category['id'] ==
                              _selectedCategoryId,
                        )
                            ? _selectedCategoryId
                            : '',
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('No category'),
                      ),
                      ..._categories.map((category) {
                        final String id =
                            category['id'] as String;

                        final String name =
                            category['name'] as String;

                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId =
                            value == null || value.isEmpty
                                ? null
                                : value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _minimumStockController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Minimum stock',
                      hintText: 'e.g. 20',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final number = double.tryParse(
                        value?.trim() ?? '',
                      );

                      if (number == null || number < 0) {
                        return 'Enter a valid stock amount.';
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
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _isSaving ? null : _saveMaterial,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(),
                            )
                          : Text(
                              _isEditing
                                  ? 'Update Material'
                                  : 'Save Material',
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}