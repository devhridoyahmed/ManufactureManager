import 'package:flutter/material.dart';

import '../../repositories/material_purchases_repository.dart';

class AddMaterialPurchaseScreen extends StatefulWidget {
  const AddMaterialPurchaseScreen({
    super.key,
    required this.material,
  });

  final Map<String, Object?> material;

  @override
  State<AddMaterialPurchaseScreen> createState() =>
      _AddMaterialPurchaseScreenState();
}

class _AddMaterialPurchaseScreenState
    extends State<AddMaterialPurchaseScreen> {
  final MaterialPurchasesRepository _repository =
      MaterialPurchasesRepository();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _quantityController =
      TextEditingController();

  final TextEditingController _totalCostController =
      TextEditingController();

  final TextEditingController _supplierController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  DateTime _purchaseDate = DateTime.now();

  bool _isSaving = false;

  double get _quantity {
    return double.tryParse(
          _quantityController.text.trim(),
        ) ??
        0;
  }

  double get _totalCost {
    return double.tryParse(
          _totalCostController.text.trim(),
        ) ??
        0;
  }

  double get _unitCost {
    if (_quantity <= 0) {
      return 0;
    }

    return _totalCost / _quantity;
  }

  String get _unitName {
    return widget.material['unit_name'] as String? ?? '';
  }

  String get _materialName {
    return widget.material['name'] as String? ?? 'Material';
  }

  Future<void> _selectPurchaseDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _purchaseDate = selectedDate;
    });
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double quantity = _quantity;
    final double totalCost = _totalCost;

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.createPurchase(
        materialId: widget.material['id'] as String,
        quantity: quantity,
        totalCost: totalCost,
        supplierName:
            _supplierController.text.trim().isEmpty
                ? null
                : _supplierController.text.trim(),
        purchaseDate: _purchaseDate,
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock added successfully.'),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add stock: $error',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _quantityController.addListener(_refreshUnitCost);
    _totalCostController.addListener(_refreshUnitCost);
  }

  void _refreshUnitCost() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _totalCostController.dispose();
    _supplierController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        '${_purchaseDate.day.toString().padLeft(2, '0')}/'
        '${_purchaseDate.month.toString().padLeft(2, '0')}/'
        '${_purchaseDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Stock'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _materialName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record a new purchase and increase stock.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: _quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g. 20',
                suffixText:
                    _unitName.isEmpty ? null : _unitName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final double? number =
                    double.tryParse(value?.trim() ?? '');

                if (number == null || number <= 0) {
                  return 'Enter a quantity greater than zero.';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _totalCostController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Total purchase cost',
                hintText: 'e.g. 2000',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final double? number =
                    double.tryParse(value?.trim() ?? '');

                if (number == null || number < 0) {
                  return 'Enter a valid purchase cost.';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Calculated unit cost',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '৳ ${_unitCost.toStringAsFixed(2)}'
                            '${_unitName.isEmpty ? '' : ' / $_unitName'}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_today_outlined,
              ),
              title: const Text('Purchase date'),
              subtitle: Text(formattedDate),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectPurchaseDate,
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _supplierController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Supplier',
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
                    _isSaving ? null : _savePurchase,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(),
                      )
                    : const Text('Save Purchase'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}