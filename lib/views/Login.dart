import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../componentes/buttons/Button1.dart';
import 'Registro.dart';
import 'PrincipalPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;

  Future<void> _login() async {
    setState(() {
      loading = true;
    });

    try {
      // ? URL de la API en Render
      final uri = Uri.parse(
        'https://blesshealth24-7-backecommerce.onrender.com/auth/iniciar-sesion',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "correoUsuario": emailController.text.trim(),
          "contrasenaUsuario": passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("? Login exitoso: $data");

        final prefs = await SharedPreferences.getInstance();

        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await prefs.setString('authToken', token);
        } else {
          await prefs.remove('authToken');
        }

        final usuario = data['usuario'];
        if (usuario is Map<String, dynamic>) {
          final userId = (usuario['id'] as num?)?.toInt();
          if (userId != null && userId > 0) {
            await prefs.setInt('usuarioId', userId);
          } else {
            await prefs.remove('usuarioId');
          }

          await prefs.setString(
            'usuarioNombre',
            usuario['nombre']?.toString() ?? '',
          );
          await prefs.setString(
            'usuarioApellido',
            usuario['apellido']?.toString() ?? '',
          );
          await prefs.setString(
            'usuarioCorreo',
            usuario['email']?.toString() ?? '',
          );

          final rolId = (usuario['rolId'] as num?)?.toInt();
          if (rolId != null) {
            await prefs.setInt('usuarioRolId', rolId);
          } else {
            await prefs.remove('usuarioRolId');
          }
        } else {
          await prefs.remove('usuarioId');
          await prefs.remove('usuarioNombre');
          await prefs.remove('usuarioApellido');
          await prefs.remove('usuarioCorreo');
          await prefs.remove('usuarioRolId');
        }

        await prefs.setBool('usuarioSesionActiva', data['active'] == true);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        print("? Error: ${response.statusCode}");
        print("Respuesta: ${response.body}");
        if (mounted) {
          final mensajeError = response.body.isNotEmpty
              ? response.body
              : 'Error: ${response.statusCode}';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mensajeError)));
        }
      }
    } catch (e) {
      print("?? Error de conexión: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error de conexión con el servidor")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Sección superior con imagen de fondo
          Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              image: DecorationImage(
                image: AssetImage('assets/images/Fondo.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
            child: Column(
              children: [
                const Spacer(flex: 1),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/Logo1.png', width: 120),
                      const SizedBox(height: 40),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: "Correo Electrónico",
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Contraseña",
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00A6B2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: loading ? null : _login,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            "Iniciar Sesión",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CustomButton(
                  text: "REGISTRARSE",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegistroPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
