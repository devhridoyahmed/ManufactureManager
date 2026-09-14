import 'package:flutter/material.dart';

import '../../repositories/material_purchases_repository.dart';

class MaterialPurchaseHistoryScreen extends StatefulWidget {
  const MaterialPurchaseHistoryScreen({
    super.key,
    required this.material,
  });

  final Map<String, Object?> material;

  @override
  State<MaterialPurchaseHistoryScreen> createState() =>
      _MaterialPurchaseHistoryScreenState();
}

class _MaterialPurchaseHistoryScreenState
    extends State<MaterialPurchaseHistoryScreen> {
  final MaterialPurchasesRepository _repository =
      MaterialPurchasesRepository();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, Object?>> _purchases = [];

  double _currentStock = 0;
  double _totalPurchased = 0;
  double _totalCost = 0;

  String get _materialName {
    return widget.material['name'] as String? ?? 'Material';
  }

  String get _unitName {
    final String name =
        widget.material['unit_name'] as String? ?? '';

    final String symbol =
        widget.material['unit_symbol'] as String? ?? '';

    if (symbol.isEmpty) {
      return name;
    }

    return symbol;
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String materialId =
          widget.material['id'] as String;

      final purchases =
          await _repository.getPurchases(materialId);

      final currentStock =
          await _repository.getCurrentStock(materialId);

      final totalPurchased =
          await _repository.getTotalPurchasedQuantity(
        materialId,
      );

      final totalCost =
          await _repository.getTotalPurchaseCost(
        materialId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _purchases = purchases;
        _currentStock = currentStock;
        _totalPurchased = totalPurchased;
        _totalCost = totalCost;
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

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(Object? value) {
    if (value == null) {
      return 'Unknown date';
    }

    final DateTime? date =
        DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load purchase history.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _materialName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Current Stock',
                  value:
                      '${_formatNumber(_currentStock)}'
                      '${_unitName.isEmpty ? '' : ' $_unitName'}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Purchased',
                  value:
                      '${_formatNumber(_totalPurchased)}'
                      '${_unitName.isEmpty ? '' : ' $_unitName'}',
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _SummaryCard(
            title: 'Total Purchase Cost',
            value:
                '৳ ${_formatNumber(_totalCost)}',
            icon: Icons.payments_outlined,
          ),

          const SizedBox(height: 24),

          Text(
            'Purchases',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 12),

          if (_purchases.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No purchases recorded yet.',
                  ),
                ),
              ),
            )
          else
            ..._purchases.map(
              (purchase) => _PurchaseCard(
                purchase: purchase,
                unitName: _unitName,
                formatNumber: _formatNumber,
                formatDate: _formatDate,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({
    required this.purchase,
    required this.unitName,
    required this.formatNumber,
    required this.formatDate,
  });

  final Map<String, Object?> purchase;
  final String unitName;
  final String Function(double value) formatNumber;
  final String Function(Object? value) formatDate;

  @override
  Widget build(BuildContext context) {
    final double quantity =
        (purchase['quantity'] as num?)
                ?.toDouble() ??
            0;

    final double totalCost =
        (purchase['total_cost'] as num?)
                ?.toDouble() ??
            0;

    final double unitCost =
        (purchase['unit_cost'] as num?)
                ?.toDouble() ??
            0;

    final String supplier =
        purchase['supplier_name'] as String? ?? '';

    final String notes =
        purchase['notes'] as String? ?? '';

    final Object? purchaseDate =
        purchase['purchase_date'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatDate(purchaseDate),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _PurchaseInfoRow(
              label: 'Quantity',
              value:
                  '${formatNumber(quantity)}'
                  '${unitName.isEmpty ? '' : ' $unitName'}',
            ),

            _PurchaseInfoRow(
              label: 'Total cost',
              value:
                  '৳ ${formatNumber(totalCost)}',
            ),

            _PurchaseInfoRow(
              label: 'Unit cost',
              value:
                  '৳ ${formatNumber(unitCost)}'
                  '${unitName.isEmpty ? '' : ' / $unitName'}',
            ),

            if (supplier.isNotEmpty)
              _PurchaseInfoRow(
                label: 'Supplier',
                value: supplier,
              ),

            if (notes.isNotEmpty)
              _PurchaseInfoRow(
                label: 'Notes',
                value: notes,
              ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseInfoRow extends StatelessWidget {
  const _PurchaseInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}