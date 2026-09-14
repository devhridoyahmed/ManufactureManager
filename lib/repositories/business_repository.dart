import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class BusinessRepository {
  BusinessRepository({
    AppDatabase? appDatabase,
    Uuid? uuid,
  })  : _appDatabase = appDatabase ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<String> getOrCreateBusiness() async {
    final Database db = await _appDatabase.database;

    final List<Map<String, Object?>> existingBusinesses =
        await db.query(
      'businesses',
      columns: ['id'],
      orderBy: 'created_at ASC',
      limit: 1,
    );

    if (existingBusinesses.isNotEmpty) {
      return existingBusinesses.first['id'] as String;
    }

    final String businessId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    await db.transaction((transaction) async {
      await transaction.insert(
        'businesses',
        {
          'id': businessId,
          'name': 'Manufacturing Manager',
          'owner_name': null,
          'mobile': null,
          'address': null,
          'logo_path': null,
          'currency': 'BDT',
          'created_at': now,
          'updated_at': now,
        },
      );

      await transaction.insert(
        'business_settings',
        {
          'id': _uuid.v4(),
          'business_id': businessId,
          'default_labour_rate': 0,
          'default_stock_alert_qty': 0,
          'default_payment_status': 'UNPAID',
          'default_order_status': 'ORDERED',
          'created_at': now,
          'updated_at': now,
        },
      );

      final List<Map<String, Object?>> units =
          await transaction.query(
        'units',
        columns: ['id'],
        orderBy: 'name ASC',
      );

      for (final Map<String, Object?> unit in units) {
        await transaction.insert(
          'business_units',
          {
            'id': _uuid.v4(),
            'business_id': businessId,
            'unit_id': unit['id'],
            'is_active': 1,
            'created_at': now,
          },
        );
      }
    });

    return businessId;
  }
}