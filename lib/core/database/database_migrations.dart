import 'package:sqflite/sqflite.dart';

class DatabaseMigrations {
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion + 1;
        version <= newVersion;
        version++) {
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
      }
    }
  }
}