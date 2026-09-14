import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class MaterialPurchasesRepository {
  MaterialPurchasesRepository({AppDatabase? appDatabase, Uuid? uuid})
    : _appDatabase = appDatabase ?? AppDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<String> getBusinessId() async {
    final Database db = await _appDatabase.database;

    final List<Map<String, Object?>> businesses = await db.query(
      'businesses',
      columns: ['id'],
      orderBy: 'created_at ASC',
      limit: 1,
    );

    if (businesses.isEmpty) {
      throw StateError('No business has been created.');
    }

    return businesses.first['id'] as String;
  }

  /// Creates a material purchase and increases stock.
  ///
  /// Example:
  /// 10 meters of rope purchased for 1,500 BDT.
  /// Unit cost = 150 BDT per meter.
  Future<String> createPurchase({
    required String materialId,
    required double quantity,
    required double totalCost,
    String? supplierName,
    DateTime? purchaseDate,
    String? notes,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Purchase quantity must be greater than zero.');
    }

    if (totalCost < 0) {
      throw ArgumentError('Total cost cannot be negative.');
    }

    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final String purchaseId = _uuid.v4();
    final String movementId = _uuid.v4();

    final String now = DateTime.now().toIso8601String();

    final DateTime effectivePurchaseDate = purchaseDate ?? DateTime.now();

    final String purchaseDateValue = effectivePurchaseDate.toIso8601String();

    final double unitCost = totalCost / quantity;

    await db.transaction((transaction) async {
      // Make sure the material belongs to the current business.
      final List<Map<String, Object?>> materials = await transaction.query(
        'materials',
        columns: ['id'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [materialId, businessId],
        limit: 1,
      );

      if (materials.isEmpty) {
        throw StateError('Material not found for this business.');
      }

      // 1. Save the purchase.
      await transaction.insert('material_purchases', {
        'id': purchaseId,
        'business_id': businessId,
        'material_id': materialId,
        'quantity': quantity,
        'total_cost': totalCost,
        'unit_cost': unitCost,
        'supplier_name': supplierName,
        'purchase_date': purchaseDateValue,
        'notes': notes,
        'created_at': now,
        'updated_at': now,
      });

      // 2. Increase stock through a stock movement.
      await transaction.insert('material_stock_movements', {
        'id': movementId,
        'business_id': businessId,
        'material_id': materialId,
        'movement_type': 'PURCHASE',
        'quantity': quantity,
        'reference_id': purchaseId,
        'notes': notes,
        'movement_date': purchaseDateValue,
        'created_at': now,
      });
    });

    return purchaseId;
  }

  /// Returns the current stock for one material.
  ///
  /// Purchase = positive quantity.
  /// Stock removal = negative quantity.
  Future<double> getCurrentStock(String materialId) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final List<Map<String, Object?>> result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(quantity),
        0
      ) AS current_stock
      FROM material_stock_movements
      WHERE material_id = ?
        AND business_id = ?
      ''',
      [materialId, businessId],
    );

    final Object? value = result.first['current_stock'];

    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  /// Returns all purchases for one material.
  Future<List<Map<String, Object?>>> getPurchases(String materialId) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    return db.query(
      'material_purchases',
      columns: [
        'id',
        'material_id',
        'quantity',
        'total_cost',
        'unit_cost',
        'supplier_name',
        'purchase_date',
        'notes',
        'created_at',
        'updated_at',
      ],
      where: 'material_id = ? AND business_id = ?',
      whereArgs: [materialId, businessId],
      orderBy: 'purchase_date DESC',
    );
  }

  /// Returns the total amount spent on a material.
  Future<double> getTotalPurchaseCost(String materialId) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final List<Map<String, Object?>> result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(total_cost),
        0
      ) AS total_cost
      FROM material_purchases
      WHERE material_id = ?
        AND business_id = ?
      ''',
      [materialId, businessId],
    );

    final Object? value = result.first['total_cost'];

    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  /// Returns the total quantity purchased for a material.
  Future<double> getTotalPurchasedQuantity(String materialId) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final List<Map<String, Object?>> result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(quantity),
        0
      ) AS total_quantity
      FROM material_purchases
      WHERE material_id = ?
        AND business_id = ?
      ''',
      [materialId, businessId],
    );

    final Object? value = result.first['total_quantity'];

    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  /// Removes material stock.
  ///
  /// The quantity is saved as a negative stock movement.
  ///
  /// Example:
  /// Current stock = 100 meters
  /// Remove stock = 15 meters
  /// New stock = 85 meters
  Future<void> removeStock({
    required String materialId,
    required double quantity,
    required String reason,
    String? notes,
    DateTime? movementDate,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Stock removal quantity must be greater than zero.');
    }

    if (reason.trim().isEmpty) {
      throw ArgumentError('Stock removal reason is required.');
    }

    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final double currentStock = await getCurrentStock(materialId);

    if (quantity > currentStock) {
      throw StateError('Cannot remove more stock than currently available.');
    }

    final String movementId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    final DateTime effectiveMovementDate = movementDate ?? DateTime.now();

    final String movementDateValue = effectiveMovementDate.toIso8601String();

    await db.transaction((transaction) async {
      // Make sure the material belongs to the current business.
      final List<Map<String, Object?>> materials = await transaction.query(
        'materials',
        columns: ['id'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [materialId, businessId],
        limit: 1,
      );

      if (materials.isEmpty) {
        throw StateError('Material not found for this business.');
      }

      await transaction.insert('material_stock_movements', {
        'id': movementId,
        'business_id': businessId,
        'material_id': materialId,
        'movement_type': 'REMOVAL',
        'quantity': -quantity,
        'reference_id': null,
        'notes':
            '${reason.trim()}'
            '${notes == null || notes.trim().isEmpty ? '' : '\n${notes.trim()}'}',
        'movement_date': movementDateValue,
        'created_at': now,
      });
    });
  }

  /// Returns all stock movements for one material.
  ///
  /// Purchase quantities are positive.
  /// Removal quantities are negative.
  Future<List<Map<String, Object?>>> getStockMovements(
    String materialId,
  ) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    return db.query(
      'material_stock_movements',
      columns: [
        'id',
        'material_id',
        'movement_type',
        'quantity',
        'reference_id',
        'notes',
        'movement_date',
        'created_at',
      ],
      where: 'material_id = ? AND business_id = ?',
      whereArgs: [materialId, businessId],
      orderBy: 'movement_date DESC',
    );
  }

  /// Deletes one purchase and reverses its stock movement.
  ///
  /// Example:
  /// Purchase = 10 meters
  /// Delete purchase = stock decreases by 10 meters.
  ///
  /// Both records are deleted inside one transaction.
  Future<void> deletePurchase(String purchaseId) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    await db.transaction((transaction) async {
      // Find the purchase belonging to the current business.
      final List<Map<String, Object?>> purchases = await transaction.query(
        'material_purchases',
        columns: ['id', 'material_id', 'quantity'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [purchaseId, businessId],
        limit: 1,
      );

      if (purchases.isEmpty) {
        throw StateError('Purchase not found for this business.');
      }

      final String materialId = purchases.first['material_id'] as String;

      final double quantity = (purchases.first['quantity'] as num).toDouble();

      // Find the stock movement connected to this purchase.
      final List<Map<String, Object?>> movements = await transaction.query(
        'material_stock_movements',
        columns: ['id'],
        where: '''
        business_id = ?
        AND material_id = ?
        AND movement_type = ?
        AND reference_id = ?
      ''',
        whereArgs: [businessId, materialId, 'PURCHASE', purchaseId],
        limit: 1,
      );

      if (movements.isEmpty) {
        throw StateError('Stock movement for this purchase was not found.');
      }

      // Check current stock before deleting.
      final List<Map<String, Object?>> stockResult = await transaction.rawQuery(
        '''
      SELECT COALESCE(
        SUM(quantity),
        0
      ) AS current_stock
      FROM material_stock_movements
      WHERE material_id = ?
        AND business_id = ?
      ''',
        [materialId, businessId],
      );

      final double currentStock = (stockResult.first['current_stock'] as num)
          .toDouble();

      if (quantity > currentStock) {
        throw StateError(
          'This purchase cannot be deleted because '
          'the stock has already been used or removed.',
        );
      }

      // Delete the connected stock movement first.
      await transaction.delete(
        'material_stock_movements',
        where: 'id = ? AND business_id = ?',
        whereArgs: [movements.first['id'], businessId],
      );

      // Delete the purchase record.
      await transaction.delete(
        'material_purchases',
        where: 'id = ? AND business_id = ?',
        whereArgs: [purchaseId, businessId],
      );
    });
  }

    Future<void> adjustStock({
    required String materialId,
    required double quantity,
    required bool increase,
    required String reason,
    String? notes,
    DateTime? movementDate,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Adjustment quantity must be greater than zero.',
      );
    }

    if (reason.trim().isEmpty) {
      throw ArgumentError(
        'Adjustment reason is required.',
      );
    }

    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final double currentStock =
        await getCurrentStock(materialId);

    final double movementQuantity =
        increase ? quantity : -quantity;

    if (!increase && quantity > currentStock) {
      throw StateError(
        'Cannot decrease stock below zero.',
      );
    }

    final String movementId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    final DateTime effectiveMovementDate =
        movementDate ?? DateTime.now();

    final String movementDateValue =
        effectiveMovementDate.toIso8601String();

    await db.transaction((transaction) async {
      final List<Map<String, Object?>> materials =
          await transaction.query(
        'materials',
        columns: ['id'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [
          materialId,
          businessId,
        ],
        limit: 1,
      );

      if (materials.isEmpty) {
        throw StateError(
          'Material not found for this business.',
        );
      }

      await transaction.insert(
        'material_stock_movements',
        {
          'id': movementId,
          'business_id': businessId,
          'material_id': materialId,
          'movement_type': 'ADJUSTMENT',
          'quantity': movementQuantity,
          'reference_id': null,
          'notes': '${reason.trim()}'
              '${notes == null || notes.trim().isEmpty ? '' : '\n${notes.trim()}'}',
          'movement_date': movementDateValue,
          'created_at': now,
        },
      );
    });
  }
}
