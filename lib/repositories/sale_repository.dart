import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class SaleRepository {
  SaleRepository({
    AppDatabase? appDatabase,
    Uuid? uuid,
  })  : _appDatabase = appDatabase ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  // ---------------------------------------------------------------------------
  // BUSINESS
  // ---------------------------------------------------------------------------

  Future<String> _getBusinessId(Database db) async {
    final List<Map<String, Object?>> businesses = await db.query(
      'businesses',
      columns: ['id'],
      orderBy: 'created_at ASC',
      limit: 1,
    );

    if (businesses.isEmpty) {
      throw StateError('Business not found.');
    }

    return businesses.first['id'] as String;
  }

  // ---------------------------------------------------------------------------
  // PRODUCTS AVAILABLE FOR SALE
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getProductsForSale() async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    return db.rawQuery(
      '''
      SELECT
        products.id,
        products.name,
        products.selling_price,
        products.unit_id,
        units.name AS unit_name,
        units.symbol AS unit_symbol,

        COALESCE(
          (
            SELECT SUM(product_stock_movements.quantity)
            FROM product_stock_movements
            WHERE product_stock_movements.product_id = products.id
              AND product_stock_movements.business_id = ?
          ),
          0
        ) AS current_stock

      FROM products

      INNER JOIN units
        ON units.id = products.unit_id

      WHERE products.business_id = ?
        AND products.is_active = 1

      ORDER BY products.name ASC
      ''',
      [
        businessId,
        businessId,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SINGLE PRODUCT
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>?> getProductForSale(
    String productId,
  ) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    final List<Map<String, Object?>> products = await db.rawQuery(
      '''
      SELECT
        products.id,
        products.name,
        products.selling_price,
        products.unit_id,
        units.name AS unit_name,
        units.symbol AS unit_symbol,

        COALESCE(
          (
            SELECT SUM(product_stock_movements.quantity)
            FROM product_stock_movements
            WHERE product_stock_movements.product_id = products.id
              AND product_stock_movements.business_id = ?
          ),
          0
        ) AS current_stock

      FROM products

      INNER JOIN units
        ON units.id = products.unit_id

      WHERE products.id = ?
        AND products.business_id = ?
        AND products.is_active = 1

      LIMIT 1
      ''',
      [
        businessId,
        productId,
        businessId,
      ],
    );

    if (products.isEmpty) {
      return null;
    }

    return products.first;
  }

  // ---------------------------------------------------------------------------
  // CREATE SALE
  // ---------------------------------------------------------------------------

  Future<String> createSale({
    String? customerName,
    String? customerMobile,
    required String saleDate,

    required String productId,
    required double quantity,
    required double unitPrice,

    double platformFee = 0,
    double deliveryCost = 0,
    double otherExpense = 0,

    double paidAmount = 0,

    String paymentStatus = 'UNPAID',
    String deliveryStatus = 'PENDING',

    String? notes,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Sale quantity must be greater than zero.',
      );
    }

    if (unitPrice < 0) {
      throw ArgumentError(
        'Selling price cannot be negative.',
      );
    }

    if (platformFee < 0 ||
        deliveryCost < 0 ||
        otherExpense < 0) {
      throw ArgumentError(
        'Sale expenses cannot be negative.',
      );
    }

    if (paidAmount < 0) {
      throw ArgumentError(
        'Paid amount cannot be negative.',
      );
    }

    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    return db.transaction((transaction) async {
      // -----------------------------------------------------------------------
      // 1. GET PRODUCT
      // -----------------------------------------------------------------------

      final List<Map<String, Object?>> products =
          await transaction.rawQuery(
        '''
        SELECT
          products.id,
          products.name,
          products.selling_price
        FROM products
        WHERE products.id = ?
          AND products.business_id = ?
          AND products.is_active = 1
        LIMIT 1
        ''',
        [
          productId,
          businessId,
        ],
      );

      if (products.isEmpty) {
        throw StateError(
          'Product not found.',
        );
      }

      // -----------------------------------------------------------------------
      // 2. CHECK CURRENT STOCK
      // -----------------------------------------------------------------------

      final List<Map<String, Object?>> stockResult =
          await transaction.rawQuery(
        '''
        SELECT
          COALESCE(
            SUM(quantity),
            0
          ) AS current_stock
        FROM product_stock_movements
        WHERE product_id = ?
          AND business_id = ?
        ''',
        [
          productId,
          businessId,
        ],
      );

      final double currentStock =
          (stockResult.first['current_stock'] as num?)
                  ?.toDouble() ??
              0;

      if (quantity > currentStock) {
        throw StateError(
          'Insufficient product stock. '
          'Available: $currentStock',
        );
      }

      // -----------------------------------------------------------------------
      // 3. GET PRODUCT COST
      //
      // For now we use the most recent production cost per unit.
      // Later we can improve this to a proper batch/FIFO cost system.
      // -----------------------------------------------------------------------

      final List<Map<String, Object?>> productionRecords =
          await transaction.rawQuery(
        '''
        SELECT
          quantity,
          total_cost,
          production_date,
          created_at
        FROM production_records
        WHERE product_id = ?
          AND business_id = ?
          AND quantity > 0
        ORDER BY production_date DESC, created_at DESC
        LIMIT 1
        ''',
        [
          productId,
          businessId,
        ],
      );

      if (productionRecords.isEmpty) {
        throw StateError(
          'Production cost not found for this product.',
        );
      }

      final double productionQuantity =
          (productionRecords.first['quantity'] as num)
              .toDouble();

      final double productionTotalCost =
          (productionRecords.first['total_cost'] as num)
              .toDouble();

      if (productionQuantity <= 0) {
        throw StateError(
          'Invalid production quantity.',
        );
      }

      final double unitCost =
          productionTotalCost / productionQuantity;

      // -----------------------------------------------------------------------
      // 4. CALCULATE SALE
      // -----------------------------------------------------------------------

      final double subtotal =
          quantity * unitPrice;

      final double totalSaleAmount =
          subtotal;

      final double totalCost =
          quantity * unitCost;

      final double profit =
          totalSaleAmount -
          totalCost -
          platformFee -
          deliveryCost -
          otherExpense;

      final double profitMargin =
          totalSaleAmount > 0
              ? (profit / totalSaleAmount) * 100
              : 0;

      final double dueAmount =
          totalSaleAmount +
          platformFee +
          deliveryCost +
          otherExpense -
          paidAmount;

      if (paidAmount >
          totalSaleAmount +
              platformFee +
              deliveryCost +
              otherExpense) {
        throw ArgumentError(
          'Paid amount cannot be greater than the total amount due.',
        );
      }

      final String saleId = _uuid.v4();
      final String saleItemId = _uuid.v4();
      final String stockMovementId = _uuid.v4();

      final String now =
          DateTime.now().toIso8601String();

      // -----------------------------------------------------------------------
      // 5. CREATE SALE
      // -----------------------------------------------------------------------

      await transaction.insert(
        'sales',
        {
          'id': saleId,
          'business_id': businessId,
          'customer_name': customerName,
          'customer_mobile': customerMobile,
          'sale_date': saleDate,
          'subtotal': subtotal,
          'platform_fee': platformFee,
          'delivery_cost': deliveryCost,
          'other_expense': otherExpense,
          'total_sale_amount': totalSaleAmount,
          'total_cost': totalCost,
          'profit': profit,
          'profit_margin': profitMargin,
          'paid_amount': paidAmount,
          'due_amount': dueAmount,
          'payment_status': paymentStatus,
          'delivery_status': deliveryStatus,
          'notes': notes,
          'created_at': now,
          'updated_at': now,
        },
      );

      // -----------------------------------------------------------------------
      // 6. CREATE SALE ITEM
      // -----------------------------------------------------------------------

      await transaction.insert(
        'sale_items',
        {
          'id': saleItemId,
          'business_id': businessId,
          'sale_id': saleId,
          'product_id': productId,
          'quantity': quantity,
          'unit_price': unitPrice,
          'target_price': 0,
          'unit_cost': unitCost,
          'total_price': totalSaleAmount,
          'total_cost': totalCost,
          'profit': profit,
          'notes': null,
          'created_at': now,
          'updated_at': now,
        },
      );

      // -----------------------------------------------------------------------
      // 7. DEDUCT FINISHED PRODUCT STOCK
      // -----------------------------------------------------------------------

      await transaction.insert(
        'product_stock_movements',
        {
          'id': stockMovementId,
          'business_id': businessId,
          'product_id': productId,
          'movement_type': 'SALE',
          'quantity': -quantity,
          'reference_id': saleId,
          'notes': 'Product sold.',
          'movement_date': saleDate,
          'created_at': now,
        },
      );

      return saleId;
    });
  }

  // ---------------------------------------------------------------------------
  // SALE HISTORY
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getSales() async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    return db.query(
      'sales',
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'sale_date DESC, created_at DESC',
    );
  }

  // ---------------------------------------------------------------------------
  // SINGLE SALE
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>?> getSale(
    String saleId,
  ) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    final List<Map<String, Object?>> sales =
        await db.query(
      'sales',
      where: 'id = ? AND business_id = ?',
      whereArgs: [
        saleId,
        businessId,
      ],
      limit: 1,
    );

    if (sales.isEmpty) {
      return null;
    }

    return sales.first;
  }

  // ---------------------------------------------------------------------------
  // SALE ITEMS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getSaleItems(
    String saleId,
  ) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    return db.rawQuery(
      '''
      SELECT
        sale_items.id,
        sale_items.sale_id,
        sale_items.product_id,
        sale_items.quantity,
        sale_items.unit_price,
        sale_items.target_price,
        sale_items.unit_cost,
        sale_items.total_price,
        sale_items.total_cost,
        sale_items.profit,
        sale_items.notes,
        products.name AS product_name
      FROM sale_items
      INNER JOIN products
        ON products.id = sale_items.product_id
      WHERE sale_items.sale_id = ?
        AND sale_items.business_id = ?
      ORDER BY sale_items.created_at ASC
      ''',
      [
        saleId,
        businessId,
      ],
    );
  }
}