import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _tipoDocController = TextEditingController(text: "1");
  final TextEditingController _numDocController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _fechaNacController = TextEditingController();
  final TextEditingController _generoController = TextEditingController(text: "F");
  final TextEditingController _rolController = TextEditingController(text: "1");
  final TextEditingController _sedeController = TextEditingController(text: "1");

  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = Uri.parse(
        "https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/auth/register");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "tipoDocumento": int.parse(_tipoDocController.text),
          "numeroDocumento": _numDocController.text.trim(),
          "nombreUsuario": _nombreController.text.trim(),
          "apellidoUsuario": _apellidoController.text.trim(),
          "emailUsuario": _emailController.text.trim(),
          "pwdUsuario": _pwdController.text.trim(),
          "telefonoUsuario": _telefonoController.text.trim(),
          "direccionUsuario": _direccionController.text.trim(),
          "fechaNacimiento": _fechaNacController.text.trim(), // formato yyyy-MM-dd
          "genero": _generoController.text.trim(),
          "idRol": int.parse(_rolController.text),
          "idSede": int.parse(_sedeController.text),
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Registro exitoso. Ahora inicia sesión")),
          );
          Navigator.pop(context); // vuelve al Login
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ Error: ${data["message"] ?? response.body}")),
          );
        }
      } else {
        // 📌 Aquí mostramos el error detallado del backend
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error ${response.statusCode}: ${response.body}")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Excepción: $e")),
      );
    }
  }


  Widget _botonRegistro(String texto) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _register,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF01A4B2),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
        texto,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/Fondo.png", fit: BoxFit.cover),
          ),
          Center(
            child: SingleChildScrollView(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Registro de Usuario",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _numDocController,
                        decoration: const InputDecoration(
                          labelText: "Número Documento",
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: "Nombre",
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _apellidoController,
                        decoration: const InputDecoration(
                          labelText: "Apellido",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Correo electrónico",
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _pwdController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _telefonoController,
                        decoration: const InputDecoration(
                          labelText: "Teléfono",
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _direccionController,
                        decoration: const InputDecoration(
                          labelText: "Dirección",
                          prefixIcon: Icon(Icons.home),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _fechaNacController,
                        decoration: const InputDecoration(
                          labelText: "Fecha de Nacimiento (YYYY-MM-DD)",
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _botonRegistro("Registrarse"),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Volver a Login",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
