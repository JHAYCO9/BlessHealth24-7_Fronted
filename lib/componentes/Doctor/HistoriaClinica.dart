import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:bless_health24/componentes/shared/info_row.dart';
import 'package:bless_health24/componentes/shared/state_views.dart';
import 'package:bless_health24/componentes/shared/app_logo_badge.dart';

import 'Archivos.dart';
import 'Paciente.dart';
import 'doctor_action_bar.dart';
import 'Medicina.dart';
import 'Remitir.dart';
import 'doctor_helpers.dart';

class HistoriaClinicaPage extends StatefulWidget {
  final String? initialDocumento;
  final bool autoSearch;
  final bool mostrarArchivosInicial;

  const HistoriaClinicaPage({
    super.key,
    this.initialDocumento,
    this.autoSearch = false,
    this.mostrarArchivosInicial = false,
  });

  @override
  State<HistoriaClinicaPage> createState() => _HistoriaClinicaPageState();
}

class _HistoriaClinicaPageState extends State<HistoriaClinicaPage> {
  final TextEditingController _documentoController = TextEditingController();
  Map<String, dynamic>? _historiaClinica;
  bool _cargando = false;
  bool _error = false;
  String _mensajeError = '';
  bool _mostrarArchivos = false;
  String _nombrePaciente = '';
  Map<String, dynamic> _datosPaciente = {};

  static const String _baseUrl =
      'https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api';

  List<dynamic> _extraerLista(dynamic source) {
    if (source is List) return source;
    if (source is Map && source['data'] is List) {
      return List<dynamic>.from(source['data']);
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _mostrarArchivos = widget.mostrarArchivosInicial;
    final documento = widget.initialDocumento?.trim();
    if (documento != null && documento.isNotEmpty) {
      _documentoController.text = documento;
      if (widget.autoSearch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _buscarHistoriaClinica(
            mostrarArchivosLuego: widget.mostrarArchivosInicial,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _documentoController.dispose();
    super.dispose();
  }

  // Buscar historia clínica por documento

  Future<void> _buscarHistoriaClinica({
    bool mostrarArchivosLuego = false,
  }) async {
    final documento = _documentoController.text.trim();
    if (documento.isEmpty) {
      setState(() {
        _error = true;
        _mensajeError = 'Ingresa un número de documento.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = false;
      _mensajeError = '';
      _historiaClinica = null;
      _mostrarArchivos = false;
    });

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/historias-clinicas/documento/$documento'))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 404) {
        setState(() {
          _error = true;
          _mensajeError =
              'No encontramos historia clínica para el documento $documento.';
        });
        return;
      }
      if (response.statusCode >= 400) {
        throw HttpException(
          'Error ${response.statusCode} al buscar la historia clínica.',
        );
      }

      final decoded = jsonDecode(response.body);
      final lista = _extraerLista(decoded);
      if (lista.isEmpty) {
        setState(() {
          _error = true;
          _mensajeError =
              'No encontramos historia clínica para el documento $documento.';
        });
        return;
      }

      final historia = Map<String, dynamic>.from(
        lista.first as Map<dynamic, dynamic>,
      );
      final paciente = Map<String, dynamic>.from(
        (historia['paciente'] as Map<dynamic, dynamic>? ?? {}),
      );
      final registros = _extraerLista(historia['registrosConsultas'])
          .map<Map<String, dynamic>>(
            (registro) =>
                Map<String, dynamic>.from(registro as Map<dynamic, dynamic>),
          )
          .toList();
      historia['registrosConsultas'] = registros;

      setState(() {
        _historiaClinica = historia;
        _nombrePaciente =
            "${paciente['nombreUsuario'] ?? ''} ${paciente['apellidoUsuario'] ?? ''}"
                .trim();
        _datosPaciente = {
          'idPaciente': paciente['idUsuario'],
          'cedula': paciente['numeroDocumento'],
          'nombres': paciente['nombreUsuario'],
          'apellidos': paciente['apellidoUsuario'],
        };
        _mostrarArchivos = mostrarArchivosLuego;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = true;
        _mensajeError =
            'La solicitud tardó demasiado. Inténtalo nuevamente en unos segundos.';
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _error = true;
        _mensajeError =
            'No fue posible conectarse al servidor. Revisa tu conexión.';
      });
    } on HttpException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _mensajeError = error.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = true;
        _mensajeError = 'La respuesta del servidor es inválida.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _mensajeError = 'Ocurrió un error inesperado: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  // Mostrar sección de archivos
  void _verArchivos() {
    setState(() {
      _mostrarArchivos = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> registrosConsultas =
        ((_historiaClinica?['registrosConsultas'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList());
    final Map<String, dynamic>? primerRegistro = registrosConsultas.isNotEmpty
        ? registrosConsultas.first
        : null;
    final int? idRegistroConsulta =
        primerRegistro != null && primerRegistro['idRegistroConsulta'] is int
        ? primerRegistro['idRegistroConsulta'] as int
        : null;
    final List<DoctorAction> quickActions = _buildQuickActionItems(
      idRegistroConsulta,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Interpretación de la historia clínica",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF00BCD4),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/Fondo.png", fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Center(child: AppLogoBadge()),
                const SizedBox(height: 24),
                if (quickActions.isNotEmpty) ...[const SizedBox(height: 16)],
                // Buscador de historia clínica
                if (!_mostrarArchivos) ...[
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Buscar Historia Clínica",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _documentoController,
                            decoration: InputDecoration(
                              labelText: "Número de Documento",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.person),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _cargando
                                  ? null
                                  : () => _buscarHistoriaClinica(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7FDCDC),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: _cargando
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Buscar",
                                      style: TextStyle(fontSize: 18),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_error) ...[
                  const SizedBox(height: 16),
                  ErrorView(
                    message: _mensajeError,
                    onRetry: () => _buscarHistoriaClinica(),
                  ),
                ],

                // Resultados de la búsqueda
                if (_historiaClinica != null && !_mostrarArchivos) ...[
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Información del Paciente",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.attach_file),
                                onPressed: _verArchivos,
                                tooltip: "Ver archivos",
                              ),
                            ],
                          ),
                          const Divider(),
                          InfoRow(
                            label: 'Nombre',
                            value: _nombrePaciente,
                            labelWidth: 100,
                            alignEnd: false,
                            showColon: true,
                            valueStyle: const TextStyle(),
                          ),
                          InfoRow(
                            label: 'Documento',
                            value:
                                _historiaClinica!['paciente']['numeroDocumento'],
                            labelWidth: 100,
                            alignEnd: false,
                            showColon: true,
                            valueStyle: const TextStyle(),
                          ),
                          InfoRow(
                            label: 'Fecha de creación',
                            value: _historiaClinica!['fechaCreacion'],
                            labelWidth: 100,
                            alignEnd: false,
                            showColon: true,
                            valueStyle: const TextStyle(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Información Médica",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InfoRow(
                            label: 'Tipo de Sangre',
                            value:
                                _historiaClinica!['tipoSangre'] ??
                                'No registrado',
                            labelWidth: 100,
                            alignEnd: false,
                            showColon: true,
                            valueStyle: const TextStyle(),
                          ),
                          InfoRow(
                            label: 'Alergias',
                            value: _historiaClinica!['alergias'] ?? 'Ninguna',
                            labelWidth: 100,
                            alignEnd: false,
                            showColon: true,
                            valueStyle: const TextStyle(),
                          ),
                          InfoRow(
                            label: 'Enfermedades Crónicas',
                            value:
                                _historiaClinica!['enfermedadesCronicas'] ??
                                'Ninguna',
                            labelWidth: 100,
                            alignEnd: false,
                            showColon: true,
                            valueStyle: const TextStyle(),
                          ),
                          InfoRow(
                            label: 'Medicamentos',
                            value:
                                _historiaClinica!['medicamentos'] ?? 'Ninguno',
                            labelWidth: 100,
                            alignEnd: false,
                            showColon: true,
                            valueStyle: const TextStyle(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Diagnósticos",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (registrosConsultas.isNotEmpty)
                            ...registrosConsultas.map<Widget>(
                              (registro) => _buildDiagnosticoItem(registro),
                            )
                          else
                            const Text("No hay diagnósticos registrados"),
                        ],
                      ),
                    ),
                  ),
                ],

                // Sección de archivos
                if (_mostrarArchivos) ...[
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00BCD4),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              _nombrePaciente.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: _historiaClinica == null
                                ? const Center(
                                    child: Text(
                                      "No hay historia clínica seleccionada",
                                    ),
                                  )
                                : ArchivosPage(
                                    cita: {
                                      'idPaciente':
                                          _datosPaciente['idPaciente'],
                                      'idHistoriaClinica':
                                          _historiaClinica?['idHistoriaClinica'],
                                    },
                                    nombrePaciente: _nombrePaciente,
                                    idRegistroConsulta: idRegistroConsulta,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int? _parseIntValue(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  void _abrirPacienteDesdeHistoria(String documento) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => Paciente(documentoId: documento)));
  }

  void _abrirRemitirDesdeHistoria({
    required int idPaciente,
    required int? idRegistroConsulta,
  }) {
    if (idRegistroConsulta == null) {
      _showSnack('No hay un registro de consulta para remitir al paciente.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemitirPage(
          idPaciente: idPaciente,
          idRegistroConsulta: idRegistroConsulta,
          nombrePaciente: _nombrePaciente.isEmpty
              ? 'Paciente'
              : _nombrePaciente,
          documentoPaciente: _datosPaciente['cedula']?.toString(),
        ),
      ),
    );
  }

  Future<void> _abrirMedicinaDesdeHistoria(int idHistoriaClinica) async {
    final nombreDoctor = await loadDoctorFullName();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicinaPage(
          idHistoriaClinica: idHistoriaClinica,
          nombreDoctor: nombreDoctor,
        ),
      ),
    );
  }

  void _abrirArchivosDesdeHistoria({
    int? idPaciente,
    int? idHistoriaClinica,
    int? idRegistroConsulta,
  }) {
    if (idPaciente == null && idHistoriaClinica == null) {
      _showSnack('No hay datos suficientes para mostrar los archivos.');
      return;
    }
    final cita = <String, dynamic>{};
    if (idPaciente != null) cita['idPaciente'] = idPaciente;
    if (idHistoriaClinica != null) {
      cita['idHistoriaClinica'] = idHistoriaClinica;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchivosPage(
          cita: cita,
          nombrePaciente: _nombrePaciente.isEmpty
              ? 'Paciente'
              : _nombrePaciente,
          idRegistroConsulta: idRegistroConsulta,
        ),
      ),
    );
  }

  List<DoctorAction> _buildQuickActionItems(int? idRegistroConsulta) {
    if (_historiaClinica == null) {
      return const <DoctorAction>[];
    }
    final actions = <DoctorAction>[];
    final documento = (_datosPaciente['cedula'] ?? '').toString().trim();
    final idPaciente = _parseIntValue(_datosPaciente['idPaciente']);
    final idHistoria = _parseIntValue(_historiaClinica?['idHistoriaClinica']);

    if (documento.isNotEmpty) {
      actions.add(
        DoctorAction(
          icon: Icons.person_outline,
          label: 'Paciente',
          onPressed: () => _abrirPacienteDesdeHistoria(documento),
        ),
      );
    }

    if (idPaciente != null || idHistoria != null) {
      actions.add(
        DoctorAction(
          icon: Icons.folder_open,
          label: 'Archivos',
          onPressed: () => _abrirArchivosDesdeHistoria(
            idPaciente: idPaciente,
            idHistoriaClinica: idHistoria,
            idRegistroConsulta: idRegistroConsulta,
          ),
        ),
      );
    }

    if (idPaciente != null && idRegistroConsulta != null) {
      actions.add(
        DoctorAction(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Remitir',
          onPressed: () => _abrirRemitirDesdeHistoria(
            idPaciente: idPaciente,
            idRegistroConsulta: idRegistroConsulta,
          ),
        ),
      );
    }

    if (idHistoria != null) {
      actions.add(
        DoctorAction(
          icon: Icons.healing_outlined,
          label: 'Medicina',
          onPressed: () => _abrirMedicinaDesdeHistoria(idHistoria),
        ),
      );
    }

    return actions;
  }

  // Widget para mostrar información en filas
  // Widget para mostrar diagnósticos
  Widget _buildDiagnosticoItem(Map<String, dynamic> registro) {
    final descripcion =
        registro['diagnostico']?.toString() ?? 'Sin diagnóstico';
    final fecha =
        registro['fechaConsulta']?.toString() ?? 'Fecha no registrada';
    final tratamiento = registro['tratamiento']?.toString();
    final observaciones = registro['observaciones']?.toString();
    final presion = registro['presionArterial']?.toString();
    final frecuencia = registro['frecuenciaCardiaca']?.toString();
    final temperatura = registro['temperatura']?.toString();
    final peso = registro['peso'];
    final altura = registro['altura'];
    final imc = registro['imc'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descripcion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Fecha: $fecha'),
            if (tratamiento != null && tratamiento.isNotEmpty)
              Text('Tratamiento: $tratamiento'),
            if (observaciones != null && observaciones.isNotEmpty)
              Text('Observaciones: $observaciones'),
            if ((presion != null && presion.isNotEmpty) ||
                (frecuencia != null && frecuencia.isNotEmpty) ||
                (temperatura != null && temperatura.isNotEmpty) ||
                peso != null)
              const SizedBox(height: 4),
            if (presion != null && presion.isNotEmpty)
              Text('Presión Arterial: $presion'),
            if (frecuencia != null && frecuencia.isNotEmpty)
              Text('Frecuencia Cardíaca: $frecuencia'),
            if (temperatura != null && temperatura.isNotEmpty)
              Text('Temperatura: $temperatura'),
            if (peso != null) Text('Peso: $peso kg'),
            if (altura != null) Text('Altura: $altura m'),
            if (imc != null) Text('IMC: $imc'),
          ],
        ),
      ),
    );
  }
}
