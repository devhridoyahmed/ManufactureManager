import 'package:flutter/material.dart';

import '../../repositories/material_purchases_repository.dart';

class AdjustMaterialStockAdjustmentScreen extends StatefulWidget {
  const AdjustMaterialStockAdjustmentScreen({
    super.key,
    required this.material,
    required this.currentStock,
  });

  final Map<String, Object?> material;
  final double currentStock;

  @override
  State<AdjustMaterialStockAdjustmentScreen> createState() =>
      _AdjustMaterialStockAdjustmentScreenState();
}

class _AdjustMaterialStockAdjustmentScreenState
    extends State<AdjustMaterialStockAdjustmentScreen> {
  final MaterialPurchasesRepository _repository =
      MaterialPurchasesRepository();

  final TextEditingController _quantityController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final List<String> _reasons = [
    'Manual correction',
    'Physical stock count',
    'Found extra stock',
    'Stock count error',
    'Other',
  ];

  String? _selectedReason;
  bool _increaseStock = true;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _materialName {
    return widget.material['name'] as String? ?? 'Material';
  }

  String get _unitName {
    final String unitSymbol =
        widget.material['unit_symbol'] as String? ?? '';

    final String unitName =
        widget.material['unit_name'] as String? ?? '';

    if (unitSymbol.isNotEmpty) {
      return unitSymbol;
    }

    return unitName;
  }

  double? get _quantity {
    final String value =
        _quantityController.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return double.tryParse(value);
  }

  double? get _resultingStock {
    final double? quantity = _quantity;

    if (quantity == null || quantity <= 0) {
      return null;
    }

    if (_increaseStock) {
      return widget.currentStock + quantity;
    }

    return widget.currentStock - quantity;
  }

  Future<void> _selectDate() async {
    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = selected;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final double? quantity = _quantity;

    if (quantity == null || quantity <= 0) {
      _showError(
        'Enter a valid quantity greater than zero.',
      );
      return;
    }

    if (!_increaseStock &&
        quantity > widget.currentStock) {
      _showError(
        'You cannot decrease stock below zero.',
      );
      return;
    }

    if (_selectedReason == null) {
      _showError(
        'Please select a reason.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.adjustStock(
        materialId: widget.material['id'] as String,
        quantity: quantity,
        increase: _increaseStock,
        reason: _selectedReason!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        movementDate: _selectedDate,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stock adjusted successfully.',
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

      _showError(
        error.toString(),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
      ),
      body: ListView(
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
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current stock: '
                    '${_formatNumber(widget.currentStock)}'
                    '${_unitName.isEmpty ? '' : ' $_unitName'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Adjustment Type',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                icon: Icon(
                  Icons.add_circle_outline,
                ),
                label: Text('Increase'),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(
                  Icons.remove_circle_outline,
                ),
                label: Text('Decrease'),
              ),
            ],
            selected: <bool>{_increaseStock},
            onSelectionChanged: _isSaving
                ? null
                : (Set<bool> selection) {
                    setState(() {
                      _increaseStock =
                          selection.first;
                    });
                  },
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _quantityController,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: 'Quantity',
              hintText: 'Example: 5',
              suffixText: _unitName.isEmpty
                  ? null
                  : _unitName,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            items: _reasons.map(
              (String reason) {
                return DropdownMenuItem<String>(
                  value: reason,
                  child: Text(reason),
                );
              },
            ).toList(),
            onChanged: _isSaving
                ? null
                : (String? value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
          ),

          const SizedBox(height: 16),

          InkWell(
            onTap: _isSaving
                ? null
                : _selectDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                ),
              ),
              child: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/'
                '${_selectedDate.month.toString().padLeft(2, '0')}/'
                '${_selectedDate.year}',
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _notesController,
            maxLines: 4,
            textCapitalization:
                TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText:
                  'Optional details about this adjustment',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          if (_resultingStock != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Stock after adjustment: '
                        '${_formatNumber(_resultingStock!)}'
                        '${_unitName.isEmpty ? '' : ' $_unitName'}',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : _save,
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
                      Icons.tune,
                    ),
              label: Text(
                _isSaving
                    ? 'Saving...'
                    : 'Save Adjustment',
              ),
            ),
          ),
        ],
      ),
    );
  }
}