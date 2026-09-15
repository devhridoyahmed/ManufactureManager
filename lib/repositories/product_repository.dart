import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class ProductRepository {
  ProductRepository({AppDatabase? appDatabase, Uuid? uuid})
    : _appDatabase = appDatabase ?? AppDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

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
  // CREATE
  // ---------------------------------------------------------------------------

  Future<String> createProduct({
    required String recipeId,
    required String unitId,
    required String name,
    double sellingPrice = 0,
    String? description,
    String? notes,
    String? imagePath,
  }) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);
    final String productId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    if (name.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty.');
    }

    if (sellingPrice < 0) {
      throw ArgumentError('Selling price cannot be negative.');
    }

    final List<Map<String, Object?>> recipes = await db.query(
      'recipes',
      columns: ['id'],
      where: '''
        id = ?
        AND business_id = ?
        AND is_active = 1
      ''',
      whereArgs: [recipeId, businessId],
      limit: 1,
    );

    if (recipes.isEmpty) {
      throw StateError('Selected recipe was not found.');
    }

    final List<Map<String, Object?>> units = await db.query(
      'units',
      columns: ['id'],
      where: 'id = ? AND is_active = 1',
      whereArgs: [unitId],
      limit: 1,
    );

    if (units.isEmpty) {
      throw StateError('Selected unit was not found.');
    }

    await db.insert('products', {
      'id': productId,
      'business_id': businessId,
      'recipe_id': recipeId,
      'unit_id': unitId,
      'name': name.trim(),
      'selling_price': sellingPrice,
      'description': description,
      'notes': notes,
      'image_path': imagePath,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    return productId;
  }

  // ---------------------------------------------------------------------------
  // READ - PRODUCT LIST
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getProducts() async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    return db.rawQuery(
      '''
      SELECT
        products.id,
        products.business_id,
        products.recipe_id,
        products.unit_id,
        products.name,
        products.selling_price,
        products.description,
        products.notes,
        products.image_path,
        products.is_active,
        products.created_at,
        products.updated_at,

        recipes.name AS recipe_name,

        units.name AS unit_name,
        units.symbol AS unit_symbol,

        COALESCE(
          (
            SELECT SUM(product_stock_movements.quantity)
            FROM product_stock_movements
            WHERE product_stock_movements.product_id =
                  products.id
          ),
          0
        ) AS current_stock

      FROM products

      INNER JOIN recipes
        ON recipes.id = products.recipe_id

      INNER JOIN units
        ON units.id = products.unit_id

      WHERE products.business_id = ?
        AND products.is_active = 1

      ORDER BY products.created_at DESC
      ''',
      [businessId],
    );
  }

  // ---------------------------------------------------------------------------
  // READ - SINGLE PRODUCT
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>?> getProduct(String productId) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    final List<Map<String, Object?>> results = await db.rawQuery(
      '''
      SELECT
        products.id,
        products.business_id,
        products.recipe_id,
        products.unit_id,
        products.name,
        products.selling_price,
        products.description,
        products.notes,
        products.image_path,
        products.is_active,
        products.created_at,
        products.updated_at,

        recipes.name AS recipe_name,

        units.name AS unit_name,
        units.symbol AS unit_symbol,

        COALESCE(
          (
            SELECT SUM(product_stock_movements.quantity)
            FROM product_stock_movements
            WHERE product_stock_movements.product_id =
                  products.id
          ),
          0
        ) AS current_stock

      FROM products

      INNER JOIN recipes
        ON recipes.id = products.recipe_id

      INNER JOIN units
        ON units.id = products.unit_id

      WHERE products.id = ?
        AND products.business_id = ?

      LIMIT 1
      ''',
      [productId, businessId],
    );

    if (results.isEmpty) {
      return null;
    }

    return results.first;
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateProduct({
    required String productId,
    required String recipeId,
    required String unitId,
    required String name,
    double sellingPrice = 0,
    String? description,
    String? notes,
    String? imagePath,
  }) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    if (name.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty.');
    }

    if (sellingPrice < 0) {
      throw ArgumentError('Selling price cannot be negative.');
    }

    final List<Map<String, Object?>> product = await db.query(
      'products',
      columns: ['id'],
      where: '''
        id = ?
        AND business_id = ?
      ''',
      whereArgs: [productId, businessId],
      limit: 1,
    );

    if (product.isEmpty) {
      throw StateError('Product not found.');
    }

    final List<Map<String, Object?>> recipes = await db.query(
      'recipes',
      columns: ['id'],
      where: '''
        id = ?
        AND business_id = ?
        AND is_active = 1
      ''',
      whereArgs: [recipeId, businessId],
      limit: 1,
    );

    if (recipes.isEmpty) {
      throw StateError('Selected recipe was not found.');
    }

    final List<Map<String, Object?>> units = await db.query(
      'units',
      columns: ['id'],
      where: '''
        id = ?
        AND is_active = 1
      ''',
      whereArgs: [unitId],
      limit: 1,
    );

    if (units.isEmpty) {
      throw StateError('Selected unit was not found.');
    }

    await db.update(
      'products',
      {
        'recipe_id': recipeId,
        'unit_id': unitId,
        'name': name.trim(),
        'selling_price': sellingPrice,
        'description': description,
        'notes': notes,
        'image_path': imagePath,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: '''
        id = ?
        AND business_id = ?
      ''',
      whereArgs: [productId, businessId],
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE - SOFT DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteProduct(String productId) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    await db.update(
      'products',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: '''
        id = ?
        AND business_id = ?
      ''',
      whereArgs: [productId, businessId],
    );
  }

  // ---------------------------------------------------------------------------
  // AVAILABLE RECIPES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getAvailableRecipes() async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    return db.query(
      'recipes',
      columns: ['id', 'name', 'description', 'labour_hours', 'labour_rate'],
      where: '''
        business_id = ?
        AND is_active = 1
      ''',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
  }

  // ---------------------------------------------------------------------------
  // AVAILABLE UNITS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getAvailableUnits() async {
    final Database db = await _appDatabase.database;

    return db.query(
      'units',
      columns: ['id', 'name', 'symbol'],
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // STOCK
  // ---------------------------------------------------------------------------

  Future<double> getProductStock(String productId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> result = await db.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(quantity),
          0
        ) AS current_stock
      FROM product_stock_movements
      WHERE product_id = ?
      ''',
      [productId],
    );

    if (result.isEmpty) {
      return 0;
    }

    return (result.first['current_stock'] as num?)?.toDouble() ?? 0;
  }

  // ---------------------------------------------------------------------------
  // PRODUCE PRODUCT
  // ---------------------------------------------------------------------------

  Future<String> produceProduct({
    required String recipeId,
    required String productName,
    required String unitId,
    required double quantity,
    required String? makerName,
    required double materialCost,
    required double labourCost,
    required double productionExpense,
    required double totalCost,
    required double targetSellingPrice,
    String? notes,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Production quantity must be greater than zero.');
    }

    if (productName.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty.');
    }

    if (materialCost < 0 ||
        labourCost < 0 ||
        productionExpense < 0 ||
        totalCost < 0 ||
        targetSellingPrice < 0) {
      throw ArgumentError(
        'Production costs and selling price cannot be negative.',
      );
    }

    final Database db = await _appDatabase.database;
    final String businessId = await _getBusinessId(db);

    final String productionId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    return db.transaction<String>((Transaction transaction) async {
      // ---------------------------------------------------------------
      // 1. Collect all raw-material requirements.
      //    This supports nested recipes.
      // ---------------------------------------------------------------

      final Map<String, double> requiredMaterials = <String, double>{};

      final Set<String> calculationPath = <String>{};

      await _collectRequiredMaterials(
        transaction,
        recipeId,
        quantity,
        requiredMaterials,
        calculationPath,
      );

      // ---------------------------------------------------------------
      // 2. Check raw-material stock before changing anything.
      // ---------------------------------------------------------------

      for (final MapEntry<String, double> entry in requiredMaterials.entries) {
        final String materialId = entry.key;
        final double requiredQuantity = entry.value;

        final List<Map<String, Object?>> stockRows = await transaction.rawQuery(
          '''
            SELECT
              COALESCE(
                SUM(material_stock_movements.quantity),
                0
              ) AS current_stock
            FROM material_stock_movements
            WHERE material_id = ?
              AND business_id = ?
            ''',
          [materialId, businessId],
        );

        final double currentStock =
            (stockRows.first['current_stock'] as num?)?.toDouble() ?? 0;

        if (currentStock < requiredQuantity) {
          final List<Map<String, Object?>> materialRows = await transaction
              .query(
                'materials',
                columns: ['name'],
                where: '''
                id = ?
                AND business_id = ?
              ''',
                whereArgs: [materialId, businessId],
                limit: 1,
              );

          final String materialName = materialRows.isNotEmpty
              ? materialRows.first['name'] as String
              : materialId;

          throw StateError(
            'Not enough stock for "$materialName". '
            'Required: $requiredQuantity, '
            'Available: $currentStock.',
          );
        }
      }

      // ---------------------------------------------------------------
      // 3. Find existing product by recipe + name.
      //    If it doesn't exist, create it.
      // ---------------------------------------------------------------

      final List<Map<String, Object?>> existingProducts = await transaction
          .query(
            'products',
            columns: ['id'],
            where: '''
            business_id = ?
            AND name = ?
            AND is_active = 1
          ''',
            whereArgs: [businessId, productName.trim()],
            limit: 1,
          );

      String productId;

      if (existingProducts.isNotEmpty) {
        productId = existingProducts.first['id'] as String;

        // Update the current suggested selling price.
        await transaction.update(
          'products',
          {
            'recipe_id': recipeId,
            'unit_id': unitId,
            'selling_price': targetSellingPrice,
            'updated_at': now,
          },
          where: '''
              id = ?
              AND business_id = ?
            ''',
          whereArgs: [productId, businessId],
        );
      } else {
        productId = _uuid.v4();

        await transaction.insert('products', {
          'id': productId,
          'business_id': businessId,
          'recipe_id': recipeId,
          'unit_id': unitId,
          'name': productName.trim(),
          'selling_price': targetSellingPrice,
          'description': null,
          'notes': notes,
          'image_path': null,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      // ---------------------------------------------------------------
      // 4. Save production record.
      //
      // materialCost and labourCost are PER UNIT.
      // productionExpense is WHOLE BATCH.
      // totalCost is WHOLE BATCH.
      // ---------------------------------------------------------------

      await transaction.insert('production_records', {
        'id': productionId,
        'business_id': businessId,
        'product_id': productId,
        'recipe_id': recipeId,
        'quantity': quantity,
        'maker_name': makerName,
        'material_cost': materialCost * quantity,
        'labour_cost': labourCost * quantity,
        'production_expense': productionExpense,
        'total_cost': totalCost,
        'production_date': now,
        'notes': notes,
        'created_at': now,
        'updated_at': now,
      });

      // ---------------------------------------------------------------
      // 5. Deduct raw materials.
      // ---------------------------------------------------------------

      for (final MapEntry<String, double> entry in requiredMaterials.entries) {
        await transaction.insert('material_stock_movements', {
          'id': _uuid.v4(),
          'business_id': businessId,
          'material_id': entry.key,
          'quantity': -entry.value,
          'reference_id': productionId,
          'notes': 'Used for production of $productName',
          'movement_date': now,
          'created_at': now,
          'movement_type': 'PRODUCTION',
        });
      }

      // ---------------------------------------------------------------
      // 6. Add finished product stock.
      // ---------------------------------------------------------------

      await transaction.insert('product_stock_movements', {
        'id': _uuid.v4(),
        'business_id': businessId,
        'product_id': productId,
        'movement_type': 'PRODUCTION',
        'quantity': quantity,
        'reference_id': productionId,
        'notes': notes,
        'movement_date': now,
        'created_at': now,
      });

      return productId;
    });
  }

  // ---------------------------------------------------------------------------
  // COLLECT RAW MATERIALS FROM RECIPE
  // ---------------------------------------------------------------------------

  Future<void> _collectRequiredMaterials(
    DatabaseExecutor db,
    String recipeId,
    double multiplier,
    Map<String, double> requiredMaterials,
    Set<String> calculationPath,
  ) async {
    if (calculationPath.contains(recipeId)) {
      throw StateError('Circular recipe reference detected.');
    }

    final Set<String> currentPath = <String>{...calculationPath, recipeId};

    final List<Map<String, Object?>> ingredients = await db.rawQuery(
      '''
      SELECT
        material_id,
        component_recipe_id,
        quantity
      FROM recipe_ingredients
      WHERE recipe_id = ?
      ''',
      [recipeId],
    );

    for (final Map<String, Object?> ingredient in ingredients) {
      final double ingredientQuantity = (ingredient['quantity'] as num)
          .toDouble();

      final double requiredQuantity = ingredientQuantity * multiplier;

      final String? materialId = ingredient['material_id'] as String?;

      final String? componentRecipeId =
          ingredient['component_recipe_id'] as String?;

      if (materialId != null) {
        requiredMaterials[materialId] =
            (requiredMaterials[materialId] ?? 0) + requiredQuantity;
      } else if (componentRecipeId != null) {
        await _collectRequiredMaterials(
          db,
          componentRecipeId,
          requiredQuantity,
          requiredMaterials,
          currentPath,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // READ - PRODUCTION HISTORY
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getProductionHistory(
    String productId,
  ) async {
    final Database db = await _appDatabase.database;

    final String businessId = await _getBusinessId(db);

    return db.rawQuery(
      '''
    SELECT
      production_records.id,
      production_records.product_id,
      production_records.recipe_id,
      production_records.quantity,
      production_records.maker_name,
      production_records.material_cost,
      production_records.labour_cost,
      production_records.production_expense,
      production_records.total_cost,
      production_records.production_date,
      production_records.notes,
      recipes.name AS recipe_name
    FROM production_records
    INNER JOIN recipes
      ON recipes.id = production_records.recipe_id
    WHERE production_records.product_id = ?
      AND production_records.business_id = ?
    ORDER BY production_records.production_date DESC
    ''',
      [productId, businessId],
    );
  }
}
