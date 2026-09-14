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
  /// unit cost = 150 BDT per meter.
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
  /// Future material consumption = negative quantity.
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
  /// Stock removal is stored as a negative quantity
  /// in material_stock_movements.
  Future<void> removeStock({
    required String materialId,
    required double quantity,
    required String reason,
    String? notes,
    DateTime? movementDate,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Stock removal quantity must be greater than zero.',
      );
    }

    if (reason.trim().isEmpty) {
      throw ArgumentError(
        'Stock removal reason is required.',
      );
    }

    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final double currentStock =
        await getCurrentStock(materialId);

    if (quantity > currentStock) {
      throw StateError(
        'Cannot remove more stock than currently available.',
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
        whereArgs: [materialId, businessId],
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
          'movement_type': 'REMOVAL',
          'quantity': -quantity,
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
