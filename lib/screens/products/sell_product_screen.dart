import 'package:flutter/material.dart';

import '../../repositories/sale_repository.dart';

class SellProductScreen extends StatefulWidget {
  const SellProductScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  State<SellProductScreen> createState() =>
      _SellProductScreenState();
}

class _SellProductScreenState
    extends State<SellProductScreen> {
  final SaleRepository _saleRepository =
      SaleRepository();

  final TextEditingController _customerNameController =
      TextEditingController();

  final TextEditingController _customerMobileController =
      TextEditingController();

  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  final TextEditingController _sellingPriceController =
      TextEditingController();

  final TextEditingController _platformFeeController =
      TextEditingController(text: '0');

  final TextEditingController _deliveryCostController =
      TextEditingController(text: '0');

  final TextEditingController _otherExpenseController =
      TextEditingController(text: '0');

  final TextEditingController _paidAmountController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  Map<String, Object?>? _product;

  bool _isLoading = true;
  bool _isSaving = false;

  String _deliveryStatus = 'PENDING';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _quantityController.dispose();
    _sellingPriceController.dispose();
    _platformFeeController.dispose();
    _deliveryCostController.dispose();
    _otherExpenseController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      final Map<String, Object?>? product =
          await _saleRepository.getProductForSale(
        widget.productId,
      );

      if (!mounted) {
        return;
      }

      if (product == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Product not found.';
        });
        return;
      }

      final double sellingPrice =
          (product['selling_price'] as num?)
                  ?.toDouble() ??
              0;

      _sellingPriceController.text =
          sellingPrice.toStringAsFixed(2);

      setState(() {
        _product = product;
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

  double _number(
    TextEditingController controller,
  ) {
    return double.tryParse(
          controller.text.trim(),
        ) ??
        0;
  }

  double get _quantity {
    return _number(_quantityController);
  }

  double get _sellingPrice {
    return _number(_sellingPriceController);
  }

  double get _platformFee {
    return _number(_platformFeeController);
  }

  double get _deliveryCost {
    return _number(_deliveryCostController);
  }

  double get _otherExpense {
    return _number(_otherExpenseController);
  }

  double get _paidAmount {
    return _number(_paidAmountController);
  }

  double get _subtotal {
    return _quantity * _sellingPrice;
  }

  double get _totalAmount {
    return _subtotal +
        _platformFee +
        _deliveryCost +
        _otherExpense;
  }

  double get _dueAmount {
    final double due =
        _totalAmount - _paidAmount;

    return due < 0 ? 0 : due;
  }

  String get _paymentStatus {
    if (_paidAmount <= 0) {
      return 'UNPAID';
    }

    if (_paidAmount >= _totalAmount) {
      return 'PAID';
    }

    return 'PARTIAL';
  }

  Future<void> _completeSale() async {
    if (_product == null) {
      return;
    }

    final double quantity = _quantity;

    if (quantity <= 0) {
      _showError(
        'Sale quantity must be greater than zero.',
      );
      return;
    }

    final double availableStock =
        (_product!['current_stock'] as num?)
                ?.toDouble() ??
            0;

    if (quantity > availableStock) {
      _showError(
        'Only $availableStock ${_product!['unit_symbol'] ?? ''} available.',
      );
      return;
    }

    if (_sellingPrice < 0) {
      _showError(
        'Selling price cannot be negative.',
      );
      return;
    }

    if (_paidAmount > _totalAmount) {
      _showError(
        'Paid amount cannot be greater than total amount.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _saleRepository.createSale(
        customerName:
            _customerNameController.text.trim().isEmpty
                ? null
                : _customerNameController.text.trim(),
        customerMobile:
            _customerMobileController.text.trim().isEmpty
                ? null
                : _customerMobileController.text.trim(),
        saleDate: DateTime.now().toIso8601String(),
        productId: widget.productId,
        quantity: quantity,
        unitPrice: _sellingPrice,
        platformFee: _platformFee,
        deliveryCost: _deliveryCost,
        otherExpense: _otherExpense,
        paidAmount: _paidAmount,
        paymentStatus: _paymentStatus,
        deliveryStatus: _deliveryStatus,
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
          content: Text(
            'Sale completed successfully.',
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

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sell Product'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sell Product'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final String productName =
        _product!['name'] as String;

    final double availableStock =
        (_product!['current_stock'] as num?)
                ?.toDouble() ??
            0;

    final String unitSymbol =
        _product!['unit_symbol'] as String? ??
            'pc';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available stock: '
                      '$availableStock $unitSymbol',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Customer',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _customerMobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Customer mobile',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Sale',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 12),

            _numberField(
              controller: _quantityController,
              label: 'Quantity',
              suffixText: unitSymbol,
            ),

            const SizedBox(height: 12),

            _numberField(
              controller: _sellingPriceController,
              label: 'Selling price per unit',
              suffixText: 'BDT',
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text(
                      '৳${_subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Expenses',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 12),

            _numberField(
              controller: _platformFeeController,
              label: 'Platform fee',
              suffixText: 'BDT',
            ),

            const SizedBox(height: 12),

            _numberField(
              controller: _deliveryCostController,
              label: 'Delivery cost',
              suffixText: 'BDT',
            ),

            const SizedBox(height: 12),

            _numberField(
              controller: _otherExpenseController,
              label: 'Other expense',
              suffixText: 'BDT',
            ),

            const SizedBox(height: 20),

            Text(
              'Payment',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 12),

            _numberField(
              controller: _paidAmountController,
              label: 'Paid amount',
              suffixText: 'BDT',
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _summaryRow(
                      'Total amount',
                      _totalAmount,
                    ),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Paid',
                      _paidAmount,
                    ),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Due',
                      _dueAmount,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'Payment status: '
                        '$_paymentStatus',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Delivery',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _deliveryStatus,
              decoration:
                  const InputDecoration(
                labelText: 'Delivery status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PENDING',
                  child: Text('Pending'),
                ),
                DropdownMenuItem(
                  value: 'DELIVERED',
                  child: Text('Delivered'),
                ),
                DropdownMenuItem(
                  value: 'CANCELLED',
                  child: Text('Cancelled'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _deliveryStatus = value;
                });
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : _completeSale,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.shopping_cart_checkout,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : 'Complete Sale',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double value,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '৳${value.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}