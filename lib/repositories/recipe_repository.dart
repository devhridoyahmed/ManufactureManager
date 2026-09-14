import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class RecipeRepository {
  RecipeRepository({AppDatabase? appDatabase, Uuid? uuid})
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
      throw StateError('No business has been created yet.');
    }

    return businesses.first['id'] as String;
  }

  Future<List<Map<String, Object?>>> getRecipes() async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    return db.query(
      'recipes',
      where: 'business_id = ? AND is_active = 1',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, Object?>?> getRecipe(String recipeId) async {
    final Database db = await _appDatabase.database;

    final List<Map<String, Object?>> results = await db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: [recipeId],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return results.first;
  }

  Future<List<Map<String, Object?>>> getRecipeIngredients(
    String recipeId,
  ) async {
    final Database db = await _appDatabase.database;

    return db.rawQuery(
      '''
      SELECT
        recipe_ingredients.id,
        recipe_ingredients.recipe_id,
        recipe_ingredients.material_id,
        recipe_ingredients.component_recipe_id,
        recipe_ingredients.quantity,
        recipe_ingredients.unit_id,
        recipe_ingredients.notes,

        materials.name AS material_name,
        material_units.name AS material_unit_name,
        material_units.symbol AS material_unit_symbol,

        component_recipes.name AS component_recipe_name,

        units.name AS unit_name,
        units.symbol AS unit_symbol

      FROM recipe_ingredients

      LEFT JOIN materials
        ON materials.id = recipe_ingredients.material_id

      LEFT JOIN units AS material_units
        ON material_units.id = materials.unit_id

      LEFT JOIN recipes AS component_recipes
        ON component_recipes.id =
           recipe_ingredients.component_recipe_id

      INNER JOIN units
        ON units.id = recipe_ingredients.unit_id

      WHERE recipe_ingredients.recipe_id = ?

      ORDER BY
        CASE
          WHEN recipe_ingredients.material_id IS NOT NULL
          THEN 0
          ELSE 1
        END,
        COALESCE(
          materials.name,
          component_recipes.name
        ) ASC
      ''',
      [recipeId],
    );
  }

  Future<List<Map<String, Object?>>> getAvailableMaterials() async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    return db.rawQuery(
      '''
      SELECT
        materials.id,
        materials.name,
        materials.unit_id,
        units.name AS unit_name,
        units.symbol AS unit_symbol
      FROM materials
      INNER JOIN units
        ON units.id = materials.unit_id
      WHERE materials.business_id = ?
        AND materials.is_active = 1
      ORDER BY materials.name ASC
      ''',
      [businessId],
    );
  }

  Future<List<Map<String, Object?>>> getAvailableRecipes({
    String? excludeRecipeId,
  }) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    if (excludeRecipeId == null) {
      return db.query(
        'recipes',
        columns: ['id', 'name', 'description'],
        where: '''
          business_id = ?
          AND is_active = 1
        ''',
        whereArgs: [businessId],
        orderBy: 'name ASC',
      );
    }

    return db.query(
      'recipes',
      columns: ['id', 'name', 'description'],
      where: '''
        business_id = ?
        AND is_active = 1
        AND id != ?
      ''',
      whereArgs: [businessId, excludeRecipeId],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, Object?>>> getAvailableUnits() async {
    final Database db = await _appDatabase.database;

    return db.query(
      'units',
      columns: ['id', 'name', 'symbol'],
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
  }

  Future<String> createRecipe({
    required String name,
    String? description,
    double labourHours = 0,
    double labourRate = 0,
    String? notes,
  }) async {
    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final String recipeId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    await db.insert('recipes', {
      'id': recipeId,
      'business_id': businessId,
      'name': name.trim(),
      'description': description,
      'labour_hours': labourHours,
      'labour_rate': labourRate,
      'notes': notes,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    return recipeId;
  }

  Future<String> addIngredient({
    required String recipeId,
    String? materialId,
    String? componentRecipeId,
    required double quantity,
    required String unitId,
    String? notes,
  }) async {
    if (materialId == null && componentRecipeId == null) {
      throw ArgumentError(
        'Either materialId or componentRecipeId is required.',
      );
    }

    if (materialId != null && componentRecipeId != null) {
      throw ArgumentError(
        'Only one of materialId or componentRecipeId can be provided.',
      );
    }

    if (quantity <= 0) {
      throw ArgumentError('Ingredient quantity must be greater than zero.');
    }

    final Database db = await _appDatabase.database;
    final String businessId = await getBusinessId();

    final String ingredientId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    await db.insert('recipe_ingredients', {
      'id': ingredientId,
      'business_id': businessId,
      'recipe_id': recipeId,
      'material_id': materialId,
      'component_recipe_id': componentRecipeId,
      'quantity': quantity,
      'unit_id': unitId,
      'notes': notes,
      'created_at': now,
      'updated_at': now,
    });

    return ingredientId;
  }

  Future<void> updateRecipe({
    required String recipeId,
    required String name,
    String? description,
    double labourHours = 0,
    double labourRate = 0,
    String? notes,
  }) async {
    final Database db = await _appDatabase.database;

    await db.update(
      'recipes',
      {
        'name': name.trim(),
        'description': description,
        'labour_hours': labourHours,
        'labour_rate': labourRate,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [recipeId],
    );
  }

  Future<void> updateIngredient({
    required String ingredientId,
    required double quantity,
    required String unitId,
    String? notes,
  }) async {
    final Database db = await _appDatabase.database;

    await db.update(
      'recipe_ingredients',
      {
        'quantity': quantity,
        'unit_id': unitId,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [ingredientId],
    );
  }

  Future<void> deleteIngredient(String ingredientId) async {
    final Database db = await _appDatabase.database;

    await db.delete(
      'recipe_ingredients',
      where: 'id = ?',
      whereArgs: [ingredientId],
    );
  }

  Future<void> deleteRecipe(String recipeId) async {
    final Database db = await _appDatabase.database;

    await db.update(
      'recipes',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [recipeId],
    );
  }

  double calculateLabourCost({
    required double labourHours,
    required double labourRate,
  }) {
    return labourHours * labourRate;
  }

  Future<Map<String, double>> calculateRecipeCost(String recipeId) async {
    final Database db = await _appDatabase.database;

    final Set<String> calculationPath = <String>{};

    return _calculateRecipeCostRecursive(db, recipeId, calculationPath);
  }

  Future<Map<String, double>> _calculateRecipeCostRecursive(
    Database db,
    String recipeId,
    Set<String> calculationPath,
  ) async {
    if (calculationPath.contains(recipeId)) {
      throw StateError('Circular recipe reference detected.');
    }

    final Set<String> currentPath = <String>{...calculationPath, recipeId};

    final List<Map<String, Object?>> ingredients = await db.rawQuery(
      '''
      SELECT
        recipe_ingredients.quantity,
        recipe_ingredients.material_id,
        recipe_ingredients.component_recipe_id
      FROM recipe_ingredients
      WHERE recipe_ingredients.recipe_id = ?
      ''',
      [recipeId],
    );

    double materialCost = 0;
    double componentRecipeCost = 0;

    for (final ingredient in ingredients) {
      final double quantity = (ingredient['quantity'] as num).toDouble();

      final String? materialId = ingredient['material_id'] as String?;

      final String? componentRecipeId =
          ingredient['component_recipe_id'] as String?;

      if (materialId != null) {
        final List<Map<String, Object?>> purchases = await db.rawQuery(
          '''
          SELECT
            quantity,
            unit_cost
          FROM material_purchases
          WHERE material_id = ?
            AND quantity > 0
          ORDER BY purchase_date ASC, created_at ASC
          ''',
          [materialId],
        );

        double remainingQuantity = quantity;

        for (final purchase in purchases) {
          if (remainingQuantity <= 0) {
            break;
          }

          final double purchaseQuantity = (purchase['quantity'] as num)
              .toDouble();

          final double unitCost = (purchase['unit_cost'] as num).toDouble();

          final double usedQuantity = remainingQuantity < purchaseQuantity
              ? remainingQuantity
              : purchaseQuantity;

          materialCost += usedQuantity * unitCost;

          remainingQuantity -= usedQuantity;
        }
      } else if (componentRecipeId != null) {
        final Map<String, double> componentCost =
            await _calculateRecipeCostRecursive(
              db,
              componentRecipeId,
              currentPath,
            );

        componentRecipeCost += componentCost['totalCost']! * quantity;
      }
    }

    final List<Map<String, Object?>> recipes = await db.query(
      'recipes',
      columns: ['labour_hours', 'labour_rate'],
      where: 'id = ?',
      whereArgs: [recipeId],
      limit: 1,
    );

    double labourCost = 0;

    if (recipes.isNotEmpty) {
      final double labourHours =
          (recipes.first['labour_hours'] as num?)?.toDouble() ?? 0;

      final double labourRate =
          (recipes.first['labour_rate'] as num?)?.toDouble() ?? 0;

      labourCost = labourHours * labourRate;
    }

    final double combinedMaterialCost = materialCost + componentRecipeCost;

    return {
      'materialCost': combinedMaterialCost,
      'componentRecipeCost': componentRecipeCost,
      'labourCost': labourCost,
      'totalCost': combinedMaterialCost + labourCost,
    };
  }
}
