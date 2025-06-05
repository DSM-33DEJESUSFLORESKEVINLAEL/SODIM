// ignore_for_file: use_build_context_synchronously, unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/mordenes_dao.dart';
import 'package:sodim/db/ordenes_dao.dart';
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/utils/sincronizador_service.dart';

class PdfOtForms extends StatefulWidget {
  final Orden orden;
  final bool soloLectura;

  const PdfOtForms({super.key, required this.orden, this.soloLectura = false});

  @override
  State<PdfOtForms> createState() => _PdfOtFormsState();
}

class _PdfOtFormsState extends State<PdfOtForms> {
  List<Map<String, dynamic>> marbetes = [];
  bool cargando = true;
  final TextEditingController empresaController = TextEditingController();
  final TextEditingController vendedorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargarMarbetes();
    cargarVendedorDesdePreferencias();

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

  Future<void> cargarVendedorDesdePreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final vendedorStr = prefs.getString('vendedor');
    if (vendedorStr != null) {
      final vendedorMap = json.decode(vendedorStr);
      empresaController.text = vendedorMap['EMPRESA'].toString();
      vendedorController.text = vendedorMap['VENDEDOR'].toString();
    }
  }

  Future<void> cargarMarbetes() async {
    final api = ApiService();

    // 1. Obtener marbetes del servidor
    final marbetesServidor = await api.getMOrdenes(widget.orden.orden);

    // 🔁 Normalizar marbetes del servidor
    final marbetesServidorNormalizados =
        marbetesServidor.map((e) {
          final mapa = Map<String, dynamic>.from(e);
          mapa['MARBETE'] = mapa['MARBETE']?.toString().toUpperCase().trim();
          return mapa;
        }).toList();

    // 2. Obtener marbetes locales y normalizar
    final marbetesLocalesCrudos = await MOrdenesDAO.obtenerTodosPorOrden(
      widget.orden.orden,
    );

    final marbetesLocales =
        marbetesLocalesCrudos.map((mapa) {
          final nuevo = mapa.map(
            (key, value) => MapEntry(key.toUpperCase(), value),
          );
          nuevo['MARBETE'] = nuevo['MARBETE']?.toString().toUpperCase().trim();
          return nuevo;
        }).toList();

    // 3. Combinar sin duplicados usando Set de marbetes únicos
    final combinados = <Map<String, dynamic>>[];
    final marbetesUnicos = <String>{};

    for (final s in marbetesServidorNormalizados) {
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

    combinados.sort((a, b) {
      final numA =
          int.tryParse(RegExp(r'\d+').stringMatch(a['MARBETE'] ?? '') ?? '0') ??
          0;
      final numB =
          int.tryParse(RegExp(r'\d+').stringMatch(b['MARBETE'] ?? '') ?? '0') ??
          0;
      return numA.compareTo(numB); // O numA.compareTo(numB) para ascendente
    });

    if (!mounted) return;
    setState(() {
      marbetes = combinados;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/SODIM1.png', height: 32),
            const SizedBox(width: 8),
          ],
        ),
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

      // ✅ Botón flotante elevado con Padding
      floatingActionButton:
          cargando
              ? null
              : Padding(
                padding: const EdgeInsets.only(
                  bottom: 40.0,
                ), // 👈 Ajusta aquí la altura deseada
                child: FloatingActionButton.extended(
                  icon: const Icon(Icons.download),
                  label: const Text('Guardar PDF'),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  onPressed: () async {
                    final pdfData = await _buildPdf(PdfPageFormat.a4);
                    await guardarPDFEnDescargas(
                      context,
                      pdfData,
                      'ORDEN_${widget.orden.orden}.pdf',
                    );

                    // ✅ Marcar en SQLite que ya se generó el PDF
                    await OrdenesDAO.marcarPdfGenerado(widget.orden.orden);
                    // ✅ Regresa al HomePage informando que esta orden fue generada
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '✅ PDF generado y marcado como finalizado.',
                        ),
                      ),
                    );

                    Navigator.pop(context, widget.orden.orden);
                  },
                ),
              ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//pero aun salgo de la app y entro a la app y me quita la linea verde
      // ✅ Contenido principal
      body:
          cargando
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  Positioned.fill(
                    child: PdfPreview(
                      build: (format) => _buildPdf(format),
                      canChangePageFormat: true,
                      canChangeOrientation: false,
                      pdfFileName: 'ORDEN_${widget.orden.orden}.pdf',
                    ),
                  ),
                ],
              ),
    );
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final orden = widget.orden; // ✅ MUÉVELO AQUÍ PRIMERO
    final DateTime fecha =
        DateTime.tryParse(orden.fechaCaptura.toString()) ?? DateTime.now();
    final String fechaFormateada =
        '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';

    final pdf = pw.Document();
    // final orden = widget.orden;

    final logoImage = await imageFromAssetBundle('assets/images/logo.png');
    final int totalDescontado =
        marbetes.length -
        (marbetes.any((e) => e['LOCAL']?.toString().toUpperCase() == 'S')
            ? 1
            : 0);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(32)),

        footer:
            (context) => pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount} || SODIM',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
        build:
            (context) => [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logoImage, width: 100),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'LLANTERA ATLAS, S.A. DE C.V.',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'ORDEN DE TRABAJO',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    /// 🔸 PRIMERA FILA: Orden - Cliente
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: 'Orden: ',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: orden.orden,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          flex: 2,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: 'Cliente: ',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text:
                                      '${orden.cliente} - ${orden.razonsocial}',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 6),

                    /// 🔸 SEGUNDA FILA: Fecha - Empresa - Vendedor
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: 'Fecha: ',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: fechaFormateada,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          flex: 1,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: 'Empresa: ',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: empresaController.text,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          flex: 1,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: 'Vendedor: ',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: vendedorController.text,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Text(
                ' Detalle de Marbetes',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: [
                  'MARBETE',
                  'MATRÍCULA',
                  'MEDIDA',
                  'MARCA',
                  'TRABAJO',
                  'ALT.',
                  'BUS',
                  'ECONOMICO',
                  'COMP.',
                  'OTRO',
                ],
                data:
                    marbetes
                        .map(
                          (e) => [
                            e['MARBETE'] ?? '',
                            e['MATRICULA'] ?? '',
                            e['MEDIDA'] ?? '',
                            e['MARCA'] ?? '',
                            e['TRABAJO'] ?? '',
                            e['TRABAJOALTERNO'] ?? '',
                            e['BUS'] ?? '',
                            e['ECONOMICO'] ?? '',
                            e['COMPUESTO'] ?? '',
                            e['TRABAJO_OTR'] ?? '',
                          ],
                        )
                        .toList(),

                cellStyle: const pw.TextStyle(fontSize: 12),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                // headerDecoration: const pw.BoxDecoration(
                //   color: PdfColors.indigo,
                // ),
                headerDecoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF7B234),
                ),

                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 2,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total de marbetes: ${marbetes.length}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                //               pw.Text(
                //   'Total de marbetes: $totalDescontado',
                //   style: pw.TextStyle(
                //     fontSize: 9,
                //     fontWeight: pw.FontWeight.bold,
                //   ),
                // ),
              ),
              pw.SizedBox(
                height: 60,
              ), // ✅ Espacio adicional para que no lo tape el botón flotante
            ],
      ),
    );

    return pdf.save();
  }
}

Future<void> guardarPDFEnDescargas(
  BuildContext context,
  Uint8List pdfData,
  String nombreArchivo,
) async {
  final status = await Permission.manageExternalStorage.request();

  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Permiso de almacenamiento denegado')),
    );
    return;
  }

  // ✅ Crear subcarpeta ORDENES_SODIM dentro de Documents
  final directorioBase = Directory(
    '/storage/emulated/0/Documents/ORDENES_SODIM',
  );
  if (!await directorioBase.exists()) {
    await directorioBase.create(recursive: true);
  }

  final file = File('${directorioBase.path}/$nombreArchivo');

  try {
    await file.writeAsBytes(pdfData);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('✅ PDF guardado: ${file.path}')));
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('❌ Error al guardar: $e')));
  }
}
