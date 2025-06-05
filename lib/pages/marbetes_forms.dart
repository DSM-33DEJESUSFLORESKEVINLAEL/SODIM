// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/catalogo_dao.dart';
import 'package:sodim/db/mordenes_dao.dart';
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/pages/login_page.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:sodim/utils/sincronizador_service.dart';

class MarbetesForms extends StatefulWidget {
  final Orden orden;
  final bool soloLectura;

  const MarbetesForms({
    super.key,
    required this.orden,
    this.soloLectura = false,
  });

  @override
  State<MarbetesForms> createState() => _MarbetesFormsState();
}

class _MarbetesFormsState extends State<MarbetesForms> {
  final TextEditingController ordenController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController empresaController = TextEditingController();
  final TextEditingController vendedorController = TextEditingController();
  final TextEditingController fCapturaController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool camposObligatoriosIncompletos = false;
  int? selectedIndex;
  bool isEditing = false;
  bool isCreating = false;

  Map<String, bool> camposVacios = {
    'marbete': false,
    'matricula': false,
    'medida': false,
    'marca': false,
    'trabajo': false,
  };

  final TextEditingController marbeteController = TextEditingController();
  final TextEditingController matriculaController = TextEditingController();
  final TextEditingController medidaController = TextEditingController();
  final TextEditingController marcaController = TextEditingController();
  final TextEditingController trabajoController = TextEditingController();
  final TextEditingController trabajoAlternoController =
      TextEditingController();
  final TextEditingController codigoTraController = TextEditingController();
  final TextEditingController compuestoController = TextEditingController();
  final TextEditingController trabajoOtrController = TextEditingController();
  final TextEditingController observacionController = TextEditingController();
  final TextEditingController sgController = TextEditingController();
  final TextEditingController busController = TextEditingController();
  final TextEditingController economicoController = TextEditingController();

  final List<String> compuestos = [
    'OTRS',
    'RTC',
    'ARC',
    'TYT',
    'TR',
    'SEM',
    'PQ',
  ];
  final List<String> trabajosOtr = ['FT', 'MO', 'OT'];
  final List<String> sg = ['S', 'N'];

  List<String> marcas = [];
  List<String> medidas = [];
  List<String> terminados = [];
  List<String> trabajos = [];
  List<String> prefijos = [];

  List<Map<String, dynamic>> marbetes = [];

  String? clienteSeleccionado;
  bool loading = true;
  bool mostrarBotonesEdicion = false; // Para Guardar/Cancelar

  @override
  void initState() {
    super.initState();
    cargarDatosIniciales();
    fCapturaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // ✅ Valor por defecto de SG
    sgController.text = 'S';
    cargarMarbetes();

    // 🔁 Verifica conexión e intenta sincronizar
    Future.delayed(const Duration(seconds: 2), () async {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await SincronizadorService.sincronizarOrdenes();
        await SincronizadorService.sincronizarMarbetes();

        // 👇 Recargar lista después de sincronizar
        await cargarMarbetes();
        debugPrint('🔁 Lista de marbetes recargada después de sincronizar');
      }
    });
  }

  Future<void> cargarDatosIniciales() async {
    await Future.wait([
      // cargarClientesDesdeSQLite(),
      cargarVendedorDesdePreferencias(),
      // cargarClientes1DesdeSQLite(),
      cargarCatalogosDesdeSQLite(),
    ]);
    setState(() => loading = false);
  }

  Future<void> cargarMarbetes() async {
    final api = ApiService();

    // 1. Obtener marbetes del servidor
    final marbetesServidorCrudos = await api.getMOrdenes(widget.orden.orden);

    // 🔁 Normaliza los marbetes del servidor
    final marbetesServidor =
        marbetesServidorCrudos.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['MARBETE'] = map['MARBETE']?.toString().toUpperCase().trim();
          return map;
        }).toList();

    // 2. Obtener marbetes locales
    final marbetesLocalesCrudos = await MOrdenesDAO.obtenerTodosPorOrden(
      widget.orden.orden,
    );

    final marbetesLocales =
        marbetesLocalesCrudos.map((map) {
          final nuevo = map.map((k, v) => MapEntry(k.toUpperCase(), v));
          nuevo['MARBETE'] = nuevo['MARBETE']?.toString().toUpperCase().trim();
          return nuevo;
        }).toList();

    // 3. Combinar sin duplicar por MARBETE
    final combinados = <Map<String, dynamic>>[];
    final marbetesUnicos = <String>{};

    for (final s in marbetesServidor) {
      final id = s['MARBETE'];
      if (id != null && marbetesUnicos.add(id)) {
        combinados.add(s);
      }
    }

    for (final l in marbetesLocales) {
      final id = l['MARBETE'];
      if (id != null && marbetesUnicos.add(id)) {
        combinados.add(l);
      }
    }

    // 4. Debug opcional
    debugPrint('🌐 Marbetes servidor      : ${marbetesServidor.length}');
    debugPrint('📱 Marbetes locales       : ${marbetesLocales.length}');
    debugPrint('🧩 Total combinados       : ${combinados.length}');

    // 5. Actualizar UI
    if (!mounted) return;
    setState(() {
      marbetes = combinados;
    });
  }

  Future<void> cargarCatalogosDesdeSQLite() async {
    final datos = await Future.wait([
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'marcas', campo: 'marca'),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'medidas', campo: 'medida'),
      CatalogoDAO.obtenerCatalogoSimple(
        tabla: 'terminados',
        campo: 'terminado',
      ),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'prefijos', campo: 'prefijo'),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'trabajos', campo: 'trabajo'),
    ]);

    setState(() {
      marcas = datos[0];
      medidas = datos[1];
      terminados = datos[2];
      trabajos = datos[3];
      prefijos = datos[4];

      // debugPrint('🏷️ Marcas     : $marcas');
      // debugPrint('📏 Medidas     : $medidas');
      // debugPrint('✅ Terminados  : $terminados');
      // debugPrint('🛠️ Trabajos    : $trabajos');
      debugPrint('🛠️ Prefijos   : $prefijos');
    });
  }

  // -------------------------------------------------------------------------
  Future<void> cargarVendedorDesdePreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final vendedorStr = prefs.getString('vendedor');
    if (vendedorStr != null) {
      final vendedorMap = json.decode(vendedorStr);
      empresaController.text = vendedorMap['EMPRESA'].toString();
      vendedorController.text = vendedorMap['VENDEDOR'].toString();
    }
  }

  // -------------------------------------------------------------------------
  // ignore: unused_element
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

  // -----------------------------------------------------------------------------------

  // -----------------------------------------------------------------------------------------
  void limpiarCampos() {
    marbeteController.clear();
    matriculaController.clear();
    medidaController.clear();
    marcaController.clear();
    trabajoController.clear();
    trabajoAlternoController.clear();
    codigoTraController.clear();
    compuestoController.clear();
    trabajoOtrController.clear();
    observacionController.clear();

    sgController.text = 'S';
    busController.clear();
    economicoController.clear();
  }

  void llenarCampos(Map<String, dynamic> data) {
    marbeteController.text = data['MARBETE'] ?? '';
    matriculaController.text = data['MATRICULA'] ?? '';
    medidaController.text = data['MEDIDA'] ?? '';
    marcaController.text = data['MARCA'] ?? '';
    trabajoController.text = data['TRABAJO'] ?? '';
    trabajoAlternoController.text = data['TRABAJOALTERNO'] ?? '';
    codigoTraController.text = data['CODIGO_TRA'] ?? '';
    compuestoController.text = data['COMPUESTO'] ?? '';
    trabajoOtrController.text = data['TRABAJO_OTR'] ?? '';
    sgController.text = data['SG'] ?? '';
    observacionController.text = data['OBSERVACION'] ?? '';

    // 👇 Agrega estas líneas
    busController.text = data['BUS'] ?? '';
    economicoController.text = data['ECONOMICO'] ?? '';
  }

  String generarMarbete() {
    final ordenBase = widget.orden.orden;

    // Detectar prefijo (letras al inicio)
    final prefijoMatch = RegExp(r'^[A-Z]+').firstMatch(ordenBase);
    final prefijo = prefijoMatch?.group(0) ?? 'T'; // Por defecto 'T'

    // Obtener solo marbetes con ese mismo prefijo y parte numérica válida
    final numeros =
        marbetes
            .map((e) => e['MARBETE']?.toString() ?? '')
            .where(
              (m) =>
                  m.startsWith(prefijo) &&
                  int.tryParse(m.substring(prefijo.length)) != null,
            )
            .map((m) => int.parse(m.substring(prefijo.length)))
            .toList();

    if (numeros.isEmpty) {
      // Si no hay marbetes aún con ese prefijo, usar el mismo número de orden si es válido
      if (ordenBase.startsWith(prefijo) &&
          int.tryParse(ordenBase.substring(prefijo.length)) != null) {
        return ordenBase;
      } else {
        // ignore: unnecessary_string_interpolations
        return '$prefijo'; // Fallback
      }
    }

    // Si ya hay marbetes, usar el mayor + 1
    final max = numeros.reduce((a, b) => a > b ? a : b);
    return '$prefijo${(max + 1).toString()}';
  }

  Widget _buildDropdownConController(
    String label,
    TextEditingController controller, {
    required String clave,
    required List<String> opciones,
    String? Function(String?)? validator,
  }) {
    return TypeAheadFormField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
      suggestionsCallback: (pattern) {
        return opciones
            .where(
              (opcion) => opcion.toLowerCase().contains(pattern.toLowerCase()),
            )
            .toList();
      },
      itemBuilder: (context, String suggestion) {
        return ListTile(title: Text(suggestion));
      },
      onSuggestionSelected: (String suggestion) {
        controller.text = suggestion;
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '⚠ Requerido';
        }
        if (!opciones.contains(value.toUpperCase())) {
          return '❌ Seleccione una opción válida';
        }
        return validator != null ? validator(value) : null;
      },
      noItemsFoundBuilder:
          (context) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('🔍 Sin coincidencias'),
          ),
    );
  }

  Widget _buildDropdownConController2(
    String label,
    TextEditingController controller, {
    required String clave,
    required List<String> opciones,
    String? Function(String?)? validator,
  }) {
    return TypeAheadFormField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 255, 137, 3)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 255, 137, 3)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 255, 137, 3)),
          ),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
      suggestionsCallback: (pattern) {
        return opciones
            .where(
              (opcion) => opcion.toLowerCase().contains(pattern.toLowerCase()),
            )
            .toList();
      },
      itemBuilder: (context, String suggestion) {
        return ListTile(title: Text(suggestion));
      },
      onSuggestionSelected: (String suggestion) {
        controller.text = suggestion;
      },
      validator: (value) {
        if (value != null &&
            value.isNotEmpty &&
            !opciones.contains(value.toUpperCase())) {
          return '❌ Seleccione una opción válida';
        }
        return validator != null ? validator(value) : null;
      },
      noItemsFoundBuilder:
          (context) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('🔍 Sin coincidencias'),
          ),
    );
  }

  Widget _buildDropdownConController3(
    String label,
    TextEditingController controller, {
    required String clave,
    required List<String> opciones,
    String? Function(String?)? validator,
  }) {
    return TypeAheadFormField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
      suggestionsCallback: (pattern) {
        return opciones
            .where(
              (opcion) => opcion.toLowerCase().contains(pattern.toLowerCase()),
            )
            .toList();
      },
      itemBuilder: (context, String suggestion) {
        return ListTile(title: Text(suggestion));
      },
      onSuggestionSelected: (String suggestion) {
        controller.text = suggestion;
      },
      validator: (value) {
        if (value != null &&
            value.isNotEmpty &&
            !opciones.contains(value.toUpperCase())) {
          return '❌ Seleccione una opción válida';
        }
        return validator != null ? validator(value) : null;
      },
      noItemsFoundBuilder:
          (context) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('🔍 Sin coincidencias'),
          ),
    );
  }

  Widget _buildCampoConController(
    String label,
    TextEditingController controller, {
    required String clave,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 350,
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        // inputFormatters: [UpperCaseTextFormatter()],
        inputFormatters: [
          UpperCaseTextFormatter(),
          LengthLimitingTextInputFormatter(10), // 👈 Limita a 14 caracteres
        ],
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
  // quiero que me lo limite a solo 14 valores

  Widget _buildCampoConController3(
    String label,
    TextEditingController controller, {
    required String clave,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 350,
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildCampoConController2(
    String label,
    TextEditingController controller, {
    required String clave,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 350,
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final screenWidth = MediaQuery.of(context).size.width;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Image.asset('assets/images/SODIM1.png', height: 48),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
                      '📌Orden: ${widget.orden.orden}',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Color.fromARGB(255, 7, 7, 7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      _iconAction(
                        icon: Icons.add_box,
                        label: 'Nuevo',
                        onTap:
                            (!widget.soloLectura && !isCreating && !isEditing)
                                ? () {
                                  limpiarCampos();
                                  marbeteController.text = generarMarbete();
                                  isCreating = true;
                                  isEditing = true;
                                  mostrarBotonesEdicion = true;
                                  selectedIndex = null;
                                  setState(() {});
                                }
                                : null,
                      ),

                      const SizedBox(width: 24),
                      _iconAction(
                        icon: Icons.edit,
                        label: 'Modificar',
                        onTap:
                            (!widget.soloLectura &&
                                    !mostrarBotonesEdicion &&
                                    selectedIndex != null &&
                                    !isCreating)
                                ? () {
                                  final seleccionado = marbetes[selectedIndex!];
                                  llenarCampos(seleccionado);
                                  isCreating = false;
                                  isEditing = true;
                                  mostrarBotonesEdicion = true;
                                  setState(() {});
                                }
                                : null,
                      ),
                      const SizedBox(width: 24),

                      _iconAction(
                        icon: Icons.save,
                        label: 'Guardar',

                        onTap:
                            (mostrarBotonesEdicion)
                                ? () async {
                                  // ✅ VALIDACIÓN GLOBAL DEL FORMULARIO
                                  if (!formKey.currentState!.validate()) {
                                    // Si hay errores, se mostrarán automáticamente en cada campo
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '⚠️ Faltan Campos por llenar',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  // Paso 2: Procesar normalmente si todos los campos están llenos
                                  final ordenActual = widget.orden.orden;
                                  final marbeteActual =
                                      marbeteController.text.trim();

                                  final datosActualizar = {
                                    'ORDEN': ordenActual,
                                    'MARBETE': marbeteActual,
                                    'MATRICULA': matriculaController.text,
                                    'MEDIDA': medidaController.text,
                                    'MARCA': marcaController.text,
                                    'TRABAJO': trabajoController.text,
                                    'TRABAJOALTERNO':
                                        trabajoAlternoController.text,
                                    'UBICACION': null,
                                    'CODIGO_TRA': codigoTraController.text,
                                    'COMPUESTO': compuestoController.text,
                                    'TRABAJO_OTR': trabajoOtrController.text,
                                    'SG': sgController.text,
                                    'OBS': observacionController.text,
                                    'BUS': busController.text,
                                    'ECONOMICO': economicoController.text,
                                  };

                                  final datosInsertar = {
                                    ...datosActualizar,
                                    'CLIENTE': widget.orden.cliente,
                                    'RAZONSOCIAL': widget.orden.razonsocial,
                                    'EMPRESA': empresaController.text,
                                    'VEND': vendedorController.text,
                                  };

                                  final jsonFinal =
                                      isCreating
                                          ? datosInsertar
                                          : datosActualizar;

                                  debugPrint(
                                    '📤 Enviando JSON: ${jsonEncode(jsonFinal)}',
                                  );
                                  // ---------------------------------------------------------------
                                  try {
                                    final api = ApiService();
                                    final result =
                                        isCreating
                                            ? await api.insertMOrdenes(
                                              jsonFinal,
                                            )
                                            : await api.updateMOrdenes(
                                              jsonFinal,
                                            );

                                    // ✅ Guardar también en SQLite aunque la API funcione
                                    final datosLocal = {
                                      ...jsonFinal,
                                      'LOCAL': 'N', // Guardado en línea
                                      'FECHASYS': DateFormat(
                                        'yyyy-MM-dd HH:mm:ss',
                                      ).format(DateTime.now()),
                                    };
                                    await MOrdenesDAO.insertarMOrden(
                                      datosLocal,
                                    );
                                    debugPrint(
                                      '📥 Guardado en SQLite con LOCAL=N',
                                    );
                                    
                                    // 👉 Bitácora
                                    if (!isCreating && selectedIndex != null) {
                                      final anterior = marbetes[selectedIndex!];
                                      final cambios = <String>[];

                                      for (final campo
                                          in datosActualizar.keys) {
                                        final nuevo =
                                            datosActualizar[campo]
                                                ?.toString() ??
                                            '';
                                        final viejo =
                                            anterior[campo]?.toString() ?? '';
                                        if (nuevo != viejo) {
                                          cambios.add(
                                            '$campo: "$viejo" → "$nuevo"',
                                          );
                                        }
                                      }

                                      if (cambios.isNotEmpty) {
                                        final observacion =
                                            'Se actualizó el marbete $marbeteActual. Cambios:\n${cambios.join('\n')}';

                                        final bitacoraData = {
                                          'REG': 1,
                                          'ORDEN': ordenActual,
                                          'MARBETE': marbeteActual,
                                          'OBSERVACION': observacion,
                                          'FECHASYS': DateFormat(
                                            'yyyy-MM-dd HH:mm:ss',
                                          ).format(DateTime.now()),
                                          'USUARIO':
                                              vendedorController.text.trim(),
                                        };

                                        try {
                                          await api.insertBitacorasOt(
                                            bitacoraData,
                                          );
                                          debugPrint('📝 Bitácora insertada');
                                        } catch (_) {
                                          try {
                                            await api.updateBitacorasOt(
                                              bitacoraData,
                                            );
                                            debugPrint(
                                              '📝 Bitácora actualizada',
                                            );
                                          } catch (e2) {
                                            debugPrint(
                                              '❌ No se pudo actualizar bitácora: $e2',
                                            );
                                          }
                                        }
                                      }
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ ${isCreating ? "Insertado" : "Actualizado"}: $result',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    if (isCreating) {
                                      marbetes.add(datosInsertar);
                                    } else if (selectedIndex != null) {
                                      marbetes[selectedIndex!] =
                                          datosActualizar;
                                    }

                                    limpiarCampos();
                                    isCreating = false;
                                    isEditing = false;
                                    mostrarBotonesEdicion = false;
                                    selectedIndex = null;
                                    setState(() {});
                                  } catch (e) {
                                    debugPrint('❌ Error: $e');

                                    final datosLocal = {
                                      ...jsonFinal,
                                      'LOCAL': 'S',
                                      'FECHASYS': DateFormat(
                                        'yyyy-MM-dd HH:mm:ss',
                                      ).format(DateTime.now()),
                                    };

                                    await MOrdenesDAO.insertarMOrden(
                                      datosLocal,
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '📴 Marbete guardado localmente en SQLite',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );

                                    debugPrint(
                                      '📦 JSON guardado en SQLite:\n${const JsonEncoder.withIndent('  ').convert(datosLocal)}',
                                    );

                                    if (isCreating) {
                                      marbetes.add(datosLocal);
                                    } else if (selectedIndex != null) {
                                      marbetes[selectedIndex!] = datosLocal;
                                    }

                                    limpiarCampos();
                                    isCreating = false;
                                    isEditing = false;
                                    mostrarBotonesEdicion = false;
                                    selectedIndex = null;
                                    setState(() {});
                                  }
                                }
                                : null,
                      ),
                      const SizedBox(width: 24),
                      _iconAction(
                        icon: Icons.cancel,
                        label: 'Cancelar',
                        onTap:
                            (mostrarBotonesEdicion)
                                ? () {
                                  limpiarCampos();
                                  isEditing = false;
                                  isCreating = false;
                                  mostrarBotonesEdicion = false;
                                  selectedIndex = null;
                                  setState(() {});
                                }
                                : null,
                      ),
                      const SizedBox(width: 24),

                      _iconAction(
                        icon: Icons.delete_forever,
                        label: 'Elimina Marbete',
                        onTap:
                            (!widget.soloLectura &&
                                    !mostrarBotonesEdicion &&
                                    selectedIndex != null)
                                ? () async {
                                  final marbeteSeleccionado =
                                      marbetes[selectedIndex!];
                                  final marbeteId =
                                      marbeteSeleccionado['MARBETE'];
                                  final ubicacion =
                                      marbeteSeleccionado['UBICACION'] ?? '';

                                  if (ubicacion.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '❌ No se puede eliminar un marbete con ubicación asignada.',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  final confirmado = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (ctx) => AlertDialog(
                                          title: const Text('Confirmación'),
                                          content: Text(
                                            '¿Deseas eliminar este marbete $marbeteId?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, false),
                                              child: const Text('No'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, true),
                                              child: const Text('Sí'),
                                            ),
                                          ],
                                        ),
                                  );

                                  if (confirmado ?? false) {
                                    try {
                                      final api = ApiService();
                                      final result = await api.deleteMOrdenes(
                                        marbeteId,
                                      );

                                      print(
                                        '✅ Eliminado del servidor: $result',
                                      );

                                      selectedIndex = null;
                                      limpiarCampos();

                                      await cargarMarbetes();
                                      setState(() {});

                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '✅ Marbete eliminado: $marbeteId',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    } catch (e) {
                                      print(
                                        '❌ Error al eliminar marbete $marbeteId: $e',
                                      );

                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '❌ Error al eliminar: $e',
                                                ),
                                                backgroundColor:
                                                    Colors.red.shade400,
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    }
                                  }
                                }
                                : null,
                      ),

                      const SizedBox(width: 24),
                      _iconAction(
                        icon: Icons.close,
                        label: 'Cerrar',
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const Text(
                  '📌 Detalles del Marbete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampoConController3(
                              'Marbete',
                              marbeteController,
                              clave: 'marbete',
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Campo requerido'
                                          : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCampoConController2(
                              'Matrícula',
                              matriculaController,
                              clave: 'matricula',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '⚠ Matrícula requerida';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController(
                              'Medida',
                              medidaController,
                              clave: 'medida',
                              opciones: medidas,
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Seleccione una medida'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController(
                              'Marca',
                              marcaController,
                              clave: 'marca',
                              opciones: marcas,
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Seleccione una marca'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController(
                              'Trabajo',
                              trabajoController,
                              clave: 'trabajo',
                              opciones: terminados,
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Seleccione un trabajo'
                                          : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownConController3(
                              'Trabajo alterno',
                              trabajoAlternoController,
                              clave: 'trabajoAlterno',
                              opciones: terminados,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      /// NUEVOS CAMPOS INTEGRADOS:
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampoConController(
                              'Bus',
                              busController, // ✅ correcto(),
                              clave: 'bus',
                              validator: (value) => null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCampoConController(
                              'Economico',
                              economicoController,
                              clave: 'economico',
                              validator: (value) => null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController2(
                              'Código TRA',
                              codigoTraController,
                              clave: 'codigoTra',
                              opciones: trabajos,
                              validator: (value) {
                                final codigoLleno =
                                    value != null && value.trim().isNotEmpty;
                                final compuestoLleno =
                                    compuestoController.text.trim().isNotEmpty;
                                final trabajoOtrLleno =
                                    trabajoOtrController.text.trim().isNotEmpty;

                                if (codigoLleno &&
                                    (!compuestoLleno || !trabajoOtrLleno)) {
                                  return 'Completa Compuesto y Trabajo OTR';
                                }

                                if (value != null &&
                                    value.isNotEmpty &&
                                    !trabajos.contains(value.toUpperCase())) {
                                  return '❌ Seleccione una opción válida';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownConController2(
                              'Compuesto',
                              compuestoController,
                              clave: 'compuesto',
                              opciones: compuestos,
                              validator: (value) {
                                final codigoLleno =
                                    codigoTraController.text.trim().isNotEmpty;
                                if (codigoLleno &&
                                    (value == null || value.trim().isEmpty)) {
                                  return '⚠ Requerido si Código TRA tiene valor';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController2(
                              'Trabajo OTR',
                              trabajoOtrController,
                              clave: 'trabajoOtr',
                              opciones: trabajosOtr,
                              validator: (value) {
                                final codigoLleno =
                                    codigoTraController.text.trim().isNotEmpty;
                                if (codigoLleno &&
                                    (value == null || value.trim().isEmpty)) {
                                  return '⚠ Requerido si Código TRA tiene valor';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownConController3(
                              'Garantía',
                              sgController,
                              clave: 'sg',
                              opciones: sg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildCampoConController(
                              'Observación',
                              observacionController,
                              clave: 'observacion',
                              validator: (value) => null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Text(
                  '📄 Lista de Marbetes Registrados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowColor: WidgetStateProperty.resolveWith(
                          (states) => Colors.deepPurple.shade50,
                        ),
                        dataRowMinHeight: 30,
                        dataRowMaxHeight: 40,
                        columns: const [
                          DataColumn(label: Text('Marbete')),
                          DataColumn(label: Text('Matrícula')),
                          DataColumn(label: Text('Medida')),
                          DataColumn(label: Text('Marca')),
                          DataColumn(label: Text('Trabajo')),
                          DataColumn(label: Text('Trabajo alterno')),
                          DataColumn(label: Text('BUS')), // ✅ CAMBIO
                          DataColumn(label: Text('Económico')), // ✅ CAMBIO
                          DataColumn(label: Text('SG')),
                        ],
                        rows: List.generate(marbetes.length, (index) {
                          final e = marbetes[index];
                          final bool isSelected = selectedIndex == index;

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) =>
                                  isSelected ? Colors.blue.shade100 : null,
                            ),
                            cells: [
                              DataCell(
                                Text(e['MARBETE'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['MATRICULA'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['MEDIDA'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['MARCA'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['TRABAJO'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['TRABAJOALTERNO'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['BUS'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['ECONOMICO'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(e['SG'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                            ],
                          );
                        }),
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

  Widget buildLabelField(
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
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget buildCampo(String label) {
    return SizedBox(
      width: 180,
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey : Color(0xFFF7B234),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget buildDropdown(String label) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 220, maxWidth: 250),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: const [],
        onChanged: (value) {},
      ),
    );
  }
}
