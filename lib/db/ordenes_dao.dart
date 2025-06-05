import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/orden_model.dart';
import 'db_helper.dart';

class OrdenesDAO {
  static const String tableName = 'ordenes';

  /// Inserta una orden en SQLite (FORZADA)
  static Future<void> insertOrden(Orden orden) async {
    final db = await DBHelper.initDb();

    try {
      // Validación ligera: solo que 'orden' no esté vacío
      if (orden.orden.isEmpty) {
        debugPrint('⚠️ Orden sin identificador no insertada: ${orden.toJson()}');
        return;
      }

      final data = orden.toMap();
      debugPrint('📥 Intentando insertar en SQLite: $data');

      final id = await db.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('✅ Insert OK: ${orden.orden} (rowid: $id)');
    } catch (e) {
      debugPrint('❌ Error al insertar orden ${orden.orden}: $e');
    }
  }

  /// Recupera todas las órdenes desde SQLite
  static Future<List<Orden>> getOrdenes() async {
    try {
      final db = await DBHelper.initDb();
      final List<Map<String, dynamic>> maps = await db.query(tableName);

      // debugPrint('📦 SQLite: ${maps.length} órdenes recuperadas.');
      return maps.map((map) => Orden.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error al recuperar órdenes de SQLite: $e');
      return [];
    }
  }

 

static Future<void> insertarListaOrdenes(List<Orden> nuevasOrdenes) async {
  final db = await DBHelper.initDb();

  try {
    // 🔄 Obtener órdenes actuales en SQLite
    final ordenesLocales = await getOrdenes();
    final pdfLocales = ordenesLocales
        .where((o) => o.pdfGenerado == true)
        .map((o) => o.orden)
        .toSet();

    final batch = db.batch();
    for (final orden in nuevasOrdenes) {
      if (orden.orden.isEmpty) continue;

      // ✅ Preserva pdfGenerado si ya estaba marcado en SQLite
      if (pdfLocales.contains(orden.orden)) {
        orden.pdfGenerado = true;
      }

      batch.insert(
        tableName,
        orden.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('✅ ${nuevasOrdenes.length} órdenes insertadas con estado pdfGenerado preservado.');
  } catch (e) {
    debugPrint('❌ Error al insertar lista de órdenes: $e');
  }
}

static Future<void> insertarOrden(Orden orden) async {
  // final db = await DBProvider.db.database;
  final db = await DBHelper.initDb();
  await db.insert('ordenes', orden.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
}

  /// Limpia la tabla de órdenes
  static Future<void> clearOrdenes() async {
    try {
      final db = await DBHelper.initDb();
      await db.delete(tableName);
      debugPrint('🧹 Tabla $tableName limpiada correctamente.');
    } catch (e) {
      debugPrint('❌ Error al limpiar la tabla $tableName: $e');
    }
  }
  /// Devuelve las órdenes locales no sincronizadas (LOCAL = 'S')
  static Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    final db = await DBHelper.initDb();
    return await db.query(
      'ordenes',
      where: 'LOCAL = ?',
      whereArgs: ['S'],
    );
  }
static Future<void> marcarPdfGenerado(String orden) async {
    final db = await DBHelper.initDb();
  await db.update(
    'ordenes',
    {'pdf_generado': 1},
    where: 'orden = ?',
    whereArgs: [orden],
  );
}

static Future<void> eliminarPorOrden(String orden) async {
  try {
    final db = await DBHelper.initDb();
    final filas = await db.delete(
      tableName,
      where: 'orden = ?',
      whereArgs: [orden],
    );

    debugPrint('🗑️ Eliminadas $filas fila(s) con orden: $orden');
  } catch (e) {
    debugPrint('❌ Error al eliminar orden $orden: $e');
  }
}





}
