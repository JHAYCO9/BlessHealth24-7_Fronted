import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'Archivos.dart';

class DiagnosticoPacientePage extends StatefulWidget {
  final Map<String, dynamic> cita;
  final String nombrePaciente;

  const DiagnosticoPacientePage({
    super.key,
    required this.cita,
    required this.nombrePaciente,
  });

  @override
  State<DiagnosticoPacientePage> createState() =>
      _DiagnosticoPacientePageState();
}

class _DiagnosticoPacientePageState extends State<DiagnosticoPacientePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _fechaConsultaController =
      TextEditingController();
  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _sintomasController = TextEditingController();
  final TextEditingController _presionArterialController =
      TextEditingController();
  final TextEditingController _frecuenciaCardiacaController =
      TextEditingController();
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _alturaController = TextEditingController();

  bool _guardando = false;
  int? _idHistoriaClinica;
  int? _idRegistroConsulta;

  List<dynamic> _extraerLista(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map && decoded['data'] is List) {
      return List<dynamic>.from(decoded['data']);
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _fechaConsultaController.text = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.now());
    _cargarHistoriaClinica();
    _cargarRegistroConsulta();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fechaConsultaController.dispose();
    _motivoController.dispose();
    _sintomasController.dispose();
    _presionArterialController.dispose();
    _frecuenciaCardiacaController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  // Cargar historia clnica del paciente
  Future<void> _cargarHistoriaClinica() async {
    try {
      final idPaciente = widget.cita['idPaciente'];

      final response = await http.get(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/historias-clinicas/paciente/$idPaciente",
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final lista = _extraerLista(decoded);
        if (lista.isNotEmpty) {
          final primero = lista.first as Map<String, dynamic>?;
          setState(() {
            _idHistoriaClinica = primero?['idHistoriaClinica'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar historia clnica: $e")),
      );
    }
  }

  // Cargar registro de consulta existente si hay
  Future<void> _cargarRegistroConsulta() async {
    try {
      final idCita = widget.cita['idCita'];

      final response = await http.get(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/registros-consultas/cita/$idCita",
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final lista = _extraerLista(decoded);
        if (lista.isNotEmpty) {
          final registro = lista.first as Map<String, dynamic>? ?? {};
          setState(() {
            _idRegistroConsulta = registro['idRegistroConsulta'];
            _fechaConsultaController.text =
                registro['fechaConsulta']?.toString() ?? '';
            _motivoController.text =
                registro['motivoConsulta']?.toString() ?? '';
            _sintomasController.text = registro['sintomas']?.toString() ?? '';
            _presionArterialController.text =
                registro['presionArterial']?.toString() ?? '';
            _frecuenciaCardiacaController.text =
                registro['frecuenciaCardiaca']?.toString() ?? '';
            _pesoController.text = registro['peso'] != null
                ? '${registro['peso']}'
                : '';
            _alturaController.text = registro['altura'] != null
                ? '${registro['altura']}'
                : '';
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cargar consulta: $e")));
    }
  }

  // Guardar registro de consulta
  Future<void> _guardarConsulta() async {
    if (_fechaConsultaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingrese la fecha de consulta")),
      );
      return;
    }

    if (_idHistoriaClinica == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se encontr historia clnica del paciente"),
        ),
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final idCita = widget.cita['idCita'];
      final prefs = await SharedPreferences.getInstance();
      final idMedico = prefs.getString("idMedico");

      final idMedicoParsed = int.tryParse(idMedico ?? '');
      if (idMedicoParsed == null || idMedicoParsed <= 0) {
        setState(() {
          _guardando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No se encontr un identificador de mdico vlido. Inicie sesin nuevamente.",
            ),
          ),
        );
        return;
      }

      final double? peso = double.tryParse(_pesoController.text.trim());
      final double? altura = double.tryParse(_alturaController.text.trim());

      final body = {
        "idHistoriaClinica": _idHistoriaClinica,
        "idMedico": idMedicoParsed,
        "idCita": idCita,
        "fechaConsulta": _fechaConsultaController.text,
        "motivoConsulta": _motivoController.text,
        "sintomas": _sintomasController.text,
        "presionArterial": _presionArterialController.text,
        "frecuenciaCardiaca": _frecuenciaCardiacaController.text,
      };

      if (peso != null) {
        body["peso"] = peso;
      }
      if (altura != null) {
        body["altura"] = altura;
      }

      final response = await http.post(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/registros-consultas",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      setState(() {
        _guardando = false;
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Consulta guardada con xito")),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error: ${errorData['message'] ?? 'Error desconocido'}",
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _guardando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al guardar consulta: $e")));
    }
  }

  // Seleccionar fecha
  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2025),
    );

    if (fecha != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final fechaCompleta = DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          time.hour,
          time.minute,
        );
        setState(() {
          _fechaConsultaController.text = DateFormat(
            'yyyy-MM-dd HH:mm:ss',
          ).format(fechaCompleta);
        });
      }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/Fondo.png", fit: BoxFit.cover),
          ),
          Column(
            children: [
              Container(
                color: const Color(0xFF00BCD4),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.nombrePaciente.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.teal,
                  tabs: const [
                    Tab(text: "Datos"),
                    Tab(text: "Consulta"),
                    Tab(text: "Archivos"),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pestaa de Datos
                    const Center(child: Text("Informacin del paciente")),

                    // Pestaa de Consulta (antes Diagnstico)
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Registro de Consulta",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo de fecha de consulta
                          TextField(
                            controller: _fechaConsultaController,
                            decoration: InputDecoration(
                              labelText: "Fecha y Hora de Consulta",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _seleccionarFecha,
                              ),
                            ),
                            readOnly: true,
                          ),
                          const SizedBox(height: 20),

                          // Campo de motivo
                          TextField(
                            controller: _motivoController,
                            decoration: InputDecoration(
                              labelText: "Motivo de Consulta",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),

                          // Campo de sntomas
                          TextField(
                            controller: _sintomasController,
                            decoration: InputDecoration(
                              labelText: "Sntomas",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),

                          // Signos vitales
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _presionArterialController,
                                  decoration: InputDecoration(
                                    labelText: "Presin Arterial",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _frecuenciaCardiacaController,
                                  decoration: InputDecoration(
                                    labelText: "Frecuencia Cardaca",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Peso y altura
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _pesoController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: "Peso (kg)",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _alturaController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: "Altura (m)",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Botn de guardar
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _guardando ? null : _guardarConsulta,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6DCECB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _guardando
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Guardar Consulta",
                                      style: TextStyle(fontSize: 18),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pestaa de Archivos
                    ArchivosPage(
                      cita: widget.cita,
                      nombrePaciente: widget.nombrePaciente,
                      idRegistroConsulta: _idRegistroConsulta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
