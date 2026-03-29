import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'libre_link_service.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'insulin_tracker.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE glucose_readings (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL UNIQUE,  -- epoch ms
            value     REAL NOT NULL,
            is_high   INTEGER NOT NULL DEFAULT 0,
            is_low    INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // Índice para queries por rango de tiempo (muy frecuentes)
        await db.execute(
          'CREATE INDEX idx_timestamp ON glucose_readings(timestamp DESC)');
      },
    );
  }

  /// Inserta o ignora si ya existe (UNIQUE en timestamp)
  static Future<void> insertReadings(List<GlucoseReading> readings) async {
    final db = await database;
    final batch = db.batch();
    for (final r in readings) {
      batch.insert('glucose_readings', {
        'timestamp': r.timestamp.millisecondsSinceEpoch,
        'value':     r.value,
        'is_high':   r.isHigh ? 1 : 0,
        'is_low':    r.isLow  ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// Lecturas de las últimas N horas, ordenadas por tiempo
  static Future<List<GlucoseReading>> getReadings({int hours = 24}) async {
    final db = await database;
    final since = DateTime.now()
        .subtract(Duration(hours: hours))
        .millisecondsSinceEpoch;

    final rows = await db.query(
      'glucose_readings',
      where: 'timestamp >= ?',
      whereArgs: [since],
      orderBy: 'timestamp ASC',
    );

    return rows.map((row) => GlucoseReading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      value:     row['value'] as double,
      isHigh:    (row['is_high'] as int) == 1,
      isLow:     (row['is_low']  as int) == 1,
    )).toList();
  }

  /// Lectura más reciente
  static Future<GlucoseReading?> getLatestReading() async {
    final db = await database;
    final rows = await db.query('glucose_readings',
      orderBy: 'timestamp DESC', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GlucoseReading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      value:     row['value'] as double,
      isHigh:    (row['is_high'] as int) == 1,
      isLow:     (row['is_low']  as int) == 1,
    );
  }

  /// Stats del día actual
  static Future<Map<String, double>> getDayStats() async {
    final db = await database;
    final startOfDay = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery('''
      SELECT
        MIN(value)  AS min_val,
        MAX(value)  AS max_val,
        AVG(value)  AS avg_val,
        COUNT(*)    AS total,
        SUM(CASE WHEN value >= 70 AND value <= 180 THEN 1 ELSE 0 END) AS in_range
      FROM glucose_readings
      WHERE timestamp >= ?
    ''', [startOfDay]);

    if (rows.isEmpty || rows.first['total'] == 0) {
      return {'min': 0, 'max': 0, 'avg': 0, 'tir': 0};
    }

    final r = rows.first;
    final total   = (r['total'] as int).toDouble();
    final inRange = (r['in_range'] as int).toDouble();

    return {
      'min': (r['min_val'] as num?)?.toDouble() ?? 0,
      'max': (r['max_val'] as num?)?.toDouble() ?? 0,
      'avg': (r['avg_val'] as num?)?.toDouble() ?? 0,
      'tir': total > 0 ? (inRange / total * 100) : 0,
    };
  }
}