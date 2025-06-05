// ignore_for_file: unused_element, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/catalogo_dao.dart';
import 'package:sodim/db/ordenes_dao.dart';
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/pages/login_page.dart';
import 'package:sodim/pages/marbetes_forms.dart';
import 'package:sodim/utils/sincronizador_service.dart';

class NuevaOrden extends StatefulWidget {
  // const NuevaOrden({super.key});
  final Orden? ordenExistente;
  final String? cliente;

  const NuevaOrden({super.key, this.ordenExistente, this.cliente});

  @override
  State<NuevaOrden> createState() => _NuevaOrdenState();
}

class _NuevaOrdenState extends State<NuevaOrden> {
  final TextEditingController ordenController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController empresaController = TextEditingController();
  final TextEditingController vendedorController = TextEditingController();
  final TextEditingController fCapturaController = TextEditingController();
  final TextEditingController clienteComboController = TextEditingController();

  List<String> clientes = [];
  List<String> prefijos = [];
  List<Orden> ordenesRecientes = [];

  String? clienteSeleccionado;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarDatosIniciales();

    if (widget.ordenExistente != null) {
      final orden = widget.ordenExistente!;
      ordenController.text = orden.orden;
      clienteSeleccionado = orden.cliente;
      nombreController.text = orden.razonsocial;
      empresaController.text = orden.empresa.toString();
      vendedorController.text = orden.vend.toString();
      fCapturaController.text = orden.fcaptura;
      clienteComboController.text =
          '$clienteSeleccionado - ${orden.razonsocial}';
    } else {
      fCapturaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (widget.cliente != null) {
        clienteSeleccionado = widget.cliente;
        nombreController.text = widget.cliente!;
      }

      Future.delayed(Duration.zero, () async {
        try {
          await SincronizadorService.sincronizarOrdenes();
          await SincronizadorService.sincronizarMarbetes();
        } catch (e) {
          debugPrint('⚠️ Error al intentar sincronizar: $e');
        }

        // 👇 Aquí llamas a tu validación
        // await validarPrefijoVsEmpresa();
      });
    }
  }

  Future<void> cargarDatosIniciales() async {
    await Future.wait([
      // cargarClientesDesdeSQLite(),
      cargarCatalogosDesdeSQLite(),
      cargarVendedorDesdePreferencias(),
    ]);
    setState(() => loading = false);
  }

  Future<void> cargarCatalogosDesdeSQLite() async {
    final datos = await Future.wait([
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'clientes', campo: 'nombre'),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'prefijos', campo: 'prefijo'),
    ]);

    setState(() {
      clientes = datos[0];
      prefijos = datos[1];

      // if (!clientes.contains(clienteSeleccionado)) {
      //   clienteSeleccionado = null;
      //   nombreController.clear();
      // }
      // ✅ Solo borramos si ya habíamos cargado orden y no existe en la lista
      if (clienteSeleccionado != null &&
          !clientes.contains(clienteSeleccionado)) {
        clienteSeleccionado = null;
        nombreController.clear();
      }

      // 👉 Establece el primer prefijo si ordenController está vacío
      if (prefijos.isNotEmpty && ordenController.text.isEmpty) {
        ordenController.text = prefijos[0];
      }

      // debugPrint('🛠️ Cliente    : $clientes');
      debugPrint('🛠️ Prefijos   : $prefijos');
    });
  }

  Future<void> cargarVendedorDesdePreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final vendedorStr = prefs.getString('vendedor');
    if (vendedorStr != null) {
      final vendedorMap = json.decode(vendedorStr);
      empresaController.text = vendedorMap['EMPRESA'].toString();
      vendedorController.text = vendedorMap['VENDEDOR'].toString();
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      fCapturaController.text = DateFormat('yyyy-MM-dd').format(fecha);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        title: Text(
          widget.ordenExistente != null
              ? '✏️ Modificar Orden'
              : '📦 Nueva Orden',
        ),
        // backgroundColor: Colors.indigo.shade700,
        // foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7B234), Color(0xFFE19A14)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment, color: Color(0xFFF7B234)),
                    const SizedBox(width: 8),
                    Text(
                      'Registro de Orden',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Color(0xFFD2691E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _buildCampoLabeled(context, 'Orden', ordenController),
                const SizedBox(height: 12),
                const Text('Cliente'),
                const SizedBox(height: 6),

                TypeAheadFormField<String>(
                  textFieldConfiguration: TextFieldConfiguration(
                    controller:
                        clienteComboController, // ✅ SOLO este debe quedar
                    decoration: const InputDecoration(
                      hintText: 'Seleccionar cliente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  suggestionsCallback:
                      (pattern) =>
                          clientes
                              .where(
                                (c) => c.toLowerCase().contains(
                                  pattern.toLowerCase(),
                                ),
                              )
                              .toList(),
                  itemBuilder:
                      (context, String suggestion) =>
                          ListTile(title: Text(suggestion)),
                  onSuggestionSelected: (String suggestion) {
                    final partes = suggestion.split(' - ');
                    setState(() {
                      clienteSeleccionado = partes.first.trim(); // Solo "CA001"
                      nombreController.text =
                          partes.length > 1 ? partes[1].trim() : '';
                      clienteComboController.text =
                          suggestion; // ✅ también actualiza el campo visible
                    });
                  },
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCampoLabeled(
                        context,
                        'Empresa',
                        empresaController,
                        enabled: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCampoLabeled(
                        context,
                        'Vendedor',
                        vendedorController,
                        enabled: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCampoLabeled(
                  context,
                  'Fecha de Captura',
                  fCapturaController,
                  enabled: false,
                  readOnly: true,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (ordenController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ El campo "Orden" es obligatorio'),
                          ),
                        );
                        return;
                      }

                      if (clienteSeleccionado == null ||
                          clienteSeleccionado!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Debes seleccionar un cliente'),
                          ),
                        );
                        return;
                      }

                      final Map<String, String?> jsonFinal = {
                        'ORDEN': ordenController.text.trim(),
                        'FECHA': DateFormat(
                          'yyyy-MM-dd',
                        ).format(DateTime.now()), // ✅ Corrección
                        'CLIENTE': clienteSeleccionado,
                        'RAZONSOCIAL': nombreController.text.trim(),
                        'FCIERRE': null,
                        'FCAPTURA': DateFormat(
                          'yyyy-MM-dd HH:mm:ss',
                        ).format(DateTime.now()),
                        'EMPRESA': empresaController.text.trim(),
                        'VEND': vendedorController.text.trim(),
                        'RUTA': null,
                        'ENVIADA': null,
                        'DIAS_ENTREGA': null,
                        'CLIE_TIPO': null,
                        'UCAPTURA': null,
                      };

                      debugPrint('📤 Enviando JSON: ${jsonEncode(jsonFinal)}');

                      try {
                        final api =
                            ApiService(); // Asegúrate de tener esta clase importada
                        final resultado =
                            widget.ordenExistente == null
                                ? await api.insertOrdenes(jsonFinal)
                                : await api.updateOrdenes(jsonFinal);
                        if (widget.ordenExistente != null) {
                          final clienteAnterior =
                              widget.ordenExistente!.cliente;
                          final clienteActual = clienteSeleccionado;

                          // Si el MARBETE fue modificado registrarlo , sino que se quede como null
                          if (clienteAnterior != clienteActual) {
                            final bitacoraData = {
                              'REG': 1, // Genera uno real si aplica
                              'ORDEN': ordenController.text.trim(),
                              'MARBETE': null, // Rellena si aplica
                              'OBSERVACION':
                                  'Cliente modificado: De $clienteAnterior a $clienteActual',
                              'FECHASYS': DateFormat(
                                'yyyy-MM-dd HH:mm:ss',
                              ).format(DateTime.now()),
                              'USUARIO': vendedorController.text.trim(),
                            };

                            try {
                              // Intenta primero insertar la bitácora
                              final resultado = await api.insertBitacorasOt(
                                bitacoraData,
                              );
                              debugPrint('✅ Bitácora registrada: $resultado');
                            } catch (e) {
                              debugPrint(
                                '⚠️ Insert falló, intentando actualización...',
                              );

                              try {
                                // Si ya existe, actualiza la bitácora
                                final resultadoUpdate = await api
                                    .updateBitacorasOt(bitacoraData);
                                debugPrint(
                                  '🔄 Bitácora actualizada: $resultadoUpdate',
                                );
                              } catch (e2) {
                                debugPrint(
                                  '❌ No se pudo registrar ni actualizar bitácora: $e2',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '❌ Error al registrar bitácora',
                                    ),
                                  ),
                                );
                              }
                            }
                          } else {
                            debugPrint(
                              'ℹ️ Cliente sin cambios. No se registró bitácora.',
                            );
                          }
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Orden ${widget.ordenExistente == null ? "creada" : "actualizada"}: $resultado',
                            ),
                          ),
                        );

                        final nueva = Orden(
                          orden: jsonFinal['ORDEN'] ?? '',
                          fecha: jsonFinal['FECHA'] ?? '',
                          cliente: jsonFinal['CLIENTE'] ?? '',
                          razonsocial: jsonFinal['RAZONSOCIAL'] ?? '',
                          fcierre: jsonFinal['FCIERRE'] ?? '',
                          fcaptura: jsonFinal['FCAPTURA'] ?? '',
                          empresa:
                              int.tryParse(jsonFinal['EMPRESA'] ?? '') ?? 0,
                          vend: int.tryParse(jsonFinal['VEND'] ?? '') ?? 0,
                          ruta: jsonFinal['RUTA'] ?? '',
                          enviada: jsonFinal['ENVIADA'] == 'S' ? 1 : 0,
                          diasentrega:
                              int.tryParse(jsonFinal['DIAS_ENTREGA'] ?? '') ??
                              0,
                          clietipo: jsonFinal['CLIE_TIPO'] ?? '',
                          ucaptura: jsonFinal['UCAPTURA'] ?? '',
                          local: 'N', // 👈 importante
                        );

                        // Navigator.pop(context, nueva);
                         Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MarbetesForms(orden: nueva),
                            ),
                          );

                        if (widget.ordenExistente == null) {
                          setState(() {
                            ordenesRecientes.add(nueva);
                          });
                        }
                      } catch (e) {
                        debugPrint('❌ Error: $e');

                        if (e.toString().contains('Failed host lookup')) {
                          debugPrint('📴  Guardando orden localmente...');

                          final nueva = Orden(
                            orden: jsonFinal['ORDEN'] ?? '',
                            fecha: jsonFinal['FECHA'] ?? '',
                            cliente: jsonFinal['CLIENTE'] ?? '',
                            razonsocial: jsonFinal['RAZONSOCIAL'] ?? '',
                            fcierre: jsonFinal['FCIERRE'] ?? '',
                            fcaptura: jsonFinal['FCAPTURA'] ?? '',
                            empresa:
                                int.tryParse(jsonFinal['EMPRESA'] ?? '') ?? 0,
                            vend: int.tryParse(jsonFinal['VEND'] ?? '') ?? 0,
                            ruta: jsonFinal['RUTA'] ?? '',
                            enviada: 0,
                            diasentrega:
                                int.tryParse(jsonFinal['DIAS_ENTREGA'] ?? '') ??
                                0,
                            clietipo: jsonFinal['CLIE_TIPO'] ?? '',
                            ucaptura: jsonFinal['UCAPTURA'] ?? '',
                            local:
                                'S', // 👈 Agrega este campo si lo tienes en el modelo
                          );

                          await OrdenesDAO.insertarOrden(nueva);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📴 Orden guardada localmente'),
                            ),
                          );

                          Navigator.pop(context, nueva);
                          // Navigator.pushReplacement(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => MarbetesForms(orden: nueva),
                          //   ),
                          // );

                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error al guardar: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(
                        0xFFD2691E,
                      ), // botón naranja oscuro
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampoLabeled(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      enabled: enabled,
      inputFormatters: [
        UpperCaseTextFormatter(), // sigue forzando mayúsculas
        LengthLimitingTextInputFormatter(8), // 👈 Limita a 14 caracteres
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        if (prefijos.isEmpty) return;

        final prefix = prefijos[0];

        // Elimina todo lo que no sea dígito después del prefijo
        String digitsOnly = value
            .replaceFirst(prefix, '')
            .replaceAll(RegExp(r'\D'), '');

        // Limita a máximo 15 dígitos
        if (digitsOnly.length > 15) {
          digitsOnly = digitsOnly.substring(0, 15);
        }

        controller.text = '$prefix$digitsOnly';
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      },
      onEditingComplete: () {
        final prefix = prefijos.isNotEmpty ? prefijos[0] : '';
        final value = controller.text;
        final numerico = value.replaceFirst(prefix, '');

        if (numerico.length < 6 || numerico.length > 15) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ El número debe tener entre 6 y 15 dígitos'),
            ),
          );
        }
      },
      keyboardType: TextInputType.number,
    );
  }
}
