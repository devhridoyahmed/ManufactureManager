import 'package:flutter/material.dart';

import '../../repositories/product_repository.dart';
import 'produce_product_screen.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductRepository _productRepository = ProductRepository();

  List<Map<String, Object?>> _products = <Map<String, Object?>>[];

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, Object?>> products = await _productRepository
          .getProducts();

      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;
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
      appBar: AppBar(title: const Text('Products')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ProduceProductScreen(),
            ),
          );

          if (!mounted) {
            return;
          }

          await _loadProducts();
        },
        child: const Icon(Icons.add),
      ),
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
                'Could not load products.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProducts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.inventory_2_outlined, size: 64),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No products yet.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(height: 8),
            Center(child: Text('Tap + to add your first product.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          return _buildProductCard(_products[index]);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, Object?> product) {
    final String name = product['name'] as String? ?? 'Unnamed Product';

    final String recipeName = product['recipe_name'] as String? ?? 'No recipe';

    final String unitSymbol = product['unit_symbol'] as String? ?? '';

    final double sellingPrice =
        (product['selling_price'] as num?)?.toDouble() ?? 0;

    final double currentStock =
        (product['current_stock'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(child: const Icon(Icons.inventory_2_outlined)),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recipe: $recipeName'),
              const SizedBox(height: 4),
              Text('Selling price: ৳${sellingPrice.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              Text(
                'Stock: ${currentStock.toStringAsFixed(2)}'
                '${unitSymbol.isNotEmpty ? ' $unitSymbol' : ''}',
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailsScreen(productId: product['id'] as String),
            ),
          );

          if (!mounted) {
            return;
          }

          await _loadProducts();
        },
      ),
    );
  }
}
