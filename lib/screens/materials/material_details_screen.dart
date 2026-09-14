import 'package:flutter/material.dart';

import '../../repositories/material_purchases_repository.dart';
import '../../repositories/materials_repository.dart';

import 'add_material_purchase_screen.dart';
import 'add_material_screen.dart';
import 'adjust_material_stock_screen.dart';
import 'material_purchase_history_screen.dart';

class MaterialDetailsScreen extends StatefulWidget {
  const MaterialDetailsScreen({super.key, required this.materialId});

  final String materialId;

  @override
  State<MaterialDetailsScreen> createState() => _MaterialDetailsScreenState();
}

class _MaterialDetailsScreenState extends State<MaterialDetailsScreen> {
  final MaterialsRepository _repository = MaterialsRepository();

  final MaterialPurchasesRepository _purchasesRepository =
      MaterialPurchasesRepository();

  bool _isLoading = true;
  bool _isLoadingStock = true;
  bool _isLoadingCost = true;

  String? _errorMessage;

  Map<String, Object?>? _material;

  double _currentStock = 0;
  double _totalPurchasedQuantity = 0;
  double _totalPurchaseCost = 0;

  @override
  void initState() {
    super.initState();

    _loadMaterial();
  }

  Future<void> _loadMaterial() async {
    setState(() {
      _isLoading = true;
      _isLoadingStock = true;
      _isLoadingCost = true;
      _errorMessage = null;
    });

    try {
      final material = await _repository.getMaterialById(widget.materialId);

      final double currentStock = await _purchasesRepository.getCurrentStock(
        widget.materialId,
      );

      final double totalPurchasedQuantity = await _purchasesRepository
          .getTotalPurchasedQuantity(widget.materialId);

      final double totalPurchaseCost = await _purchasesRepository
          .getTotalPurchaseCost(widget.materialId);

      if (!mounted) {
        return;
      }

      setState(() {
        _material = material;
        _currentStock = currentStock;
        _totalPurchasedQuantity = totalPurchasedQuantity;
        _totalPurchaseCost = totalPurchaseCost;

        _isLoading = false;
        _isLoadingStock = false;
        _isLoadingCost = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();

        _isLoading = false;
        _isLoadingStock = false;
        _isLoadingCost = false;
      });
    }
  }

  Future<void> _addStock() async {
    if (_material == null) {
      return;
    }

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddMaterialPurchaseScreen(material: _material!),
      ),
    );

    if (saved == true) {
      await _loadMaterial();
    }
  }

  Future<void> _openPurchaseHistory() async {
    if (_material == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaterialPurchaseHistoryScreen(material: _material!),
      ),
    );

    await _loadMaterial();
  }

  Future<void> _removeStock() async {
    if (_material == null) {
      return;
    }

    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdjustMaterialStockScreen(
          material: _material!,
          currentStock: _currentStock,
        ),
      ),
    );

    if (changed == true) {
      await _loadMaterial();
    }
  }

  Future<void> _editMaterial() async {
    if (_material == null) {
      return;
    }

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddMaterialScreen(material: _material)),
    );

    if (saved == true) {
      await _loadMaterial();
    }
  }

  Future<void> _deactivateMaterial() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate material?'),
          content: const Text(
            'This material will no longer appear in the active '
            'materials list.',
          ),
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
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deactivateMaterial(widget.materialId);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not deactivate material: $error')),
      );
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatMoney(double value) {
    return '৳${value.toStringAsFixed(2)}';
  }

  double get averageUnitCost {
    if (_totalPurchasedQuantity <= 0) {
      return 0;
    }

    return _totalPurchaseCost / _totalPurchasedQuantity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Details'),
        actions: [
          if (_material != null)
            IconButton(
              onPressed: _editMaterial,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
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
              const SizedBox(height: 12),
              const Text(
                'Could not load material.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMaterial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_material == null) {
      return const Center(child: Text('Material not found.'));
    }

    final String name = _material!['name'] as String? ?? 'Unnamed material';

    final String unitName = _material!['unit_name'] as String? ?? '';

    final String unitSymbol = _material!['unit_symbol'] as String? ?? '';

    final String categoryName = _material!['category_name'] as String? ?? '';

    final double minimumStock =
        (_material!['minimum_stock'] as num?)?.toDouble() ?? 0;

    final String description = _material!['description'] as String? ?? '';

    final String notes = _material!['notes'] as String? ?? '';

    final bool isLowStock = !_isLoadingStock && _currentStock <= minimumStock;

    final String stockUnit = unitSymbol.isEmpty ? unitName : unitSymbol;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  unitSymbol.isEmpty ? unitName : '$unitName ($unitSymbol)',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        _InfoCard(
          title: 'Stock',
          children: [
            _InfoRow(
              label: 'Current stock',
              value: _isLoadingStock
                  ? 'Loading...'
                  : '${_formatNumber(_currentStock)}'
                        '${stockUnit.isEmpty ? '' : ' $stockUnit'}',
              valueColor: isLowStock ? Colors.red : null,
            ),
            _InfoRow(
              label: 'Minimum stock',
              value:
                  '${_formatNumber(minimumStock)}'
                  '${stockUnit.isEmpty ? '' : ' $stockUnit'}',
            ),
            if (isLowStock && !_isLoadingStock)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stock is at or below the minimum level.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _addStock,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add Stock'),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _currentStock > 0 ? _removeStock : null,
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('Remove Stock'),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _openPurchaseHistory,
          icon: const Icon(Icons.history),
          label: const Text('Purchase History'),
        ),

        const SizedBox(height: 16),

        _InfoCard(
          title: 'Expense Summary',
          children: [
            _InfoRow(
              label: 'Total purchased',
              value: _isLoadingCost
                  ? 'Loading...'
                  : '${_formatNumber(_totalPurchasedQuantity)}'
                        '${stockUnit.isEmpty ? '' : ' $stockUnit'}',
            ),
            _InfoRow(
              label: 'Total purchase cost',
              value: _isLoadingCost
                  ? 'Loading...'
                  : _formatMoney(_totalPurchaseCost),
            ),
            _InfoRow(
              label: 'Average unit cost',
              value: _isLoadingCost
                  ? 'Loading...'
                  : _formatMoney(averageUnitCost),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _InfoCard(
          title: 'Information',
          children: [
            _InfoRow(
              label: 'Unit',
              value: unitName.isEmpty ? 'Not set' : unitName,
            ),
            _InfoRow(
              label: 'Category',
              value: categoryName.isEmpty ? 'No category' : categoryName,
            ),
          ],
        ),

        if (description.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(title: 'Description', children: [Text(description)]),
        ],

        if (notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(title: 'Notes', children: [Text(notes)]),
        ],

        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: _editMaterial,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Material'),
        ),

        const SizedBox(height: 12),

        TextButton.icon(
          onPressed: _deactivateMaterial,
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Deactivate Material'),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
