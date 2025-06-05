// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use, duplicate_ignore, unused_field

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/mordenes_dao.dart';
// import 'package:sodim/db/db_helper.dart';
import 'package:sodim/db/ordenes_dao.dart';
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/models/vendedor_model.dart';
import 'package:sodim/pages/bitacora_ot_form.dart';
import 'package:sodim/pages/marbetes_forms.dart';
import 'package:sodim/pages/nueva_orden.dart';
import 'package:sodim/pages/pdf_ot.dart';
import 'package:sodim/utils/conexion_helper.dart';
import 'package:sodim/utils/sincronizador_service.dart';
import 'package:sodim/widgets/boton.dart';
import 'package:sodim/widgets/custom_drawer.dart';

class HomePage extends StatefulWidget {
  final Vendedor vendedor;
  const HomePage({super.key, required this.vendedor});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Orden> ordenesRecientes = [];
  Orden? ordenSeleccionada;
  bool isEditing = false;
  bool isCreating = false;
  bool mostrarBotonesEdicion = false;
  bool? selectedIndex;
  bool? soloLectura;
  Set<String> ordenesConPdf = {};
  Set<String> pdfGenerados = {};
  Set<String> marbetesSincronizados =
      SincronizadorService.marbetesSincronizados;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _yaSincronizado = false;

  @override
  void initState() {
    super.initState();
    _cargarOrdenes();
    ApiService().cargarOrdenesDesdePrefs();

    // 🚀 Escucha cambios de red
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) async {
      final conectado = await ConexionHelper.hayInternet(); // ✅ conexión real

      if (conectado && !_yaSincronizado) {
        _yaSincronizado = true;
        debugPrint('🔄 Detected connection, sincronizando...');
        await _sincronizarYActualizar();
      }
    });

    // 🔄 Verifica inmediatamente
    Future.delayed(Duration.zero, () async {
      final conectado = await ConexionHelper.hayInternet();
      if (conectado && !_yaSincronizado) {
        _yaSincronizado = true;
        debugPrint('🔄 Conectado al iniciar, sincronizando...');
        await _sincronizarYActualizar();
      }
    });
  }

  Future<void> _sincronizarYActualizar() async {
    final conectado = await ConexionHelper.hayInternet();

    if (conectado) {
      await SincronizadorService.sincronizarOrdenes();
      await SincronizadorService.sincronizarMarbetes();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sincronización completada')),
        );
      }
    }

    await _cargarOrdenes();
  }


Future<void> _cargarOrdenes() async {
  final api = ApiService();
  final bool conectado = await ConexionHelper.hayInternet();

  List<Orden> ordenesValidas = [];

  // 🔄 1. Cargar las órdenes locales antes de que se sobrescriban
  final ordenesLocales = await OrdenesDAO.getOrdenes();

  final pdfLocales = ordenesLocales
      .where((o) => o.pdfGenerado == true)
      .map((o) => o.orden)
      .toSet();

  final localesLocales = ordenesLocales
      .where((o) => o.local == 'S')
      .map((o) => o.orden)
      .toSet();

  if (conectado) {
    // ✅ Carga desde API
    final List<Map<String, dynamic>> data = await api.getOrdenes(
      widget.vendedor.empresa.toString(),
      widget.vendedor.id.toString(),
    );

    for (var item in data) {
      try {
        final orden = Orden.fromJson(item);

        // ✅ Si ya fue generado el PDF antes, mantenlo
        if (pdfLocales.contains(orden.orden)) {
          orden.pdfGenerado = true;
        }

        // ✅ Si ya estaba marcada como local, también se conserva
        if (localesLocales.contains(orden.orden)) {
          orden.local = 'S';
        }

        ordenesValidas.add(orden);
      } catch (e, stackTrace) {
        debugPrint('❌ Error al convertir item a Orden:\n$item');
        debugPrint('‼️ Error: $e');
        debugPrint('📍 Stack: $stackTrace');
      }
    }

    if (ordenesValidas.isNotEmpty) {
      await OrdenesDAO.insertarListaOrdenes(ordenesValidas);
      debugPrint('✅ ${ordenesValidas.length} órdenes insertadas en SQLite.');
    }
  } else {
    // ❌ No hay conexión: leer desde SQLite
    debugPrint('📴 Cargando órdenes desde SQLite...');
    ordenesValidas = ordenesLocales; // ✅ ya cargadas antes
  }

  if (ordenesValidas.isEmpty) {
    debugPrint('⚠️ No se cargaron órdenes válidas.');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No se encontraron órdenes válidas')),
      );
    }
  }

  setState(() {
    ordenesRecientes = ordenesValidas;
    pdfGenerados = ordenesValidas
        .where((orden) => orden.pdfGenerado == true)
        .map((orden) => orden.orden)
        .toSet();
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true, // 🔄 Importante para centrar el title
        title: Image.asset('assets/images/SODIM1.png', height: 48),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar',
            onPressed: () async {
              final conectado = await ConexionHelper.hayInternet();
              if (conectado) {
                debugPrint('🔄 Sincronizando manualmente desde botón...');
                await _sincronizarYActualizar();
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ No hay conexión a internet'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFA500), Color(0xFFF7B234)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      drawer: CustomDrawer(vendedor: widget.vendedor),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📋 Sistema de Ordenes ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD2691E),
                ),
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 14),
              _infoTile('🏢 Empresa', widget.vendedor.empresa.toString()),
              const SizedBox(height: 10),
              _infoTile(
                '👨‍🔧 Vendedor',
                '${widget.vendedor.id} - ${widget.vendedor.nombre}',
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // _iconAction(
                    //   context,
                    IconActionButton(
                      icon: Icons.add_box,
                      label: 'Nueva Orden',
                      onTap: () async {
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(builder: (context) => NuevaOrden()),
                        // );
                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => NuevaOrden()),
                        );

                        if (resultado != null && resultado is Orden) {
                          setState(() {
                            // ordenesRecientes.add(resultado);
                            ordenesRecientes.insert(
                              0,
                              resultado,
                            ); // ✅ Ahora se muestra al inicio
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Orden agregada a la lista'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 24),

                    // _iconAction(
                    //   context,
                    IconActionButton(
                      icon: Icons.local_offer,
                      label: 'Marbetes',
                      onTap: () {
                        if (ordenSeleccionada == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '⚠️ Selecciona una orden para continuar.',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    MarbetesForms(orden: ordenSeleccionada!),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 24),
                    // _iconAction(
                    //   context,
                    IconActionButton(
                      icon: Icons.remove_red_eye,
                      label: 'Consulta',
                      onTap: () {
                        if (ordenSeleccionada == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '⚠️ Selecciona una orden para consultar.',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => MarbetesForms(
                                  orden: ordenSeleccionada!,
                                  soloLectura: true,
                                ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 24),
                    IconActionButton(
                      icon: Icons.delete,
                      label: 'Eliminar',
                      onTap: () async {
                        if (ordenSeleccionada == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '⚠️ Selecciona una orden para eliminar.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        final confirmacion = await showDialog<bool>(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text('Eliminar orden'),
                                content: Text(
                                  '¿Estás seguro de eliminar la orden ${ordenSeleccionada!.orden}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                        );

                        if (confirmacion ?? false) {
                          final ordenId = ordenSeleccionada!.orden;
                          final conectado = await ConexionHelper.hayInternet();

                          try {
                            // 🔄 1. Si hay internet, elimina del servidor
                            if (conectado) {
                              final api = ApiService();
                              await api.deleteOrdenes(ordenId);
                              debugPrint('☁️ Orden eliminada del servidor');
                            } else {
                              debugPrint(
                                '📴 Sin internet: solo se eliminará localmente',
                              );
                            }

                            // ✅ 2. Siempre eliminar localmente (SQLite)
                            await OrdenesDAO.eliminarPorOrden(ordenId);
                            await MOrdenesDAO.eliminarPorOrden(ordenId);

                            setState(() {
                              ordenesRecientes.remove(ordenSeleccionada);
                              ordenSeleccionada = null;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  conectado
                                      ? '✅ Orden eliminada (local + servidor)'
                                      : '✅ Orden eliminada localmente (sin internet)',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Error al eliminar: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    const SizedBox(width: 24),
                    // _iconAction(
                    //   context,
                    IconActionButton(
                      icon: Icons.edit_note,
                      label: 'Modifica Orden',
                      onTap: () async {
                        if (ordenSeleccionada == null ||
                            ordenSeleccionada!.cliente.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '⚠️ Selecciona una orden para modificar.',
                              ),
                            ),
                          );
                        } else {
                          final modificada = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => NuevaOrden(
                                    ordenExistente: ordenSeleccionada,
                                    cliente:
                                        ordenSeleccionada!
                                            .cliente, // ✅ ahora sí funciona
                                  ),
                            ),
                          );

                          if (modificada != null && modificada is Orden) {
                            setState(() {
                              final index = ordenesRecientes.indexWhere(
                                (o) => o.orden == modificada.orden,
                              );
                              if (index != -1) {
                                ordenesRecientes[index] = modificada;
                              }
                            });
                          }
                        }
                      },
                    ),

                    const SizedBox(width: 12),
                    // _iconAction(
                    //   context,
                    IconActionButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF',
                      onTap: () async {
                        if (ordenSeleccionada == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '⚠️ Selecciona una orden para descargar el PDF.',
                              ),
                            ),
                          );
                          return;
                        }

                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PdfOtForms(
                                  orden: ordenSeleccionada!,
                                  soloLectura: true,
                                ),
                          ),
                        );

                        if (resultado != null && mounted) {
                          await OrdenesDAO.marcarPdfGenerado(
                            resultado,
                          ); // ✅ Persistir en SQLite

                          setState(() {
                            pdfGenerados.add(
                              resultado,
                            ); // ✅ Mostrar en verde visualmente
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // ----------------------------------------------------------------
              const Text(
                '📑 Órdenes recientes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  // color: Colors.deepPurple,
                  color: Color(0xFFD2691E),
                ),
              ),
              const SizedBox(height: 10),

              // ----------------------------------------------------------------
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical, // ✅ vertical
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, // ✅ horizontal
                    child: DataTable(
                      // ignore: deprecated_member_use
                      headingRowColor: MaterialStateProperty.resolveWith(
                        (states) => Color(0xFFF7B234),
                      ),
                      columnSpacing: 12, // 👈 reduce espacio entre columnas
                      dataRowMinHeight: 30, // 👈 altura mínima de fila
                      dataRowMaxHeight: 40, // 👈 altura máxima de fila

                      columns: const [
                        DataColumn(label: Text('Orden')),
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Fecha Captura')),
                        DataColumn(label: Text('Cliente')),
                      ],

                      rows:
                          ordenesRecientes.map((orden) {
                            final bool estaGenerado = pdfGenerados.contains(
                              orden.orden,
                            );
                            final bool isSelected = ordenSeleccionada == orden;

                            return DataRow(
                              color: MaterialStateProperty.resolveWith<Color?>((
                                Set<MaterialState> states,
                              ) {
                                if (isSelected)
                                  return Colors
                                      .blue
                                      .shade100; // ✅ Azul si está seleccionada
                                if (estaGenerado) return Colors.green.shade100;
                                return null;
                              }),
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      Text(orden.orden),
                                      const SizedBox(width: 6),
                                      if (marbetesSincronizados.contains(
                                        orden.orden,
                                      ))
                                        const Icon(
                                          Icons.cloud_done,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  onTap: () async {
                                    if (marbetesSincronizados.contains(
                                      orden.orden,
                                    )) {
                                      // ✅ Mostrar modal que ya fue sincronizado
                                      await showDialog(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: const Text(
                                                '✔ Marbete sincronizado',
                                              ),
                                              content: Text(
                                                'La orden ${orden.orden} ya fue sincronizada.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  child: const Text('Cerrar'),
                                                ),
                                              ],
                                            ),
                                      );
                                      return;
                                    }

                                    if (estaGenerado) {
                                      final confirmar = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text(
                                                'Modificar Marbete',
                                              ),
                                              content: const Text(
                                                '¿Deseas modificar esta orden ya generada?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancelar'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Modificar',
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (confirmar == true) {
                                        setState(() {
                                          ordenSeleccionada = orden;
                                          pdfGenerados.remove(
                                            orden.orden,
                                          ); // ❌ quitar verde
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '📝 Marbete listo para modificación: ${orden.orden}',
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => BitacoraOTFormPage(
                                                  orden: orden.orden,
                                                  marbete: '',
                                                  cliente: orden.cliente,
                                                ),
                                          ),
                                        );
                                      }
                                    } else {
                                      setState(() {
                                        ordenSeleccionada = orden;
                                      });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '📌 Orden seleccionada: ${orden.orden}',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),

                                DataCell(
                                  Text(orden.razonsocial),
                                  onTap: () {
                                    setState(() {
                                      ordenSeleccionada = orden;
                                    });
                                  },
                                ),
                                DataCell(
                                  Text(
                                    orden.fechaCaptura != null
                                        ? DateFormat(
                                          'dd/MM/yyyy HH:mm',
                                        ).format(orden.fechaCaptura!)
                                        : 'Fecha inválida',
                                  ),
                                  onTap: () {
                                    setState(() {
                                      ordenSeleccionada = orden;
                                    });
                                  },
                                ),
                                DataCell(
                                  Text(orden.cliente),
                                  onTap: () {
                                    setState(() {
                                      ordenSeleccionada = orden;
                                    });
                                  },
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
              // ----------------------------------------------------------------
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}
