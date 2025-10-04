import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> loadDoctorFullName() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final nombre =
        prefs.getString('nombreDoctor') ??
        prefs.getString('nombreMedico') ??
        prefs.getString('nombreUsuario') ??
        '';
    final apellido =
        prefs.getString('apellidoDoctor') ??
        prefs.getString('apellidoMedico') ??
        prefs.getString('apellidoUsuario') ??
        '';
    final completo = '$nombre $apellido'.trim();
    return completo.isEmpty ? 'Doctor' : completo;
  } catch (_) {
    return 'Doctor';
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return int.tryParse(trimmed);
    }
  }
  return null;
}

String? extractDocumentoPaciente(Map<String, dynamic> source) {
  const posibles = [
    'numeroDocumentoPaciente',
    'numeroDocumento',
    'documentoPaciente',
    'documento',
    'cedulaPaciente',
    'cedula',
    'identificacion',
  ];
  for (final key in posibles) {
    if (!source.containsKey(key)) continue;
    final value = source[key];
    if (value == null) continue;
    final texto = value.toString().trim();
    if (texto.isNotEmpty) {
      return texto;
    }
  }
  final paciente = source['paciente'];
  if (paciente is Map<String, dynamic>) {
    final nested = extractDocumentoPaciente(paciente);
    if (nested != null && nested.isNotEmpty) {
      return nested;
    }
  }
  return null;
}

int? extractIdPaciente(Map<String, dynamic> source) {
  const posibles = ['idPaciente', 'pacienteId', 'idUsuario', 'id'];
  for (final key in posibles) {
    if (!source.containsKey(key)) continue;
    final id = _parseInt(source[key]);
    if (id != null) {
      return id;
    }
  }
  final paciente = source['paciente'];
  if (paciente is Map<String, dynamic>) {
    final nested = extractIdPaciente(Map<String, dynamic>.from(paciente));
    if (nested != null) {
      return nested;
    }
  }
  return null;
}

ButtonStyle buildDoctorQuickActionStyle() {
  return ElevatedButton.styleFrom(
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ).copyWith(
    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
      (states) => states.contains(MaterialState.disabled)
          ? Colors.grey.shade300
          : const Color(0xFF00BCD4),
    ),
    foregroundColor: MaterialStateProperty.resolveWith<Color?>(
      (states) => states.contains(MaterialState.disabled)
          ? Colors.grey.shade600
          : Colors.white,
    ),
  );
}
