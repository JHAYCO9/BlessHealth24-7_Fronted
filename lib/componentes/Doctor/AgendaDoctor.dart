import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:bless_health24/componentes/shared/app_logo_badge.dart';
import 'AtenderPaciente.dart';
import 'DiagnosticoPaciente.dart';
import 'Paciente.dart';

class AgendaDoctorPage extends StatefulWidget {
  const AgendaDoctorPage({super.key});

  @override
  State<AgendaDoctorPage> createState() => _AgendaDoctorPageState();
}

class _AgendaDoctorPageState extends State<AgendaDoctorPage> {
  List<dynamic> _citasPendientes = [];
  bool _isLoading = true;
  DateTime _fechaSeleccionada = DateTime.now();
  String? _cedulaMedico;

  @override
  void initState() {
    super.initState();
    _cargarDatosMedico();
  }

  // Cargar datos del médico desde SharedPreferences
  Future<void> _cargarDatosMedico() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cedulaMedico = prefs.getString("cedulaMedico");
    });

    if (_cedulaMedico != null) {
      _cargarCitasPorFecha();
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró informacion del medico")),
      );
    }
  }

  // Cargar citas por fecha
  Future<void> _cargarCitasPorFecha() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Formatear fechas para la API
      final fechaInicio = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
      final fechaFin = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

      final response = await http.post(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/citas/doctor/$_cedulaMedico",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"fechaInicio": fechaInicio, "fechaFin": fechaFin}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final lista = decoded is List
            ? decoded
            : (decoded is Map && decoded["data"] is List)
            ? decoded["data"]
            : [];
        final pendientes = lista.where((cita) {
          try {
            final estado = cita["estadoCita"]?.toString();
            return estado == null || estado == "Pendiente";
          } catch (_) {
            return true;
          }
        }).toList();
        setState(() {
          _citasPendientes = pendientes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _citasPendientes = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar citas: ${response.body}")),
        );
      }
    } catch (e) {
      setState(() {
        _citasPendientes = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cargar citas: $e")));
    }
  }

  // Finalizar cita
  Future<void> _finalizarCita(int idCita) async {
    try {
      final response = await http.put(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/citas/$idCita/finalizar",
        ),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cita finalizada con éxito")),
        );
        _cargarCitasPorFecha(); // Recargar citas
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al finalizar cita: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al finalizar cita: $e")));
    }
  }

  // Cancelar cita
  Future<void> _cancelarCita(int idCita) async {
    try {
      final response = await http.put(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/citas/$idCita/cancelar",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"motivoCancelacion": "Cancelada por el médico"}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cita cancelada con éxito")),
        );
        _cargarCitasPorFecha(); // Recargar citas
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cancelar cita: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cancelar cita: $e")));
    }
  }

  // Seleccionar fecha
  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2023),
      lastDate: DateTime(2025),
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
      _cargarCitasPorFecha();
    }
  }

  String? _obtenerDocumentoPaciente(Map<String, dynamic> cita) {
    const posibles = [
      'documentoPaciente',
      'numeroDocumentoPaciente',
      'numeroDocumento',
      'cedulaPaciente',
      'cedula',
      'documento',
    ];
    for (final key in posibles) {
      final value = cita[key];
      if (value != null) {
        final texto = value.toString().trim();
        if (texto.isNotEmpty) {
          return texto;
        }
      }
    }
    return null;
  }

  Future<void> _navegarAAtencion(Map<String, dynamic> cita) async {
    final nombreCompleto =
        "${cita['nombrePaciente'] ?? 'N/A'} ${cita['apellidoPaciente'] ?? ''}"
            .trim();
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AtenderPacientePage(
          cita: cita,
          nombrePaciente: nombreCompleto.isEmpty ? 'Paciente' : nombreCompleto,
        ),
      ),
    );
    if (resultado == true) {
      _cargarCitasPorFecha();
    }
  }

  void _navegarAPaciente(Map<String, dynamic> cita) {
    final documento = _obtenerDocumentoPaciente(cita);
    if (documento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el documento del paciente.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Paciente(documentoId: documento)),
    );
  }

  // Navegar a la página de diagnóstico
  void _navegarADiagnostico(Map<String, dynamic> cita) async {
    final nombreCompleto =
        "${cita['nombrePaciente'] ?? 'N/A'} ${cita['apellidoPaciente'] ?? ''}";
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DiagnosticoPacientePage(cita: cita, nombrePaciente: nombreCompleto),
      ),
    );

    // Si se guardó el diagnóstico, recargar las citas
    if (resultado == true) {
      _cargarCitasPorFecha();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Agenda de citas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _seleccionarFecha,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/Fondo.png", fit: BoxFit.cover),
          ),
          Column(
            children: [
              const SizedBox(height: 20),
              const Center(child: AppLogoBadge()),
              const SizedBox(height: 24),
              // Fecha seleccionada
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Fecha: ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _seleccionarFecha,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                      ),
                      child: const Text("Cambiar"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _citasPendientes.isEmpty
                      ? const Center(
                          child: Text(
                            "No hay citas pendientes para esta fecha",
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _citasPendientes.length,
                          itemBuilder: (context, index) {
                            final Map<String, dynamic> cita =
                                Map<String, dynamic>.from(
                                  _citasPendientes[index] as Map,
                                );
                            return Card(
                              margin: const EdgeInsets.only(bottom: 15),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                DateFormat(
                                                  'MMM',
                                                ).format(_fechaSeleccionada),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal.shade700,
                                                ),
                                              ),
                                              Text(
                                                DateFormat(
                                                  'dd',
                                                ).format(_fechaSeleccionada),
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${cita['nombrePaciente'] ?? 'N/A'} ${cita['apellidoPaciente'] ?? ''}",
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                "${cita['nombreServicio'] ?? 'Servicio no especificado'}",
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          "Hora: ${cita['fechaHora'] != null ? cita['fechaHora'].toString().substring(11, 16) : 'N/A'}",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.medical_services_outlined,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            "Motivo: ${cita['motivo'] ?? 'No especificado'}",
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _navegarAPaciente(cita),
                                          icon: const Icon(
                                            Icons.person_outline,
                                            color: Colors.teal,
                                          ),
                                          label: const Text(
                                            "Paciente",
                                            style: TextStyle(
                                              color: Colors.teal,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _navegarAAtencion(cita),
                                          icon: const Icon(
                                            Icons.healing_outlined,
                                            color: Colors.orange,
                                          ),
                                          label: const Text(
                                            "Atender",
                                            style: TextStyle(
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _navegarADiagnostico(cita),
                                          icon: const Icon(
                                            Icons.medical_services,
                                            color: Colors.blue,
                                          ),
                                          label: const Text(
                                            "Diagnóstico",
                                            style: TextStyle(
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _finalizarCita(cita['idCita']),
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.green,
                                          ),
                                          label: const Text(
                                            "Finalizar",
                                            style: TextStyle(
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _cancelarCita(cita['idCita']),
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            "Cancelar",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
