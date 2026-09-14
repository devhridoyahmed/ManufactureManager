import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';
import 'database_schema.dart';

class AppDatabase {
  AppDatabase._privateConstructor();

  static final AppDatabase instance =
      AppDatabase._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();

    final databasePath = join(
      databasesPath,
      'karukano_business_manager.db',
    );

    return openDatabase(
      databasePath,
      version: DatabaseSchema.version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await DatabaseSchema.create(db);
        await DatabaseSchema.seedUnits(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await DatabaseMigrations.migrate(
          db,
          oldVersion,
          newVersion,
        );
      },
    );
  }

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}