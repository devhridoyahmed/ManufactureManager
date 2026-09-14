import 'package:flutter/material.dart';

import '../../repositories/material_purchases_repository.dart';

class MaterialStockMovementHistoryScreen extends StatefulWidget {
  const MaterialStockMovementHistoryScreen({
    super.key,
    required this.material,
  });

  final Map<String, Object?> material;

  @override
  State<MaterialStockMovementHistoryScreen> createState() =>
      _MaterialStockMovementHistoryScreenState();
}

class _MaterialStockMovementHistoryScreenState
    extends State<MaterialStockMovementHistoryScreen> {
  final MaterialPurchasesRepository _repository =
      MaterialPurchasesRepository();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, Object?>> _movements = [];
  double _currentStock = 0;

  String get _materialName {
    return widget.material['name'] as String? ?? 'Material';
  }

  String get _unitName {
    final String symbol =
        widget.material['unit_symbol'] as String? ?? '';

    final String name =
        widget.material['unit_name'] as String? ?? '';

    if (symbol.isNotEmpty) {
      return symbol;
    }

    return name;
  }

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String materialId =
          widget.material['id'] as String;

      final List<Map<String, Object?>> movements =
          await _repository.getStockMovements(materialId);

      final double currentStock =
          await _repository.getCurrentStock(materialId);

      if (!mounted) {
        return;
      }

      setState(() {
        _movements = movements;
        _currentStock = currentStock;
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

  String _movementTitle(String type) {
    switch (type) {
      case 'PURCHASE':
        return 'Stock Purchased';

      case 'REMOVAL':
        return 'Stock Removed';

      default:
        return type;
    }
  }

  IconData _movementIcon(String type) {
    switch (type) {
      case 'PURCHASE':
        return Icons.add_shopping_cart_outlined;

      case 'REMOVAL':
        return Icons.remove_circle_outline;

      default:
        return Icons.swap_vert;
    }
  }

  String _movementQuantity(
    String type,
    double quantity,
  ) {
    final String number =
        _formatNumber(quantity.abs());

    switch (type) {
      case 'PURCHASE':
        return '+$number';

      case 'REMOVAL':
        return '-$number';

      default:
        if (quantity > 0) {
          return '+$number';
        }

        return number;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stock Movement History',
        ),
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
                'Could not load stock movement history.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMovements,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMovements,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Stock',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatNumber(_currentStock)}'
                          '${_unitName.isEmpty ? '' : ' $_unitName'}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
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
          ),

          const SizedBox(height: 24),

          Text(
            'Movements',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 12),

          if (_movements.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No stock movements recorded yet.',
                  ),
                ),
              ),
            )
          else
            ..._movements.map(
              (movement) => _MovementCard(
                movement: movement,
                unitName: _unitName,
                formatNumber: _formatNumber,
                formatDate: _formatDate,
                movementTitle: _movementTitle,
                movementIcon: _movementIcon,
                movementQuantity: _movementQuantity,
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    required this.movement,
    required this.unitName,
    required this.formatNumber,
    required this.formatDate,
    required this.movementTitle,
    required this.movementIcon,
    required this.movementQuantity,
  });

  final Map<String, Object?> movement;
  final String unitName;

  final String Function(double value) formatNumber;
  final String Function(Object? value) formatDate;
  final String Function(String type) movementTitle;
  final IconData Function(String type) movementIcon;

  final String Function(
    String type,
    double quantity,
  ) movementQuantity;

  @override
  Widget build(BuildContext context) {
    final String type =
        movement['movement_type'] as String? ?? '';

    final double quantity =
        (movement['quantity'] as num?)?.toDouble() ?? 0;

    final String notes =
        movement['notes'] as String? ?? '';

    final Object? movementDate =
        movement['movement_date'];

    final bool isPurchase =
        type == 'PURCHASE';

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
                Icon(
                  movementIcon(type),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    movementTitle(type),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  movementQuantity(
                    type,
                    quantity,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              formatDate(movementDate),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),

            const SizedBox(height: 12),

            Text(
              '${formatNumber(quantity.abs())}'
              '${unitName.isEmpty ? '' : ' $unitName'}'
              '${isPurchase ? ' added to stock' : ' removed from stock'}',
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                notes,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}