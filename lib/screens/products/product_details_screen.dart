import 'package:flutter/material.dart';

import '../../repositories/product_repository.dart';
import 'sell_product_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductRepository _productRepository = ProductRepository();

  Map<String, Object?>? _product;

  List<Map<String, Object?>> _productionHistory = <Map<String, Object?>>[];

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, Object?>? product = await _productRepository.getProduct(
        widget.productId,
      );

      final List<Map<String, Object?>> history = await _productRepository
          .getProductionHistory(widget.productId);

      if (!mounted) {
        return;
      }

      setState(() {
        _product = product;
        _productionHistory = history;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
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
                'Could not load product details.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProductDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_product == null) {
      return const Center(child: Text('Product not found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadProductDetails,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProductSummary(),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final bool? saleCompleted = await Navigator.of(context)
                    .push<bool>(
                      MaterialPageRoute(
                        builder: (context) =>
                            SellProductScreen(productId: widget.productId),
                      ),
                    );

                if (!mounted) {
                  return;
                }

                if (saleCompleted == true) {
                  await _loadProductDetails();
                }
              },
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Sell Product'),
            ),
          ),

          const SizedBox(height: 24),

          _buildProductionHistory(),
        ],
      ),
    );
  }

  Widget _buildProductSummary() {
    final String name = _product!['name'] as String? ?? 'Unnamed Product';

    final String recipeName =
        _product!['recipe_name'] as String? ?? 'No recipe';

    final String unitSymbol = _product!['unit_symbol'] as String? ?? '';

    final double sellingPrice =
        (_product!['selling_price'] as num?)?.toDouble() ?? 0;

    final double currentStock =
        (_product!['current_stock'] as num?)?.toDouble() ?? 0;

    double totalProduced = 0;

    double totalProductionCost = 0;

    for (final production in _productionHistory) {
      totalProduced += (production['quantity'] as num?)?.toDouble() ?? 0;

      totalProductionCost +=
          (production['total_cost'] as num?)?.toDouble() ?? 0;
    }

    final double averageCostPerUnit = totalProduced > 0
        ? totalProductionCost / totalProduced
        : 0;

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
            const SizedBox(height: 8),
            Text(
              'Recipe: $recipeName',
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(height: 28),
            _buildInfoRow(
              'Current Stock',
              '${currentStock.toStringAsFixed(2)}'
                  '${unitSymbol.isNotEmpty ? ' $unitSymbol' : ''}',
            ),
            _buildInfoRow(
              'Selling Price',
              '৳${sellingPrice.toStringAsFixed(2)}',
            ),
            _buildInfoRow('Total Produced', totalProduced.toStringAsFixed(2)),
            _buildInfoRow(
              'Total Production Cost',
              '৳${totalProductionCost.toStringAsFixed(2)}',
            ),
            _buildInfoRow(
              'Average Cost / Unit',
              '৳${averageCostPerUnit.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionHistory() {
    if (_productionHistory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No production history found.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Production History',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._productionHistory.map(_buildProductionCard),
      ],
    );
  }

  Widget _buildProductionCard(Map<String, Object?> production) {
    final double quantity = (production['quantity'] as num?)?.toDouble() ?? 0;

    final double totalCost =
        (production['total_cost'] as num?)?.toDouble() ?? 0;

    final double materialCost =
        (production['material_cost'] as num?)?.toDouble() ?? 0;

    final double labourCost =
        (production['labour_cost'] as num?)?.toDouble() ?? 0;

    final double productionExpense =
        (production['production_expense'] as num?)?.toDouble() ?? 0;

    final String makerName =
        production['maker_name'] as String? ?? 'Not specified';

    final String productionDate =
        production['production_date'] as String? ?? '';

    final String notes = production['notes'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produced: ${quantity.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text('Maker: $makerName'),
            const SizedBox(height: 4),
            Text('Date: $productionDate'),
            const Divider(height: 20),
            _buildInfoRow(
              'Material Cost',
              '৳${materialCost.toStringAsFixed(2)}',
            ),
            _buildInfoRow('Labour Cost', '৳${labourCost.toStringAsFixed(2)}'),
            _buildInfoRow(
              'Production Expense',
              '৳${productionExpense.toStringAsFixed(2)}',
            ),
            _buildInfoRow('Total Cost', '৳${totalCost.toStringAsFixed(2)}'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: $notes'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
