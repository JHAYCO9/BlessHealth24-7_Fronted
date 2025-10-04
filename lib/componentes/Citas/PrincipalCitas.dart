import 'package:flutter/material.dart';
import '../Citas/AgendarCita.dart';
import '../Citas/CancelarCita.dart';
import '../Citas/VerCitas.dart';

class MenuCitasPage extends StatelessWidget {
  const MenuCitasPage({super.key});

  Widget _botonMenu(BuildContext context, String texto, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF01A4B2), // 👈 Color personalizado
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          "Gestión de Citas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // 📌 Fondo con imagen completa
          Positioned.fill(
            child: Image.asset(
              "assets/images/Fondo.png",
              fit: BoxFit.cover,
            ),
          ),

          // 📌 Contenido encima
          Column(
            children: [
              const SizedBox(height: 180), // deja espacio arriba para la cabecera

              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -50),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // 👇 Botón para agendar cita
                        _botonMenu(context, "Agendar Cita Médica", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AgendarCitaPage(),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),

                        _botonMenu(context, "Cancelar Cita", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CancelarCitaPage(), // ✅ sin const
                            ),
                          );
                        }),

                        const SizedBox(height: 20),

                        // 👇 Botón para ver citas
                        _botonMenu(context, "Ver Citas", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VerCitasScreen(), // ✅ así navega bien
                            ),
                          );
                        }),
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
