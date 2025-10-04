import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:bless_health24/componentes/shared/app_logo_badge.dart';
import 'DiagnosticoPaciente.dart';
import 'HistoriaClinica.dart';
import 'Medicina.dart';
import 'Paciente.dart';
import 'Remitir.dart';
import 'doctor_action_bar.dart';
import 'doctor_helpers.dart';
import 'Archivos.dart';

class AtenderPacientePage extends StatefulWidget {
  final Map<String, dynamic> cita;
  final String nombrePaciente;

  const AtenderPacientePage({
    super.key,
    required this.cita,
    required this.nombrePaciente,
  });

  @override
  State<AtenderPacientePage> createState() => _AtenderPacientePageState();
}

class _AtenderPacientePageState extends State<AtenderPacientePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _tratamientoController = TextEditingController();
  final TextEditingController _observacionesController =
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
  DateTime _fechaConsulta = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _fechaController.text = DateFormat('dd/MM/yy').format(_fechaConsulta);
    _cargarHistoriaClinica();
    _cargarDiagnostico();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fechaController.dispose();
    _tratamientoController.dispose();
    _observacionesController.dispose();
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
        final data = jsonDecode(response.body);
        if (data["data"] != null && data["data"].isNotEmpty) {
          setState(() {
            _idHistoriaClinica = data["data"][0]['idHistoriaClinica'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar historia clnica: $e")),
      );
    }
  }

  // Cargar diagnstico existente si hay
  Future<void> _cargarDiagnostico() async {
    try {
      final idCita = widget.cita['idCita'];

      final response = await http.get(
        Uri.parse(
          "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/registros-consultas/cita/$idCita",
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["data"] != null && data["data"].isNotEmpty) {
          final registro = data["data"][0];
          setState(() {
            _idRegistroConsulta = registro['idRegistroConsulta'];
            _tratamientoController.text = registro['tratamiento'] ?? '';
            _observacionesController.text = registro['observaciones'] ?? '';
            _motivoController.text = registro['motivoConsulta'] ?? '';
            _sintomasController.text = registro['sintomas'] ?? '';
            _presionArterialController.text = registro['presionArterial'] ?? '';
            _frecuenciaCardiacaController.text =
                registro['frecuenciaCardiaca'] ?? '';
            _pesoController.text = registro['peso'] != null
                ? '${registro['peso']}'
                : '';
            _alturaController.text = registro['altura'] != null
                ? '${registro['altura']}'
                : '';
            if (registro['fechaConsulta'] != null) {
              try {
                _fechaConsulta = DateFormat(
                  'yyyy-MM-dd HH:mm:ss',
                ).parse(registro['fechaConsulta']);
                _fechaController.text = DateFormat(
                  'dd/MM/yy',
                ).format(_fechaConsulta);
              } catch (_) {}
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cargar diagnstico: $e")));
    }
  }

  // Guardar diagnstico
  Future<void> _guardarDiagnostico() async {
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
        "fechaConsulta": DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(_fechaConsulta),
        "motivoConsulta": _motivoController.text,
        "sintomas": _sintomasController.text,
        "presionArterial": _presionArterialController.text,
        "frecuenciaCardiaca": _frecuenciaCardiacaController.text,
        "tratamiento": _tratamientoController.text,
        "observaciones": _observacionesController.text,
      };

      if (peso != null) {
        body["peso"] = peso;
      }
      if (altura != null) {
        body["altura"] = altura;
      }

      final Uri uri = Uri.parse(
        "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/registros-consultas",
      );

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      setState(() {
        _guardando = false;
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Diagnstico guardado con xito")),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar diagnstico: $e")),
      );
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
      setState(() {
        _fechaConsulta = DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          _fechaConsulta.hour,
          _fechaConsulta.minute,
          _fechaConsulta.second,
        );
        _fechaController.text = DateFormat('dd/MM/yy').format(_fechaConsulta);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentoPaciente = extractDocumentoPaciente(widget.cita) ?? '';
    final int? idPaciente = extractIdPaciente(widget.cita);
    final quickActions = _buildQuickActionItems(
      documentoPaciente: documentoPaciente,
      idPaciente: idPaciente,
      idRegistroConsulta: _idRegistroConsulta,
    );

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
              const SizedBox(height: 16),
              const Center(child: AppLogoBadge()),
              const SizedBox(height: 16),
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
              if (quickActions.isNotEmpty)
                DoctorActionBar(actions: quickActions),
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
                    Tab(text: "Diagnstico"),
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

                    // Pestaa de Diagnstico
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Diagnstico",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo de fecha
                          TextField(
                            controller: _fechaController,
                            decoration: InputDecoration(
                              labelText: "DD/MM/AA",
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

                          // Campo motivo consulta
                          TextField(
                            controller: _motivoController,
                            decoration: InputDecoration(
                              labelText: "Motivo de la consulta",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),

                          // Campo sntomas
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

                          // Campo presin arterial
                          TextField(
                            controller: _presionArterialController,
                            decoration: InputDecoration(
                              labelText: "Presin arterial",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo frecuencia cardiaca
                          TextField(
                            controller: _frecuenciaCardiacaController,
                            decoration: InputDecoration(
                              labelText: "Frecuencia cardiaca",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo peso
                          TextField(
                            controller: _pesoController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: "Peso (kg)",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo altura
                          TextField(
                            controller: _alturaController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: "Altura (m)",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo tratamiento
                          TextField(
                            controller: _tratamientoController,
                            decoration: InputDecoration(
                              labelText: "Tratamiento",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 20),

                          // Campo observaciones
                          TextField(
                            controller: _observacionesController,
                            decoration: InputDecoration(
                              labelText: "Observaciones",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 6,
                          ),
                          const SizedBox(height: 30),

                          // Botn de guardar
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _guardando
                                  ? null
                                  : _guardarDiagnostico,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7FDCDC),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: _guardando
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _abrirPacienteDetalle(String documento) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => Paciente(documentoId: documento)));
  }

  void _abrirHistoriaClinica(String documento) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HistoriaClinicaPage(initialDocumento: documento, autoSearch: true),
      ),
    );
  }

  void _abrirArchivosDesdeCita() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchivosPage(
          cita: widget.cita,
          nombrePaciente: widget.nombrePaciente,
          idRegistroConsulta: _idRegistroConsulta,
        ),
      ),
    );
  }

  void _abrirDiagnosticoPaciente() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosticoPacientePage(
          cita: widget.cita,
          nombrePaciente: widget.nombrePaciente,
        ),
      ),
    );
  }

  Future<void> _abrirMedicina(int idHistoriaClinica) async {
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

  void _abrirRemitirPaciente({
    required int idPaciente,
    required int? idRegistroConsulta,
    String? documento,
  }) {
    if (idRegistroConsulta == null) {
      _showSnack('Registra una consulta antes de remitir al paciente.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemitirPage(
          idPaciente: idPaciente,
          idRegistroConsulta: idRegistroConsulta,
          nombrePaciente: widget.nombrePaciente,
          documentoPaciente: documento,
          idHistoriaClinica: _idHistoriaClinica,
        ),
      ),
    );
  }

  List<DoctorAction> _buildQuickActionItems({
    required String? documentoPaciente,
    required int? idPaciente,
    required int? idRegistroConsulta,
  }) {
    final actions = <DoctorAction>[];
    final documento = documentoPaciente?.trim();
    final idHistoria = _idHistoriaClinica;

    if (documento != null && documento.isNotEmpty) {
      actions.add(
        DoctorAction(
          icon: Icons.person_outline,
          label: 'Paciente',
          onPressed: () => _abrirPacienteDetalle(documento),
        ),
      );
      actions.add(
        DoctorAction(
          icon: Icons.history_edu_outlined,
          label: 'Historia',
          onPressed: () => _abrirHistoriaClinica(documento),
        ),
      );
    }

    actions.add(
      DoctorAction(
        icon: Icons.folder_open,
        label: 'Archivos',
        onPressed: _abrirArchivosDesdeCita,
      ),
    );

    actions.add(
      DoctorAction(
        icon: Icons.receipt_long_outlined,
        label: 'Diagnóstico',
        onPressed: _abrirDiagnosticoPaciente,
      ),
    );

    if (idPaciente != null) {
      actions.add(
        DoctorAction(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Remitir',
          onPressed: () => _abrirRemitirPaciente(
            idPaciente: idPaciente,
            idRegistroConsulta: idRegistroConsulta,
            documento: documento,
          ),
        ),
      );
    }

    if (idHistoria != null) {
      actions.add(
        DoctorAction(
          icon: Icons.healing_outlined,
          label: 'Medicina',
          onPressed: () => _abrirMedicina(idHistoria),
        ),
      );
    }

    return actions;
  }
}
