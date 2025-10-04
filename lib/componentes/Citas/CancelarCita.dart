import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class CancelarCitaPage extends StatefulWidget {
  const CancelarCitaPage({super.key});

  @override
  _CancelarCitaPageState createState() => _CancelarCitaPageState();
}

class _CancelarCitaPageState extends State<CancelarCitaPage> {
  List<dynamic> citas = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCitas();
  }

  Future<void> fetchCitas() async {
    final prefs = await SharedPreferences.getInstance();
    final idPaciente = prefs.getInt("idPaciente");

    if (idPaciente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró el usuario en sesión")),
      );
      setState(() => isLoading = false);
      return;
    }

    final response = await http.get(Uri.parse(
      "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/citas/paciente/$idPaciente",
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        citas = data["data"]
            .where((cita) => cita["estado"] == "Pendiente")
            .toList();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> cancelarCita(int idCita, String motivo) async {
    final url = Uri.parse(
        "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/citas/$idCita/cancelar");

    final response = await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({"motivoCancelacion": motivo}),
    );

    if (response.statusCode == 200) {
      fetchCitas(); // refrescar citas
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cita cancelada correctamente")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al cancelar la cita"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void mostrarDialogoMotivo(int idCita, String fechaHora) {
    final motivoController = TextEditingController();

    // ✅ Verificar 24 horas antes de mostrar el diálogo
    final fechaCita = DateTime.parse(fechaHora);
    final ahora = DateTime.now();
    final diferencia = fechaCita.difference(ahora);

    if (diferencia.inHours < 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se puede cancelar una cita con menos de 24 horas de anticipación"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Motivo de cancelación"),
        content: TextField(
          controller: motivoController,
          decoration: const InputDecoration(
            hintText: "Escribe el motivo",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cerrar"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Confirmar"),
            onPressed: () {
              final motivo = motivoController.text.trim();
              if (motivo.isNotEmpty) {
                Navigator.pop(context);
                cancelarCita(idCita, motivo);
              }
            },
          ),
        ],
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
          "Cancelar Cita",
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
              const SizedBox(height: 150),
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
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : citas.isEmpty
                        ? const Center(child: Text("No tienes citas pendientes"))
                        : ListView.builder(
                      itemCount: citas.length,
                      itemBuilder: (context, index) {
                        final cita = citas[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Médico: ${cita["nombreMedico"]}",
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("Especialidad: ${cita["especialidad"]}"),
                                Text("Servicio: ${cita["servicio"]}"),
                                Text("Fecha: ${cita["fechaHora"]}"),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => mostrarDialogoMotivo(
                                      cita["idCita"], cita["fechaHora"]),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF01A4B2),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text("Cancelar"),
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
