import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Doctor/AgendaDoctor.dart';

class CustomNavbar extends StatelessWidget {
  const CustomNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFE6F9FA),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.person, color: Colors.teal, size: 30),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final idMedico = prefs.getString('idMedico');
                  final cedula = prefs.getString('cedulaMedico');
                  final hasDoctor =
                      (idMedico != null && idMedico.isNotEmpty) &&
                      (cedula != null && cedula.isNotEmpty);
                  // Si ya hay sesión de médico, ir directo a Agenda
                  // Si no, pedir login de médico
                  // ignore: use_build_context_synchronously
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => hasDoctor
                          ? AgendaDoctorPage()
                          : const Placeholder(color: Colors.red),
                    ),
                  );
                },
              ),

              Row(
                children: [
                  Image.asset('assets/images/Logo2.png', height: 40),
                  const SizedBox(width: 8),
                  const Text(
                    "BlessHealth24",
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              // Ícono de carrito
              IconButton(
                icon: const Icon(
                  Icons.shopping_cart,
                  color: Colors.teal,
                  size: 28,
                ),
                onPressed: () {
                  // Acción al presionar
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
