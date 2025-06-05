import 'package:flutter/material.dart';
import 'package:sodim/models/vendedor_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> initDb() async {
    if (_db != null) return _db!;
    // final path = join(await getDatabasesPath(), 'sodim.db');
    final path = join(await getDatabasesPath(), 'sodim.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla VENDEDOR
        await db.execute('''
          CREATE TABLE vendedores(
         id TEXT PRIMARY KEY,         -- CAMBIO IMPORTANTE
         clave_cel TEXT,
         nombre TEXT,
         mail TEXT,
         empresa INTEGER
        )
      ''');

       await db.execute('''
  CREATE TABLE ordenes(
    orden TEXT PRIMARY KEY,
    fecha TEXT,
    cliente TEXT,
    razonsocial TEXT,
    fcierre TEXT,
    fcaptura TEXT,
    empresa INTEGER,
    vend INTEGER,
    ruta TEXT,
    enviada INTEGER,
    diasentrega INTEGER,
    clietipo TEXT,
    ucaptura TEXT,
    local TEXT DEFAULT 'N',
    pdf_generado INTEGER DEFAULT 0
  )
''');

        // Tabla MORDENES COMPLETA
        await db.execute('''
        CREATE TABLE mordenes(
  orden TEXT,
  marbete TEXT,
  economico TEXT,
  matricula TEXT,
  medida TEXT,
  marca TEXT,
  trabajo TEXT,
  terminado TEXT,
  banda TEXT,
  pr TEXT,
  nup TEXT,
  oriren TEXT,
  falla TEXT,
  ajuste TEXT,
  docajuste TEXT,
  faj TEXT,
  oaj TEXT,
  reprocesos TEXT,
  status TEXT,
  reparaciones TEXT,
  frev TEXT,
  orev TEXT,
  farm TEXT,
  oarm TEXT,
  fcal TEXT,
  ocal TEXT,
  ubicacion TEXT,
  documento TEXT,
  env_suc TEXT,
  fsalida TEXT,
  docsalida TEXT,
  fentrada TEXT,
  docentrada TEXT,
  control TEXT,
  oras TEXT,
  ocar TEXT,
  opre TEXT,
  orep TEXT,
  oenc TEXT,
  ores TEXT,
  ovul TEXT,
  fdocumento TEXT,
  fras TEXT,
  frep TEXT,
  fvul TEXT,
  fcar TEXT,
  sg TEXT,
  bus TEXT,
  trabajoalterno TEXT,
  observacion1 TEXT,
  observacion2 TEXT,
  refac TEXT,
  mesdoc TEXT,
  aniodoc TEXT,
  ter_anterior TEXT,
  nrenovado TEXT,
  ajusteimporte TEXT,
  marbete_ant TEXT,
  autoclave TEXT,
  rev_xerografia TEXT,
  obs TEXT,
  codigo_tra TEXT,
  compuesto TEXT,
  trabajo_otr TEXT,
  anio_calidad TEXT,
  mes_calidad TEXT,
  fentcascosren TEXT,
  dentcascosren TEXT,
  uentcascosren TEXT,
  cte_distribuidor TEXT,
  datoextra1 TEXT,
  falla_armado TEXT,
  fincidencia_armado TEXT,
  perdido TEXT,
  fperdido TEXT,
  clie_tipo TEXT,
  causa_atrazo TEXT,
  fabricante TEXT,
  articulo_pronostico TEXT,
  sobre TEXT,
  nc_docto TEXT,
  nc_fecha TEXT,
  nc_usuario TEXT,
  tipo_cardeado TEXT,
  marbete_ic TEXT,
  terminado_cte_ic TEXT,
  ic TEXT,
  articulo_pt TEXT,
  tarima TEXT,
  reg_tarima TEXT,
  opar TEXT,
  fpar TEXT,
  rep_parches TEXT,
  ogur0tr TEXT,
  fgur0tr TEXT,
  olavotr TEXT,
  flavotr TEXT,
  oencotr TEXT,
  fencotr TEXT,
  oresotr TEXT,
  fresotr TEXT,
  occeotr TEXT,
  fcceotr TEXT,
  otr_kilos_arm TEXT,
  otr_kilos_car TEXT,
  articulo_revisado TEXT,
  opulotr TEXT,
  fpulotr TEXT,
  lote_tira TEXT,
  sumacalidad TEXT,
  dias_entrega TEXT,

  cliente TEXT,
  razonsocial TEXT,
  empresa TEXT,
  vend TEXT,
  local TEXT,
  fechasys TEXT
)
   ''');

        // Tabla CLIENTES
        await db.execute('''
  CREATE TABLE clientes(
    clave TEXT PRIMARY KEY,
    nombre TEXT
  )
''');

        // Tabla PREFIJOS
        await db.execute('''
  CREATE TABLE prefijos(
    prefijo TEXT PRIMARY KEY
  )
''');

        // Tabla MARCAS
        await db.execute('''
  CREATE TABLE marcas(
    marca TEXT PRIMARY KEY
  )
''');

        // Tabla MEDIDAS
        await db.execute('''
  CREATE TABLE medidas(
    medida TEXT PRIMARY KEY
  )
''');

        // Tabla TERMINADOS
        await db.execute('''
  CREATE TABLE terminados(
    terminado TEXT PRIMARY KEY
  )
''');

        // Tabla TRABAJOS
        await db.execute('''
  CREATE TABLE trabajos(
    trabajo TEXT PRIMARY KEY
  )
''');
      },
    );

    return _db!;
  }

  static Future<void> insertVendedor(Vendedor vendedor) async {
    final db = await initDb();
    await db.insert(
      'vendedores',
      vendedor.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,

      // conflictAlgorithm: ConflictAlgorithm.ignore
    );
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> resetDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sodim.db');

    // Borra la base de datos
    await deleteDatabase(path);
    debugPrint('🗑 Base de datos eliminada correctamente.');
  }

  static Future<void> limpiarBaseDatos() async {
  final db = await initDb();
  await db.delete('ordenes');
  await db.delete('mordenes');
  await db.delete('clientes');
  await db.delete('prefijos');
  // Agrega más tablas si es necesario limpiar otras
}

}
