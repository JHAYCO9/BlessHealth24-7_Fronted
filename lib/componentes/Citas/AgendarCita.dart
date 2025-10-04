import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AgendarCitaPage extends StatefulWidget {
  const AgendarCitaPage({super.key});

  @override
  State<AgendarCitaPage> createState() => _AgendarCitaPageState();
}

class _AgendarCitaPageState extends State<AgendarCitaPage> {
  List<dynamic> _sedes = [];
  String? _sedeSeleccionada;

  List<dynamic> _servicios = [];
  String? _servicioSeleccionado;

  List<dynamic> _medicos = [];

  bool _cargando = true;
  bool _cargandoMedicos = false;

  @override
  void initState() {
    super.initState();
    _cargarSedes();
    _cargarServicios();
  }

  // 📌 Cargar sedes
  Future<void> _cargarSedes() async {
    try {
      final response = await http.get(
        Uri.parse("https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/sedes"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _sedes = List<Map<String, dynamic>>.from(data["data"]);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar sedes: $e")),
      );
    }
  }

  // 📌 Cargar servicios
  Future<void> _cargarServicios() async {
    try {
      final response = await http.get(
        Uri.parse("https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/servicios/"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _servicios = List<Map<String, dynamic>>.from(data["data"]);
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _cargando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar servicios: $e")),
      );
    }
  }

  // 📌 Cargar médicos
  Future<void> _cargarMedicos(int idEspecialidad) async {
    setState(() {
      _cargandoMedicos = true;
      _medicos = [];
    });

    try {
      final response = await http.get(
        Uri.parse(
            "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/medicos/especialidad/$idEspecialidad"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _medicos = List<Map<String, dynamic>>.from(data["data"])
              .where((medico) => medico["nombreSede"] == _sedeSeleccionada)
              .toList();
          _cargandoMedicos = false;
        });
      }
    } catch (e) {
      setState(() {
        _cargandoMedicos = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar médicos: $e")),
      );
    }
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // 📌 Tarjeta del médico
  Widget _medicoCard(dynamic medico) {
    final Map<String, dynamic> data = medico as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.blue),
        title: Text("${data['nombreUsuario']} ${data['apellidoUsuario']}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Especialidad: ${data['nombreEspecialidad']}"),
            Text("Sede: ${data['nombreSede']}"),
            Text("Tel: ${data['telefonoUsuario']}"),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          final idMedico = data["idMedico"];
          final idServicio = _servicios
              .firstWhere((s) => s["nombreServicio"] == _servicioSeleccionado)["idServicio"];
          final idSede = _sedes
              .firstWhere((s) => s["nombreSede"] == _sedeSeleccionada)["idSede"];

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AgendarCitaFormPage(
                idMedico: idMedico,
                idServicio: idServicio,
                idSede: idSede,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Agendar Cita",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/Fondo.png",
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 160),
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
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _dropdownField(
                          label: "Selecciona la ciudad:",
                          value: _sedeSeleccionada,
                          items: _sedes
                              .map<DropdownMenuItem<String>>((sede) {
                            return DropdownMenuItem<String>(
                              value: sede["nombreSede"],
                              child: Text(sede["ciudadSede"]),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            setState(() {
                              _sedeSeleccionada = valor;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        _dropdownField(
                          label: "Selecciona un servicio:",
                          value: _servicioSeleccionado,
                          items: _servicios
                              .map<DropdownMenuItem<String>>((servicio) {
                            return DropdownMenuItem<String>(
                              value: servicio["nombreServicio"],
                              child: Text(servicio["nombreServicio"]),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            setState(() {
                              _servicioSeleccionado = valor;
                            });

                            final servicio = _servicios.firstWhere(
                                    (s) => s["nombreServicio"] == valor);
                            final idEspecialidad = servicio["idServicio"];
                            _cargarMedicos(idEspecialidad);
                          },
                        ),
                        const SizedBox(height: 30),

                        if (_cargandoMedicos)
                          const Center(child: CircularProgressIndicator())
                        else if (_medicos.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Médicos disponibles:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._medicos.map(_medicoCard),
                            ],
                          )
                        else if (_sedeSeleccionada != null &&
                              _servicioSeleccionado != null)
                            const Text(
                              "No hay médicos disponibles en esta sede.",
                              style: TextStyle(color: Colors.red),
                            ),
                      ],
                    ),
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

class AgendarCitaFormPage extends StatefulWidget {
  final int idMedico;
  final int idServicio;
  final int idSede;

  const AgendarCitaFormPage({
    super.key,
    required this.idMedico,
    required this.idServicio,
    required this.idSede,
  });

  @override
  State<AgendarCitaFormPage> createState() => _AgendarCitaFormPageState();
}

class _AgendarCitaFormPageState extends State<AgendarCitaFormPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _fechaHora;
  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _sintomasController = TextEditingController();

  bool _enviando = false;

  Future<void> _agendarCita() async {
    if (!_formKey.currentState!.validate() || _fechaHora == null) return;

    setState(() {
      _enviando = true;
    });

    // 📌 Recuperamos idPaciente desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final idPaciente = prefs.getInt("idPaciente") ?? 43; // fallback en caso de error

    final body = {
      "idPaciente": idPaciente,
      "idServicio": widget.idServicio,
      "idSede": widget.idSede,
      "fechaHora": _fechaHora!
          .toIso8601String()
          .replaceFirst("T", " ")
          .substring(0, 19),
      "motivo": _motivoController.text,
      "sintomas": _sintomasController.text,
      "idMedico": widget.idMedico,
    };

    try {
      final response = await http.post(
        Uri.parse("https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/citas"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cita agendada con éxito ✅")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al agendar cita: $e")),
      );
    } finally {
      setState(() {
        _enviando = false;
      });
    }
  }

  Future<void> _seleccionarFechaHora() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      final hora = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );

      if (hora != null) {
        setState(() {
          _fechaHora = DateTime(
            fecha.year,
            fecha.month,
            fecha.day,
            hora.hour,
            hora.minute,
          );
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
          "Completar datos de la cita",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/Fondo.png",
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 160),
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
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _seleccionarFechaHora,
                            child: Text(_fechaHora == null
                                ? "Seleccionar fecha y hora"
                                : "Fecha: ${_fechaHora.toString()}"),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _motivoController,
                            decoration:
                            const InputDecoration(labelText: "Motivo"),
                            validator: (value) =>
                            value!.isEmpty ? "Ingresa el motivo" : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _sintomasController,
                            decoration:
                            const InputDecoration(labelText: "Síntomas"),
                            validator: (value) =>
                            value!.isEmpty ? "Ingresa los síntomas" : null,
                          ),
                          const SizedBox(height: 30),
                          _enviando
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                            onPressed: _agendarCita,
                            child: const Text("Agendar Cita"),
                          ),
                        ],
                      ),
                    ),
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
