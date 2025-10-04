import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'signature_pad.dart';
import 'archivos_local_helper.dart';
import 'package:bless_health24/componentes/shared/info_row.dart';
import 'package:bless_health24/componentes/shared/app_logo_badge.dart';

class MedicinaPage extends StatefulWidget {
  final int idHistoriaClinica;
  final String nombreDoctor;

  const MedicinaPage({
    super.key,
    required this.idHistoriaClinica,
    required this.nombreDoctor,
  });

  @override
  State<MedicinaPage> createState() => _MedicinaPageState();
}

class _MedicinaPageState extends State<MedicinaPage> {
  final TextEditingController _medicamentosController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _historia = {};
  Map<String, dynamic> _historialCompleto = {};
  final GlobalKey<SignaturePadState> _firmaKey = GlobalKey<SignaturePadState>();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _medicamentosController.dispose();
    super.dispose();
  }

  // ---------------------- Helpers HTTP ----------------------

  Future<Map<String, dynamic>?> _getJson(Uri url) async {
    final resp = await http.get(url);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      // Acepta {data: {...}}, {data: [...]}, {...} o [...]
      if (decoded is Map && decoded['data'] != null) {
        final data = decoded['data'];
        if (data is List) {
          return data.isNotEmpty ? Map<String, dynamic>.from(data.first) : null;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
      if (decoded is List) {
        return decoded.isNotEmpty
            ? Map<String, dynamic>.from(decoded.first)
            : null;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getHistoriaById(int idHistoria) async {
    final url = Uri.parse(
      'https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/historias-clinicas/$idHistoria',
    );
    return _getJson(url);
  }

  // OJO: En tu Postman, historial-completo es por idPaciente (no por idHistoriaClinica)
  Future<Map<String, dynamic>?> _getHistorialCompletoByPaciente(
    int idPaciente,
  ) async {
    final url = Uri.parse(
      'https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/historias-clinicas/historial-completo/$idPaciente',
    );
    return _getJson(url);
  }

  // ---------------------- Carga de datos ----------------------

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // 1) Obtener la historia por ID para descubrir idPaciente + medicamentos actuales
      final historia = await _getHistoriaById(widget.idHistoriaClinica);

      if (!mounted) {
        return;
      }

      if (historia == null) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'No se encontrÃ³ la historia clÃ­nica #${widget.idHistoriaClinica}.';
          _isLoading = false;
        });
        return;
      }

      // Guardar historia base
      _historia = historia;

      // Pre-cargar medicamentos si existen
      _medicamentosController.text = (_historia['medicamentos'] ?? '')
          .toString();

      // 2) Intentar cargar historial completo por idPaciente (si lo tenemos)
      final idPaciente =
          _historia['idPaciente'] ??
          (_historia['paciente'] is Map
              ? _historia['paciente']['idUsuario']
              : null);

      if (idPaciente is int) {
        final hc = await _getHistorialCompletoByPaciente(idPaciente);
        if (hc != null) {
          _historialCompleto = hc;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error de conexiÃ³n: $e';
      });
    }
  }

  // ---------------------- Guardar medicamentos ----------------------

  Future<void> _guardarMedicamentos() async {
    final firmaState = _firmaKey.currentState;
    if (firmaState == null || firmaState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor firma la orden antes de guardar'),
        ),
      );
      return;
    }

    final firmaBytes = await firmaState.toPngBytes();
    if (firmaBytes == null || firmaBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo capturar la firma, intenta nuevamente'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final medicamentosTexto = _medicamentosController.text.trim();

    try {
      final existente = await _getHistoriaById(widget.idHistoriaClinica);

      Map<String, dynamic> body;

      if (existente != null && existente.isNotEmpty) {
        body = {
          if (existente['idPaciente'] != null)
            'idPaciente': existente['idPaciente'],
          'tipoSangre': existente['tipoSangre'],
          'alergias': existente['alergias'],
          'enfermedadesCronicas': existente['enfermedadesCronicas'],
          'medicamentos': medicamentosTexto,
          'antecedentesFamiliares': existente['antecedentesFamiliares'],
          'observaciones': existente['observaciones'],
        };
      } else {
        body = {'medicamentos': medicamentosTexto};
      }

      final resp = await http.put(
        Uri.parse(
          'https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/historias-clinicas/${widget.idHistoriaClinica}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      if (!mounted) {
        return;
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _guardarResumenMedicamentos(
          medicamentos: medicamentosTexto,
          firmaPng: firmaBytes.toList(),
        );
        await _mostrarResumenMedicamentos(
          medicamentos: medicamentosTexto,
          firmaBytes: firmaBytes,
        );
        firmaState.clear();
        _historia['medicamentos'] = medicamentosTexto;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicamentos actualizados con exito')),
        );
        Navigator.pop(context, true);
      } else {
        String msg = 'Error al guardar (${resp.statusCode})';
        try {
          final err = jsonDecode(resp.body);
          if (err is Map && err['message'] != null) {
            msg = 'Error: ${err['message']}';
          }
        } catch (_) {}
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar medicamentos: $e')),
      );
    }
  }

  Future<void> _guardarResumenMedicamentos({
    required String medicamentos,
    required List<int> firmaPng,
  }) async {
    final now = DateTime.now();
    final resumen = _construirResumenMedicamentos(medicamentos, now);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);

    await ArchivosLocalHelper.addBytes(
      idHistoriaClinica: widget.idHistoriaClinica,
      nombre: 'Receta medicamentos $timestamp',
      mimeType: 'text/plain',
      bytes: utf8.encode(resumen),
    );

    if (firmaPng.isNotEmpty) {
      await ArchivosLocalHelper.addBytes(
        idHistoriaClinica: widget.idHistoriaClinica,
        nombre: 'Firma receta $timestamp',
        mimeType: 'image/png',
        bytes: firmaPng,
      );
    }
  }

  Future<void> _mostrarResumenMedicamentos({
    required String medicamentos,
    required Uint8List firmaBytes,
  }) async {
    final resumen = _construirResumenMedicamentos(medicamentos, DateTime.now());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resumen de la receta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(resumen),
              const SizedBox(height: 12),
              const Text(
                'Firma',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Image.memory(firmaBytes, height: 150, fit: BoxFit.contain),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _construirResumenMedicamentos(String medicamentos, DateTime fecha) {
    final paciente =
        (_historialCompleto['paciente'] as Map?) ??
        (_historia['paciente'] as Map?) ??
        {};
    final nombre =
        ('${paciente['nombreUsuario'] ?? paciente['nombre'] ?? ''} '
                '${paciente['apellidoUsuario'] ?? paciente['apellido'] ?? ''}')
            .trim();
    final documento =
        (paciente['numeroDocumento'] ?? paciente['documento'] ?? 'N/A')
            .toString();
    final contenido = medicamentos.isEmpty ? '- Sin especificar' : medicamentos;
    final fechaTexto = DateFormat('yyyy-MM-dd HH:mm').format(fecha);

    final buffer = StringBuffer()
      ..writeln('Receta de medicamentos')
      ..writeln('Doctor: ${widget.nombreDoctor}')
      ..writeln('Paciente: ${nombre.isEmpty ? 'N/A' : nombre}')
      ..writeln('Documento: $documento')
      ..writeln('Medicamentos indicados:')
      ..writeln(contenido)
      ..writeln('Generada: $fechaTexto');

    return buffer.toString();
  }

  String _calcularEdad(String? fechaNacimiento) {
    try {
      if (fechaNacimiento == null || fechaNacimiento.isEmpty) return 'N/A';
      final fn = DateTime.parse(fechaNacimiento);
      final hoy = DateTime.now();
      int edad = hoy.year - fn.year;
      if (hoy.month < fn.month || (hoy.month == fn.month && hoy.day < fn.day)) {
        edad--;
      }
      return edad.toString();
    } catch (_) {
      return 'N/A';
    }
  }

  String _extraerCiudad(String? direccion) {
    if (direccion == null || direccion.isEmpty) return 'N/A';
    try {
      final partes = direccion.split(',');
      return partes.length > 1 ? partes.last.trim() : direccion;
    } catch (_) {
      return direccion;
    }
  }

  // ---------------------- Build ----------------------

  @override
  Widget build(BuildContext context) {
    final paciente =
        (_historialCompleto['paciente'] as Map?) ??
        (_historia['paciente'] as Map?) ??
        {};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF007A7A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Medicinas',
          style: TextStyle(
            color: Color(0xFF007A7A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F7FA), Color(0xFF007A7A)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
            ? Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : _buildContent(paciente),
      ),
    );
  }

  Widget _buildContent(Map paciente) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        const Center(child: AppLogoBadge()),
        const SizedBox(height: 24),
        // Nombre del mÃ©dico
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            widget.nombreDoctor.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Tarjeta principal
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perfil del Paciente:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF007A7A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(paciente['nombreUsuario'] ?? '')} ${(paciente['apellidoUsuario'] ?? '')}'
                      .trim(),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                const Text(
                  'InformaciÃ³n Personal:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF007A7A),
                  ),
                ),
                const SizedBox(height: 8),
                InfoRow(
                  label: 'Documento',
                  value: '${paciente['numeroDocumento'] ?? 'N/A'}',
                  labelWidth: 120,
                  alignEnd: false,
                  showColon: true,
                  valueStyle: const TextStyle(),
                ),
                InfoRow(
                  label: 'Edad',
                  value: _calcularEdad(paciente['fechaNacimiento']?.toString()),
                  labelWidth: 120,
                  alignEnd: false,
                  showColon: true,
                  valueStyle: const TextStyle(),
                ),
                InfoRow(
                  label: 'Género',
                  value: '${paciente['genero'] ?? 'N/A'}',
                  labelWidth: 120,
                  alignEnd: false,
                  showColon: true,
                  valueStyle: const TextStyle(),
                ),
                InfoRow(
                  label: 'Teléfono',
                  value: '${paciente['telefonoUsuario'] ?? 'N/A'}',
                  labelWidth: 120,
                  alignEnd: false,
                  showColon: true,
                  valueStyle: const TextStyle(),
                ),
                InfoRow(
                  label: 'Ciudad',
                  value: _extraerCiudad(
                    paciente['direccionUsuario']?.toString(),
                  ),
                  labelWidth: 120,
                  alignEnd: false,
                  showColon: true,
                  valueStyle: const TextStyle(),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Datos ClÃ­nicos:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF007A7A),
                  ),
                ),
                const SizedBox(height: 8),

                const Divider(thickness: 1),

                const Text(
                  'Medicamentos:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF007A7A),
                  ),
                ),
                const SizedBox(height: 8),

                Stack(
                  children: [
                    TextField(
                      controller: _medicamentosController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: 'Ingrese los medicamentos del paciente',
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: const Color(0xFF80DEEA),
                        child: const Icon(Icons.add),
                        onPressed: () {
                          // Inserta "- " al final como nueva lÃ­nea
                          final current = _medicamentosController.text;
                          final newline = current.isEmpty
                              ? '- '
                              : '$current\n- ';
                          _medicamentosController.text = newline;
                          _medicamentosController.selection =
                              TextSelection.fromPosition(
                                TextPosition(
                                  offset: _medicamentosController.text.length,
                                ),
                              );
                        },
                      ),
                    ),
                  ],
                ),

                const Text(
                  'Firma del médico',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: SignaturePad(
                    key: _firmaKey,
                    penColor: Colors.black,
                    strokeWidth: 2.0,
                    controller: SignaturePadController(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _firmaKey.currentState?.clear(),
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Limpiar firma'),
                  ),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 24),

                Center(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _guardarMedicamentos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF80DEEA),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Guardar',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
