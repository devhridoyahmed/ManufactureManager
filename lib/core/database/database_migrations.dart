import 'package:sqflite/sqflite.dart';

class DatabaseMigrations {
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 1:
          // Version 1 is created directly in onCreate.
          break;

        case 2:
          // Already handled in the original database.
          break;

        case 3:
          // Already handled in the original database.
          break;

        case 4:
          await db.execute('''
            CREATE TABLE IF NOT EXISTS material_purchases (
              id TEXT PRIMARY KEY,
              business_id TEXT NOT NULL,
              material_id TEXT NOT NULL,
              quantity REAL NOT NULL,
              total_cost REAL NOT NULL,
              unit_cost REAL NOT NULL,
              supplier_name TEXT,
              purchase_date TEXT NOT NULL,
              notes TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (business_id)
                REFERENCES businesses(id)
                ON DELETE CASCADE,
              FOREIGN KEY (material_id)
                REFERENCES materials(id)
                ON DELETE RESTRICT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS material_stock_movements (
              id TEXT PRIMARY KEY,
              business_id TEXT NOT NULL,
              material_id TEXT NOT NULL,
              movement_type TEXT NOT NULL,
              quantity REAL NOT NULL,
              reference_id TEXT,
              notes TEXT,
              movement_date TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (business_id)
                REFERENCES businesses(id)
                ON DELETE CASCADE,
              FOREIGN KEY (material_id)
                REFERENCES materials(id)
                ON DELETE RESTRICT
            )
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS
            idx_material_purchases_material
            ON material_purchases(material_id)
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS
            idx_material_purchases_business
            ON material_purchases(business_id)
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS
            idx_material_stock_movements_material
            ON material_stock_movements(material_id)
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS
            idx_material_stock_movements_business
            ON material_stock_movements(business_id)
          ''');

          break;

        case 5:
          // Version 5 uses the existing
          // material_stock_movements table.
          //
          // No new table or column is required.
          // Stock removal will be saved as a negative quantity.
          break;

        case 6:
          await db.execute('''
    CREATE TABLE IF NOT EXISTS recipes (
      id TEXT PRIMARY KEY,
      business_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      labour_hours REAL NOT NULL DEFAULT 0,
      labour_rate REAL NOT NULL DEFAULT 0,
      notes TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE (business_id, name),
      FOREIGN KEY (business_id)
        REFERENCES businesses(id)
        ON DELETE CASCADE
    )
  ''');

          await db.execute('''
    CREATE INDEX IF NOT EXISTS
    idx_recipes_business
    ON recipes(business_id)
  ''');

          break;

        case 7:
          await db.execute('''
    CREATE TABLE IF NOT EXISTS recipe_ingredients (
      id TEXT PRIMARY KEY,
      business_id TEXT NOT NULL,
      recipe_id TEXT NOT NULL,
      material_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_id TEXT NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (business_id)
        REFERENCES businesses(id)
        ON DELETE CASCADE,
      FOREIGN KEY (recipe_id)
        REFERENCES recipes(id)
        ON DELETE CASCADE,
      FOREIGN KEY (material_id)
        REFERENCES materials(id)
        ON DELETE RESTRICT,
      FOREIGN KEY (unit_id)
        REFERENCES units(id)
        ON DELETE RESTRICT
    )
  ''');

        case 8:
          await db.transaction((transaction) async {
            await transaction.execute('''
      CREATE TABLE recipe_ingredients_new (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        recipe_id TEXT NOT NULL,
        material_id TEXT,
        component_recipe_id TEXT,
        quantity REAL NOT NULL,
        unit_id TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,

        CHECK (
          (material_id IS NOT NULL AND component_recipe_id IS NULL)
          OR
          (material_id IS NULL AND component_recipe_id IS NOT NULL)
        ),

        FOREIGN KEY (business_id)
          REFERENCES businesses(id)
          ON DELETE CASCADE,

        FOREIGN KEY (recipe_id)
          REFERENCES recipes(id)
          ON DELETE CASCADE,

        FOREIGN KEY (material_id)
          REFERENCES materials(id)
          ON DELETE RESTRICT,

        FOREIGN KEY (component_recipe_id)
          REFERENCES recipes(id)
          ON DELETE RESTRICT,

        FOREIGN KEY (unit_id)
          REFERENCES units(id)
          ON DELETE RESTRICT
      )
    ''');

            await transaction.execute('''
      INSERT INTO recipe_ingredients_new (
        id,
        business_id,
        recipe_id,
        material_id,
        component_recipe_id,
        quantity,
        unit_id,
        notes,
        created_at,
        updated_at
      )
      SELECT
        id,
        business_id,
        recipe_id,
        material_id,
        NULL,
        quantity,
        unit_id,
        notes,
        created_at,
        updated_at
      FROM recipe_ingredients
    ''');

            await transaction.execute('DROP TABLE recipe_ingredients');

            await transaction.execute('''
      ALTER TABLE recipe_ingredients_new
      RENAME TO recipe_ingredients
    ''');

            await transaction.execute('''
      CREATE INDEX idx_recipe_ingredients_recipe
      ON recipe_ingredients(recipe_id)
    ''');

            await transaction.execute('''
      CREATE INDEX idx_recipe_ingredients_material
      ON recipe_ingredients(material_id)
    ''');

            await transaction.execute('''
      CREATE INDEX idx_recipe_ingredients_business
      ON recipe_ingredients(business_id)
    ''');

            await transaction.execute('''
      CREATE INDEX idx_recipe_ingredients_component_recipe
      ON recipe_ingredients(component_recipe_id)
    ''');
          });

          await db.execute('''
    CREATE INDEX IF NOT EXISTS
    idx_recipe_ingredients_recipe
    ON recipe_ingredients(recipe_id)
  ''');

          await db.execute('''
    CREATE INDEX IF NOT EXISTS
    idx_recipe_ingredients_material
    ON recipe_ingredients(material_id)
  ''');

          await db.execute('''
    CREATE INDEX IF NOT EXISTS
    idx_recipe_ingredients_business
    ON recipe_ingredients(business_id)
  ''');

          break;
      }
    }
  }
}
