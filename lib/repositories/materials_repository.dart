import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class MaterialsRepository {
  MaterialsRepository({
    AppDatabase? appDatabase,
    Uuid? uuid,
  })  : _appDatabase = appDatabase ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<String> getBusinessId() async {
    final Database db = await _appDatabase.database;

    final List<Map<String, Object?>> businesses =
        await db.query(
      'businesses',
      columns: ['id'],
      orderBy: 'created_at ASC',
      limit: 1,
    );

    if (businesses.isEmpty) {
      throw StateError(
        'No business has been created.',
      );
    }

    return businesses.first['id'] as String;
  }

  Future<List<Map<String, Object?>>> getMaterials() async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    return db.rawQuery(
      '''
      SELECT
        materials.id,
        materials.name,
        materials.category_id,
        materials.unit_id,
        materials.minimum_stock,
        materials.description,
        materials.notes,
        materials.image_path,
        materials.is_active,
        materials.created_at,
        materials.updated_at,
        units.name AS unit_name,
        units.symbol AS unit_symbol,
        material_categories.name AS category_name
      FROM materials
      LEFT JOIN units
        ON units.id = materials.unit_id
      LEFT JOIN material_categories
        ON material_categories.id = materials.category_id
      WHERE materials.business_id = ?
        AND materials.is_active = 1
      ORDER BY materials.name ASC
      ''',
      [businessId],
    );
  }

  Future<List<Map<String, Object?>>> getMaterialsWithStock() async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    return db.rawQuery(
      '''
      SELECT
        materials.id,
        materials.name,
        materials.category_id,
        materials.unit_id,
        materials.minimum_stock,
        materials.description,
        materials.notes,
        materials.image_path,
        materials.is_active,
        materials.created_at,
        materials.updated_at,
        units.name AS unit_name,
        units.symbol AS unit_symbol,
        material_categories.name AS category_name,
        COALESCE(
          (
            SELECT SUM(
              material_stock_movements.quantity
            )
            FROM material_stock_movements
            WHERE material_stock_movements.material_id =
                  materials.id
              AND material_stock_movements.business_id = ?
          ),
          0
        ) AS current_stock
      FROM materials
      LEFT JOIN units
        ON units.id = materials.unit_id
      LEFT JOIN material_categories
        ON material_categories.id = materials.category_id
      WHERE materials.business_id = ?
        AND materials.is_active = 1
      ORDER BY materials.name ASC
      ''',
      [
        businessId,
        businessId,
      ],
    );
  }

  Future<Map<String, Object?>?> getMaterialById(
    String materialId,
  ) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final List<Map<String, Object?>> results =
        await db.rawQuery(
      '''
      SELECT
        materials.id,
        materials.name,
        materials.category_id,
        materials.unit_id,
        materials.minimum_stock,
        materials.description,
        materials.notes,
        materials.image_path,
        materials.is_active,
        materials.created_at,
        materials.updated_at,
        units.name AS unit_name,
        units.symbol AS unit_symbol,
        material_categories.name AS category_name
      FROM materials
      LEFT JOIN units
        ON units.id = materials.unit_id
      LEFT JOIN material_categories
        ON material_categories.id = materials.category_id
      WHERE materials.id = ?
        AND materials.business_id = ?
      LIMIT 1
      ''',
      [
        materialId,
        businessId,
      ],
    );

    if (results.isEmpty) {
      return null;
    }

    return results.first;
  }

  Future<String> createMaterial({
    required String name,
    required String unitId,
    double minimumStock = 0,
    String? categoryId,
    String? description,
    String? notes,
    String? imagePath,
  }) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final String materialId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    await db.insert(
      'materials',
      {
        'id': materialId,
        'business_id': businessId,
        'category_id': categoryId,
        'unit_id': unitId,
        'name': name.trim(),
        'minimum_stock': minimumStock,
        'description': description,
        'notes': notes,
        'image_path': imagePath,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
    );

    return materialId;
  }

  Future<void> updateMaterial({
    required String materialId,
    required String name,
    required String unitId,
    required double minimumStock,
    String? categoryId,
    String? description,
    String? notes,
    String? imagePath,
  }) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    await db.update(
      'materials',
      {
        'category_id': categoryId,
        'unit_id': unitId,
        'name': name.trim(),
        'minimum_stock': minimumStock,
        'description': description,
        'notes': notes,
        'image_path': imagePath,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND business_id = ?',
      whereArgs: [
        materialId,
        businessId,
      ],
    );
  }

  Future<void> deactivateMaterial(
    String materialId,
  ) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    await db.update(
      'materials',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND business_id = ?',
      whereArgs: [
        materialId,
        businessId,
      ],
    );
  }

  Future<List<Map<String, Object?>>> getUnits() async {
    final Database db = await _appDatabase.database;

    final List<Map<String, Object?>> rows =
        await db.query(
      'units',
      columns: [
        'id',
        'name',
        'symbol',
      ],
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    final Map<String, Map<String, Object?>> uniqueUnits =
        {};

    for (final unit in rows) {
      final String id = unit['id'] as String;
      uniqueUnits[id] = unit;
    }

    return uniqueUnits.values.toList();
  }

  Future<List<Map<String, Object?>>> getCategories() async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    return db.query(
      'material_categories',
      columns: [
        'id',
        'name',
        'description',
      ],
      where: 'business_id = ? AND is_active = ?',
      whereArgs: [
        businessId,
        1,
      ],
      orderBy: 'name ASC',
    );
  }
}