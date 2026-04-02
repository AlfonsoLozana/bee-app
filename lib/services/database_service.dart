import 'dart:math' show sqrt, min, max;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'libre_link_service.dart';
import '../models/insulin_reading.dart';
import '../models/daily_pattern_reading.dart';

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
      version: 2,
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
          'CREATE INDEX idx_timestamp ON glucose_readings(timestamp DESC)',
        );

        // Tabla de dosis de insulina
        await db.execute('''
          CREATE TABLE dose_records (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp    INTEGER NOT NULL,   -- epoch ms
            type         TEXT NOT NULL,      -- 'rapid', 'basal', 'correction'
            units        REAL NOT NULL,
            insulin_name TEXT NOT NULL,
            note         TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_dose_timestamp ON dose_records(timestamp DESC)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE dose_records (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp    INTEGER NOT NULL,
              type         TEXT NOT NULL,
              units        REAL NOT NULL,
              insulin_name TEXT NOT NULL,
              note         TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_dose_timestamp ON dose_records(timestamp DESC)',
          );
        }
      },
    );
  }

  /// Inserta o actualiza si ya existe (UNIQUE en timestamp)
  /// La API de LibreLink ajusta valores con el tiempo, por lo que actualizamos
  static Future<void> insertReadings(List<GlucoseReading> readings) async {
    final db = await database;
    final batch = db.batch();
    for (final r in readings) {
      batch.insert(
        'glucose_readings',
        {
          'timestamp': r.timestamp.millisecondsSinceEpoch,
          'value': r.value,
          'is_high': r.isHigh ? 1 : 0,
          'is_low': r.isLow ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ); // ✅ SOBRESCRIBE si existe
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

    return rows
        .map(
          (row) => GlucoseReading(
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            value: row['value'] as double,
            isHigh: (row['is_high'] as int) == 1,
            isLow: (row['is_low'] as int) == 1,
          ),
        )
        .toList();
  }

  /// Lecturas desde un timestamp específico (para día natural)
  static Future<List<GlucoseReading>> getReadingsSince(
    int sinceTimestamp,
  ) async {
    final db = await database;

    final rows = await db.query(
      'glucose_readings',
      where: 'timestamp >= ?',
      whereArgs: [sinceTimestamp],
      orderBy: 'timestamp ASC',
    );

    return rows
        .map(
          (row) => GlucoseReading(
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            value: row['value'] as double,
            isHigh: (row['is_high'] as int) == 1,
            isLow: (row['is_low'] as int) == 1,
          ),
        )
        .toList();
  }

  /// Lecturas agregadas por intervalos de tiempo desde medianoche (para día natural con promedio)
  ///
  /// Este método agrupa lecturas en intervalos de N minutos desde las 00:00 del día actual
  /// y calcula el promedio de todas las lecturas en cada intervalo.
  ///
  /// @param intervalMinutes: tamaño del intervalo en minutos (ej: 5 para franjas de 5 min)
  /// @return: Lista de lecturas promediadas por intervalo temporal
  static Future<List<GlucoseReading>> getAggregatedReadings({
    int intervalMinutes = 5,
  }) async {
    final db = await database;

    // Calcular timestamp de medianoche (00:00 del día actual)
    final now = DateTime.now();
    final startOfDay = now.copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
    );
    final startTimestamp = startOfDay.millisecondsSinceEpoch;

    // Obtener todas las lecturas del día
    final rows = await db.rawQuery(
      '''
      SELECT 
        timestamp,
        value
      FROM glucose_readings
      WHERE timestamp >= ?
      ORDER BY timestamp ASC
    ''',
      [startTimestamp],
    );

    if (rows.isEmpty) return [];

    // Agrupar por intervalo de minutos
    final Map<int, List<double>> intervals = {};

    for (final row in rows) {
      final ts = DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);
      final minuteOfDay = ts.hour * 60 + ts.minute;

      // Redondear al intervalo más cercano
      final intervalKey = (minuteOfDay ~/ intervalMinutes) * intervalMinutes;

      intervals.putIfAbsent(intervalKey, () => []);
      intervals[intervalKey]!.add((row['value'] as num).toDouble());
    }

    // Calcular promedio para cada intervalo y crear lecturas
    final result = <GlucoseReading>[];

    for (final entry
        in intervals.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      final minuteOfDay = entry.key;
      final values = entry.value;

      if (values.isEmpty) continue;

      // Calcular promedio
      final avgValue = values.reduce((a, b) => a + b) / values.length;

      // Crear timestamp para este intervalo
      final intervalTime = startOfDay.add(Duration(minutes: minuteOfDay));

      result.add(
        GlucoseReading(
          timestamp: intervalTime,
          value: avgValue,
          isHigh: false, // No calculamos límites en agregaciones
          isLow: false,
        ),
      );
    }

    return result;
  }

  /// Lectura más reciente
  static Future<GlucoseReading?> getLatestReading() async {
    final db = await database;
    final rows = await db.query(
      'glucose_readings',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GlucoseReading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      value: row['value'] as double,
      isHigh: (row['is_high'] as int) == 1,
      isLow: (row['is_low'] as int) == 1,
    );
  }

  /// Stats del día actual (mantener para compatibilidad)
  static Future<Map<String, double>> getDayStats() async {
    return getStatsForPeriod(hours: 24);
  }

  /// Stats genérico para cualquier período de horas
  /// @param hours: número de horas hacia atrás desde ahora
  /// @param lowLimit: límite bajo personalizado para TIR
  /// @param highLimit: límite alto personalizado para TIR
  static Future<Map<String, double>> getStatsForPeriod({
    required int hours,
    int lowLimit = 70,
    int highLimit = 180,
  }) async {
    final db = await database;
    final since = DateTime.now()
        .subtract(Duration(hours: hours))
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT
        MIN(value)  AS min_val,
        MAX(value)  AS max_val,
        AVG(value)  AS avg_val,
        COUNT(*)    AS total,
        SUM(CASE WHEN value >= ? AND value <= ? THEN 1 ELSE 0 END) AS in_range,
        SUM(CASE WHEN value > ? THEN 1 ELSE 0 END) AS above_range,
        SUM(CASE WHEN value < ? THEN 1 ELSE 0 END) AS below_range,
        SUM(CASE WHEN value > 240 THEN 1 ELSE 0 END) AS critical_high
      FROM glucose_readings
      WHERE timestamp >= ?
    ''',
      [lowLimit, highLimit, highLimit, lowLimit, since],
    );

    if (rows.isEmpty || rows.first['total'] == 0) {
      return {
        'min': 0,
        'max': 0,
        'avg': 0,
        'tir': 0,
        'above_range': 0,
        'below_range': 0,
        'critical_high': 0,
      };
    }

    final r = rows.first;
    final total = (r['total'] as int).toDouble();
    final inRange = (r['in_range'] as int).toDouble();
    final aboveRange = (r['above_range'] as int).toDouble();
    final belowRange = (r['below_range'] as int).toDouble();
    final criticalHigh = (r['critical_high'] as int).toDouble();

    return {
      'min': (r['min_val'] as num?)?.toDouble() ?? 0,
      'max': (r['max_val'] as num?)?.toDouble() ?? 0,
      'avg': (r['avg_val'] as num?)?.toDouble() ?? 0,
      'tir': total > 0 ? (inRange / total * 100) : 0,
      'above_range': total > 0 ? (aboveRange / total * 100) : 0,
      'below_range': total > 0 ? (belowRange / total * 100) : 0,
      'critical_high': total > 0 ? (criticalHigh / total * 100) : 0,
    };
  }

  /// Calcular coeficiente de variación del día actual (mantener para compatibilidad)
  static Future<double> getCVToday() async {
    return getCVForPeriod(hours: 24);
  }

  /// Calcular coeficiente de variación para cualquier período
  /// @param hours: número de horas hacia atrás desde ahora
  static Future<double> getCVForPeriod({required int hours}) async {
    final db = await database;
    final since = DateTime.now()
        .subtract(Duration(hours: hours))
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT value FROM glucose_readings WHERE timestamp >= ?
    ''',
      [since],
    );

    if (rows.length < 2) return 0.0;

    final values = rows.map((r) => r['value'] as double).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final stddev = sqrt(variance);

    return mean > 0 ? (stddev / mean) * 100 : 0.0;
  }

  /// Obtener promedio de ayer (retorna null si no hay datos)
  static Future<double?> getYesterdayAverage() async {
    final db = await database;
    final now = DateTime.now();
    final startOfYesterday = now
        .subtract(const Duration(days: 1))
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;
    final endOfYesterday = now
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT AVG(value) AS avg_val, COUNT(*) AS total
      FROM glucose_readings
      WHERE timestamp >= ? AND timestamp < ?
    ''',
      [startOfYesterday, endOfYesterday],
    );

    if (rows.isEmpty || rows.first['total'] == 0) return null;

    return (rows.first['avg_val'] as num?)?.toDouble();
  }

  /// Calcular patrón glucémico diario promedio
  ///
  /// Este método agrupa lecturas por franja horaria del día (ej: 08:00-08:05)
  /// y calcula la media y desviación estándar para cada franja basándose en
  /// múltiples días de datos. El resultado es un "día típico" que muestra
  /// el patrón glucémico promedio.
  ///
  /// @param days: número de días completos hacia atrás desde hoy
  /// @param intervalMinutes: resolución temporal (1 min = 1440 franjas/día, 5 min = 288 franjas/día)
  /// @return: Lista de lecturas promedio por franja horaria (00:00-24:00)
  static Future<List<DailyPatternReading>> getDailyPattern({
    required int days,
    int intervalMinutes = 1,
  }) async {
    final db = await database;

    // Calcular rango de días (días completos hacia atrás)
    final now = DateTime.now();
    final startDate = now
        .subtract(Duration(days: days))
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final since = startDate.millisecondsSinceEpoch;

    // Obtener todas las lecturas del período
    final rows = await db.rawQuery(
      '''
      SELECT 
        timestamp,
        value
      FROM glucose_readings
      WHERE timestamp >= ?
      ORDER BY timestamp ASC
    ''',
      [since],
    );

    if (rows.isEmpty) return [];

    // Agrupar por franja horaria del día
    // Clave: minutos desde medianoche (0-1439)
    // Valor: List<double> valores de glucosa
    final Map<int, List<double>> timeSlots = {};

    for (final row in rows) {
      final ts = DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);
      final minuteOfDay = ts.hour * 60 + ts.minute;

      // Redondear a la franja de intervalo más cercana
      final slotMinute = (minuteOfDay ~/ intervalMinutes) * intervalMinutes;

      timeSlots.putIfAbsent(slotMinute, () => []);
      timeSlots[slotMinute]!.add((row['value'] as num).toDouble());
    }

    // Calcular estadísticas para cada franja
    final result = <DailyPatternReading>[];

    for (int minute = 0; minute < 1440; minute += intervalMinutes) {
      final values = timeSlots[minute];

      // Requiere al menos 2 lecturas para calcular desviación
      if (values == null || values.length < 2) continue;

      final mean = values.reduce((a, b) => a + b) / values.length;
      final stdDev = DailyPatternReading.calculateStdDev(values, mean);
      final minVal = values.reduce(min);
      final maxVal = values.reduce(max);

      result.add(
        DailyPatternReading(
          timeOfDay: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
          mean: mean,
          stdDev: stdDev,
          min: minVal,
          max: maxVal,
          sampleCount: values.length,
        ),
      );
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────
  // Métodos para dosis de insulina
  // ─────────────────────────────────────────────────────────────

  /// Insertar una nueva dosis
  static Future<void> insertDose(DoseRecord dose) async {
    final db = await database;
    await db.insert('dose_records', {
      'timestamp': dose.timestamp.millisecondsSinceEpoch,
      'type': dose.type.name,
      'units': dose.units,
      'insulin_name': dose.insulinName,
      'note': dose.note,
    });
  }

  /// Obtener dosis del día actual
  static Future<List<DoseRecord>> getDosesToday() async {
    final db = await database;
    final startOfDay = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;

    final rows = await db.query(
      'dose_records',
      where: 'timestamp >= ?',
      whereArgs: [startOfDay],
      orderBy: 'timestamp DESC',
    );

    return rows
        .map(
          (row) => DoseRecord(
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            type: DoseType.values.firstWhere((t) => t.name == row['type']),
            units: row['units'] as double,
            insulinName: row['insulin_name'] as String,
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  /// Obtener las N dosis más recientes
  static Future<List<DoseRecord>> getRecentDoses({int limit = 10}) async {
    final db = await database;

    final rows = await db.query(
      'dose_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return rows
        .map(
          (row) => DoseRecord(
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            type: DoseType.values.firstWhere((t) => t.name == row['type']),
            units: row['units'] as double,
            insulinName: row['insulin_name'] as String,
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  /// Eliminar una dosis
  static Future<void> deleteDose(DoseRecord dose) async {
    final db = await database;
    await db.delete(
      'dose_records',
      where: 'timestamp = ?',
      whereArgs: [dose.timestamp.millisecondsSinceEpoch],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Detección de eventos críticos (hipos e hipers)
  // ─────────────────────────────────────────────────────────────

  /// Detectar eventos de hipoglucemia e hiperglucemia
  /// Un evento se cuenta cuando hay ≥15 minutos continuos fuera de umbral
  /// @param hours: número de horas hacia atrás desde ahora
  /// @param hypoThreshold: umbral de hipoglucemia (default 70 mg/dL)
  /// @param hyperThreshold: umbral de hiperglucemia (default 250 mg/dL)
  /// @return Map con contadores de eventos: {'hypo_count': int, 'hyper_count': int}
  static Future<Map<String, int>> getHypoHyperEvents({
    required int hours,
    int hypoThreshold = 70,
    int hyperThreshold = 250,
  }) async {
    final db = await database;
    final since = DateTime.now()
        .subtract(Duration(hours: hours))
        .millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT timestamp, value
      FROM glucose_readings
      WHERE timestamp >= ?
      ORDER BY timestamp ASC
    ''',
      [since],
    );

    if (rows.isEmpty) {
      return {'hypo_count': 0, 'hyper_count': 0};
    }

    int hypoCount = 0;
    int hyperCount = 0;

    DateTime? hypoStartTime;
    DateTime? hyperStartTime;

    const minEventDuration = Duration(minutes: 15);

    for (int i = 0; i < rows.length; i++) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        rows[i]['timestamp'] as int,
      );
      final value = (rows[i]['value'] as num).toDouble();

      // Detectar hipoglucemia
      if (value < hypoThreshold) {
        hypoStartTime ??= timestamp;
      } else {
        // Salió del rango de hipo
        if (hypoStartTime != null) {
          final duration = timestamp.difference(hypoStartTime);
          if (duration >= minEventDuration) {
            hypoCount++;
          }
          hypoStartTime = null;
        }
      }

      // Detectar hiperglucemia
      if (value > hyperThreshold) {
        hyperStartTime ??= timestamp;
      } else {
        // Salió del rango de hiper
        if (hyperStartTime != null) {
          final duration = timestamp.difference(hyperStartTime);
          if (duration >= minEventDuration) {
            hyperCount++;
          }
          hyperStartTime = null;
        }
      }
    }

    // Verificar si el último evento continúa hasta el final
    final lastTimestamp = DateTime.fromMillisecondsSinceEpoch(
      rows.last['timestamp'] as int,
    );

    if (hypoStartTime != null) {
      final duration = lastTimestamp.difference(hypoStartTime);
      if (duration >= minEventDuration) {
        hypoCount++;
      }
    }

    if (hyperStartTime != null) {
      final duration = lastTimestamp.difference(hyperStartTime);
      if (duration >= minEventDuration) {
        hyperCount++;
      }
    }

    return {'hypo_count': hypoCount, 'hyper_count': hyperCount};
  }
}
