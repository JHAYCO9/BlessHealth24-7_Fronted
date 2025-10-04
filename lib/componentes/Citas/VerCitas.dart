import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VerCitasScreen extends StatefulWidget {
  const VerCitasScreen({super.key});

  @override
  _VerCitasScreenState createState() => _VerCitasScreenState();
}

class _VerCitasScreenState extends State<VerCitasScreen> {
  List<dynamic> _citas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCitas();
  }

  Future<void> _fetchCitas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idPaciente = prefs.getInt("idPaciente");

      if (idPaciente == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se encontró el usuario en sesión")),
        );
        setState(() => _loading = false);
        return;
      }

      final response = await http.get(
        Uri.parse("https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/citas/paciente/$idPaciente"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _citas = data["data"];
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
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
          "Mis Citas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // 📌 Fondo
          Positioned.fill(
            child: Image.asset(
              "assets/images/Fondo.png",
              fit: BoxFit.cover,
            ),
          ),

          // 📌 Contenedor principal
          Column(
            children: [
              const SizedBox(height: 160),

              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -40),
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
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _citas.isEmpty
                        ? const Center(
                      child: Text(
                        "No tienes citas registradas",
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                        : ListView.builder(
                      itemCount: _citas.length,
                      itemBuilder: (context, index) {
                        final cita = _citas[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            title: Text(
                              cita["servicio"],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text("Médico: ${cita["nombreMedico"]}"),
                                Text("Especialidad: ${cita["especialidad"]}"),
                                Text("Sede: ${cita["sede"]}"),
                                Text("Motivo: ${cita["motivo"]}"),
                                Text(
                                  "Fecha: ${cita["fechaHora"].toString().substring(0, 10)} "
                                      "${cita["fechaHora"].toString().substring(11, 16)}",
                                ),
                                Text(
                                  "Estado: ${cita["estado"]}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cita["estado"] == "Pendiente"
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
