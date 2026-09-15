import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  static const int version = 10;

  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE businesses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        owner_name TEXT,
        mobile TEXT,
        address TEXT,
        currency TEXT NOT NULL DEFAULT 'BDT',
        logo_path TEXT,
        description TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE business_settings (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL UNIQUE,
        default_labour_rate INTEGER NOT NULL DEFAULT 0,
        default_stock_alert_qty REAL NOT NULL DEFAULT 0,
        default_payment_status TEXT NOT NULL DEFAULT 'UNPAID',
        default_order_status TEXT NOT NULL DEFAULT 'ORDERED',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (business_id)
          REFERENCES businesses(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE units (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        symbol TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE business_units (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        UNIQUE (business_id, unit_id),
        FOREIGN KEY (business_id)
          REFERENCES businesses(id)
          ON DELETE CASCADE,
        FOREIGN KEY (unit_id)
          REFERENCES units(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE material_categories (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
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
      CREATE TABLE materials (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        category_id TEXT,
        unit_id TEXT NOT NULL,
        name TEXT NOT NULL,
        minimum_stock REAL NOT NULL DEFAULT 0,
        description TEXT,
        notes TEXT,
        image_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (business_id, name),
        FOREIGN KEY (business_id)
          REFERENCES businesses(id)
          ON DELETE CASCADE,
        FOREIGN KEY (category_id)
          REFERENCES material_categories(id)
          ON DELETE SET NULL,
        FOREIGN KEY (unit_id)
          REFERENCES units(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE recipes (
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
      CREATE TABLE recipe_ingredients (
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

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        recipe_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        name TEXT NOT NULL,
        selling_price REAL NOT NULL DEFAULT 0,
        description TEXT,
        notes TEXT,
        image_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,

        UNIQUE (business_id, name),

        FOREIGN KEY (business_id)
          REFERENCES businesses(id)
          ON DELETE CASCADE,

        FOREIGN KEY (recipe_id)
          REFERENCES recipes(id)
          ON DELETE RESTRICT,

        FOREIGN KEY (unit_id)
          REFERENCES units(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE product_stock_movements (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_id TEXT,
        notes TEXT,
        movement_date TEXT NOT NULL,
        created_at TEXT NOT NULL,

        FOREIGN KEY (business_id)
          REFERENCES businesses(id)
          ON DELETE CASCADE,

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE production_records (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        recipe_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        maker_name TEXT,
        material_cost REAL NOT NULL DEFAULT 0,
        labour_cost REAL NOT NULL DEFAULT 0,
        production_expense REAL NOT NULL DEFAULT 0,
        total_cost REAL NOT NULL DEFAULT 0,
        production_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,

        FOREIGN KEY (business_id)
          REFERENCES businesses(id)
          ON DELETE CASCADE,

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE RESTRICT,

        FOREIGN KEY (recipe_id)
          REFERENCES recipes(id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE material_purchases (
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
      CREATE TABLE material_stock_movements (
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

    await _createIndexes(db);
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX idx_business_settings_business
      ON business_settings(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_business_units_business
      ON business_units(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_material_categories_business
      ON material_categories(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_materials_business
      ON materials(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_materials_category
      ON materials(category_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_material_purchases_material
      ON material_purchases(material_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_material_purchases_business
      ON material_purchases(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_material_stock_movements_material
      ON material_stock_movements(material_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_material_stock_movements_business
      ON material_stock_movements(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_recipes_business
      ON recipes(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_recipe_ingredients_recipe
      ON recipe_ingredients(recipe_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_recipe_ingredients_material
      ON recipe_ingredients(material_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_recipe_ingredients_business
      ON recipe_ingredients(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_recipe_ingredients_component_recipe
      ON recipe_ingredients(component_recipe_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_products_business
      ON products(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_products_recipe
      ON products(recipe_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_product_stock_movements_product
      ON product_stock_movements(product_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_product_stock_movements_business
      ON product_stock_movements(business_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_production_records_product
      ON production_records(product_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_production_records_business
      ON production_records(business_id)
    ''');
  }

  static Future<void> seedUnits(Database db) async {
    final units = <Map<String, String>>[
      {'name': 'Piece', 'symbol': 'pc'},
      {'name': 'Meter', 'symbol': 'm'},
      {'name': 'Centimeter', 'symbol': 'cm'},
      {'name': 'Millimeter', 'symbol': 'mm'},
      {'name': 'Kilogram', 'symbol': 'kg'},
      {'name': 'Gram', 'symbol': 'g'},
      {'name': 'Liter', 'symbol': 'L'},
      {'name': 'Milliliter', 'symbol': 'ml'},
      {'name': 'Roll', 'symbol': 'roll'},
      {'name': 'Bundle', 'symbol': 'bundle'},
      {'name': 'Packet', 'symbol': 'pkt'},
      {'name': 'Box', 'symbol': 'box'},
      {'name': 'Set', 'symbol': 'set'},
      {'name': 'Pair', 'symbol': 'pair'},
      {'name': 'Dozen', 'symbol': 'dozen'},
      {'name': 'Bottle', 'symbol': 'bottle'},
      {'name': 'Bag', 'symbol': 'bag'},
      {'name': 'Sheet', 'symbol': 'sheet'},
      {'name': 'Yard', 'symbol': 'yd'},
      {'name': 'Foot', 'symbol': 'ft'},
      {'name': 'Inch', 'symbol': 'in'},
    ];

    for (final unit in units) {
      await db.insert(
        'units',
        {
          'id': _unitId(unit['symbol']!),
          'name': unit['name'],
          'symbol': unit['symbol'],
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static String _unitId(String symbol) {
    return 'unit_$symbol';
  }
}