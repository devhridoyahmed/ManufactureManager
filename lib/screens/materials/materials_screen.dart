import 'package:flutter/material.dart';

import '../../repositories/materials_repository.dart';

import 'add_material_screen.dart';
import 'material_details_screen.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final MaterialsRepository _repository = MaterialsRepository();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, Object?>> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, Object?>> materials =
          await _repository.getMaterialsWithStock();

      if (!mounted) {
        return;
      }

      setState(() {
        _materials = materials;
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

  bool _isLowStock(Map<String, Object?> material) {
    final double currentStock =
        (material['current_stock'] as num?)?.toDouble() ?? 0;

    final double minimumStock =
        (material['minimum_stock'] as num?)?.toDouble() ?? 0;

    return minimumStock > 0 &&
        currentStock <= minimumStock;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _stockText(Map<String, Object?> material) {
    final double currentStock =
        (material['current_stock'] as num?)?.toDouble() ?? 0;

    final String unitSymbol =
        material['unit_symbol'] as String? ?? '';

    final String stockValue =
        _formatNumber(currentStock);

    if (unitSymbol.isEmpty) {
      return 'Stock: $stockValue';
    }

    return 'Stock: $stockValue $unitSymbol';
  }

  String _minimumStockText(Map<String, Object?> material) {
    final double minimumStock =
        (material['minimum_stock'] as num?)?.toDouble() ?? 0;

    final String unitSymbol =
        material['unit_symbol'] as String? ?? '';

    final String minimumValue =
        _formatNumber(minimumStock);

    if (unitSymbol.isEmpty) {
      return 'Reorder threshold: $minimumValue';
    }

    return 'Reorder threshold: $minimumValue $unitSymbol';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? saved =
              await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const AddMaterialScreen(),
            ),
          );

          if (saved == true) {
            await _loadMaterials();
          }
        },
        child: const Icon(Icons.add),
      ),
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
                'Could not load materials.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMaterials,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_materials.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMaterials,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No materials yet.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Tap + to add your first material.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _materials.length,
        itemBuilder: (context, index) {
          final Map<String, Object?> material =
              _materials[index];

          final String name =
              material['name'] as String? ??
                  'Unnamed material';

          final bool isLowStock =
              _isLowStock(material);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isLowStock
                    ? Theme.of(context)
                        .colorScheme
                        .errorContainer
                    : null,
                child: Icon(
                  isLowStock
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
                  color: isLowStock
                      ? Theme.of(context)
                          .colorScheme
                          .onErrorContainer
                      : null,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(_stockText(material)),
                    const SizedBox(height: 2),
                    Text(
                      _minimumStockText(material),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Low stock',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () async {
                final bool? changed =
                    await Navigator.of(context)
                        .push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        MaterialDetailsScreen(
                      materialId:
                          material['id'] as String,
                    ),
                  ),
                );

                if (changed == true) {
                  await _loadMaterials();
                } else {
                  await _loadMaterials();
                }
              },
            ),
          );
        },
      ),
    );
  }
}