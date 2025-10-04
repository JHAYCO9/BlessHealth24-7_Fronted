import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bless_health24/componentes/shared/app_logo_badge.dart';
import 'package:http/http.dart' as http;

import 'Archivos.dart';
import 'doctor_action_bar.dart';

class RemitirPage extends StatefulWidget {
  final int idPaciente; // <- id del paciente
  final int idRegistroConsulta; // <- requerido por ORDENES_MEDICAS
  final String nombrePaciente;
  final String? documentoPaciente;
  final int? idHistoriaClinica;

  const RemitirPage({
    super.key,
    required this.idPaciente,
    required this.idRegistroConsulta,
    required this.nombrePaciente,
    this.documentoPaciente,
    this.idHistoriaClinica,
  });

  @override
  State<RemitirPage> createState() => _RemitirPageState();
}

class _RemitirPageState extends State<RemitirPage> {
  final TextEditingController _diagnosticoController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();

  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 30));
  bool _cargando = true;
  bool _guardando = false;

  // Estructuras visuales
  Map<String, dynamic> _pacienteUI = {}; // valores ya listos para mostrar

  @override
  void initState() {
    super.initState();
    _cargarDatosPaciente();
  }

  @override
  void dispose() {
    _diagnosticoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // Utilidad: calcular edad desde fecha (yyyy-MM-dd)
  String _calcularEdad(String? fechaNacimiento) {
    if (fechaNacimiento == null || fechaNacimiento.isEmpty) return 'N/A';
    try {
      final fn = DateTime.parse(fechaNacimiento);
      final hoy = DateTime.now();
      int edad = hoy.year - fn.year;
      if (hoy.month < fn.month || (hoy.month == fn.month && hoy.day < fn.day)) {
        edad--;
      }
      return '$edad';
    } catch (_) {
      return 'N/A';
    }
  }

  String _soloCiudad(String? direccion) {
    if (direccion == null || direccion.trim().isEmpty) return 'N/A';
    final partes = direccion.split(',');
    return partes.isNotEmpty ? partes.last.trim() : direccion.trim();
  }

  Future<void> _cargarDatosPaciente() async {
    setState(() {
      _cargando = true;
    });

    try {
      final url = Uri.parse(
        "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/historias-clinicas/historial-completo/${widget.idPaciente}",
      );

      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final data = (decoded is Map && decoded['data'] is Map)
            ? Map<String, dynamic>.from(decoded['data'])
            : <String, dynamic>{};

        // Soporte para data.paciente o data.usuario (segn cmo venga del back)
        final rawPaciente = (data['paciente'] is Map)
            ? Map<String, dynamic>.from(data['paciente'])
            : (data['usuario'] is Map)
            ? Map<String, dynamic>.from(data['usuario'])
            : <String, dynamic>{};

        // Normalizacin a nombres de la BD
        final nombre =
            rawPaciente['nombreUsuario'] ?? rawPaciente['nombre'] ?? '';
        final apellido =
            rawPaciente['apellidoUsuario'] ?? rawPaciente['apellido'] ?? '';
        final numeroDocumento =
            rawPaciente['numeroDocumento'] ?? rawPaciente['documento'] ?? '';
        final telefono =
            rawPaciente['telefonoUsuario'] ?? rawPaciente['telefono'] ?? '';
        final direccion =
            rawPaciente['direccionUsuario'] ?? rawPaciente['direccion'] ?? '';
        final genero = (rawPaciente['genero'] ?? '').toString();
        final fechaNac = rawPaciente['fechaNacimiento']?.toString();

        setState(() {
          _pacienteUI = {
            'nombreCompleto': ('$nombre $apellido').trim(),
            'documento': numeroDocumento.isEmpty ? 'N/A' : numeroDocumento,
            'edad': _calcularEdad(fechaNac),
            'genero': genero.isEmpty ? 'N/A' : genero,
            'telefono': telefono.isEmpty ? 'N/A' : telefono,
            'direccion': direccion.isEmpty ? 'N/A' : direccion,
            'ciudad': _soloCiudad(direccion),
            'idHistoriaClinica':
                (widget.idHistoriaClinica ?? data['idHistoriaClinica'])
                    ?.toString() ??
                '',
            'tipoSangre': data['tipoSangre']?.toString() ?? 'N/A',
            'fechaCreacion': data['fechaCreacion']?.toString() ?? '',
          };
          _cargando = false;
        });
      } else {
        setState(() {
          _cargando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _cargando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _guardarOrdenMedica() async {
    final descripcion = _diagnosticoController.text.trim();
    if (descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete el campo de diagnostico'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final body = {
        "idRegistroConsulta": widget.idRegistroConsulta,
        "tipoOrden": "Examen", // Puedes parametrizarlo si quieres
        "descripcion": descripcion,
        "fechaVencimiento": _fechaVencimiento.toString().split(' ').first,
        "observaciones": _observacionesController.text.trim(),
      };

      final resp = await http.post(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/ordenes-medicas",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      setState(() => _guardando = false);

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remision guardada con exito')),
        );
        Navigator.pop(context, true);
      } else {
        String msg = 'Error desconocido';
        try {
          final e = jsonDecode(resp.body);
          msg = (e is Map && e['message'] != null)
              ? e['message'].toString()
              : msg;
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $msg')));
      }
    } catch (e) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar remision: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idHistoria =
        widget.idHistoriaClinica ??
        int.tryParse((_pacienteUI['idHistoriaClinica'] ?? '').toString());
    final quickActions = _buildQuickActionItems(idHistoriaClinica: idHistoria);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Remitir",
          style: TextStyle(color: Color(0xFF00BCD4)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00BCD4)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE0F7FA), Color(0xFF007A7A)],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const SizedBox(height: 12),
                  if (quickActions.isNotEmpty)
                    DoctorActionBar(actions: quickActions),
                  const Center(child: AppLogoBadge()),
                  const SizedBox(height: 24),
                  // Encabezado con el paciente
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      widget.nombrePaciente.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Tarjeta principal
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Perfil del Paciente:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pacienteUI['nombreCompleto'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            "Informacin Personal:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Documento: ${_pacienteUI['documento'] ?? 'N/A'}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "Edad: ${_pacienteUI['edad'] ?? 'N/A'} aos",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "Gnero: ${_pacienteUI['genero'] ?? 'N/A'}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "Telfono: ${_pacienteUI['telefono'] ?? 'N/A'}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "Ciudad: ${_pacienteUI['ciudad'] ?? 'N/A'}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            "Datos Clnicos:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Historia Clnica No: ${_pacienteUI['idHistoriaClinica']}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "Fecha: ${_pacienteUI['fechaCreacion']}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "Tipo de Sangre: ${_pacienteUI['tipoSangre']}",
                            style: const TextStyle(color: Colors.grey),
                          ),

                          const Divider(height: 24),

                          const Text(
                            "Remision / Orden:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Descripcin (diagnstico / motivo)
                          _boxedField(
                            child: TextField(
                              controller: _diagnosticoController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText:
                                    "Descripcin del examen / motivo de remision",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Observaciones
                          _boxedField(
                            child: TextField(
                              controller: _observacionesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: "Observaciones (opcional)",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Fecha de vencimiento
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Fecha de vencimiento"),
                            subtitle: Text(
                              _fechaVencimiento.toString().split(' ').first,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaVencimiento,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _fechaVencimiento = picked);
                                }
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Botn Guardar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _guardando
                                  ? null
                                  : _guardarOrdenMedica,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF80DEEA),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _guardando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Guardar",
                                      style: TextStyle(fontSize: 18),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _abrirArchivos({int? idHistoriaClinica}) {
    final cita = <String, dynamic>{'idPaciente': widget.idPaciente};
    if (idHistoriaClinica != null) {
      cita['idHistoriaClinica'] = idHistoriaClinica;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchivosPage(
          cita: cita,
          nombrePaciente: widget.nombrePaciente,
          idRegistroConsulta: widget.idRegistroConsulta,
        ),
      ),
    );
  }

  List<DoctorAction> _buildQuickActionItems({required int? idHistoriaClinica}) {
    final actions = <DoctorAction>[];

    actions.add(
      DoctorAction(
        icon: Icons.folder_open,
        label: 'Archivos',
        onPressed: () => _abrirArchivos(idHistoriaClinica: idHistoriaClinica),
      ),
    );

    return actions;
  }

  Widget _boxedField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
