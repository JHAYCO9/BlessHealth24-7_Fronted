import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Cliente para consumir el servicio NLP de historias clínicas.
class NlpHcService {
  static const String _baseUrl =
      'https://nlp-hc-service.canadacentral.cloudapp.azure.com';
  static const String _processPath = '/api/nlp/process';
  static const String _downloadExcelPath = '/api/nlp/download-excel';
  static const String _excelStatusPath = '/api/nlp/excel-status';

  /// Envía la historia clínica al servicio NLP.
  static Future<NlpProcessResult> processHistoriaClinica({
    required int idHistoriaClinica,
    required int idPaciente,
    required Uint8List fileBytes,
    required String fileName,
    bool generarExcel = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$_processPath');
    final request = http.MultipartRequest('POST', uri)
      ..fields['idHistoriaClinica'] = idHistoriaClinica.toString()
      ..fields['idPaciente'] = idPaciente.toString()
      ..fields['generar_excel'] = generarExcel.toString()
      ..files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final success = response.statusCode >= 200 && response.statusCode < 300;
    Map<String, dynamic>? body;
    String? message;
    bool excelReady = false;
    String? excelUrl;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
        final data = decoded;
        message =
            data['mensaje']?.toString() ??
            data['message']?.toString() ??
            data['detail']?.toString();
        final excel =
            data['excel'] ?? data['excel_generado'] ?? data['excelUrl'];
        if (excel is bool) {
          excelReady = excel;
        } else if (excel is String && excel.isNotEmpty) {
          excelReady = true;
          excelUrl = excel;
        }
        final posibleUrl = data['excel_url'] ?? data['excelUrl'];
        if (posibleUrl is String && posibleUrl.isNotEmpty) {
          excelUrl = posibleUrl;
          excelReady = true;
        }
      }
    } catch (_) {
      // Si no es JSON ignoramos y usamos el body crudo como mensaje.
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }

    message ??= success
        ? 'Historia clínica procesada correctamente.'
        : 'No se pudo procesar la historia clínica (código ${response.statusCode}).';

    return NlpProcessResult(
      success: success,
      statusCode: response.statusCode,
      message: message,
      excelReady: excelReady,
      excelUrl: excelUrl,
      data: body,
    );
  }

  /// Consulta si hay un Excel generado disponible en el servicio.
  static Future<NlpExcelStatus> checkExcelStatus() async {
    final uri = Uri.parse('$_baseUrl$_excelStatusPath');
    final response = await http.get(uri);

    bool available = response.statusCode == 200;
    String? message;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message =
            decoded['mensaje']?.toString() ??
            decoded['message']?.toString() ??
            decoded['detail']?.toString();
        final flag = decoded['excelDisponible'] ?? decoded['available'];
        if (flag is bool) {
          available = flag;
        }
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }

    return NlpExcelStatus(
      available: available,
      statusCode: response.statusCode,
      message: message,
    );
  }

  /// Descarga el Excel generado.
  static Future<Uint8List> downloadExcel() async {
    final uri = Uri.parse('$_baseUrl$_downloadExcelPath');
    final response = await http.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw Exception(
      'No se pudo descargar el Excel (código ${response.statusCode}).',
    );
  }
}

class NlpProcessResult {
  final bool success;
  final int statusCode;
  final String message;
  final bool excelReady;
  final String? excelUrl;
  final Map<String, dynamic>? data;

  NlpProcessResult({
    required this.success,
    required this.statusCode,
    required this.message,
    required this.excelReady,
    required this.excelUrl,
    required this.data,
  });
}

class NlpExcelStatus {
  final bool available;
  final int statusCode;
  final String? message;

  NlpExcelStatus({
    required this.available,
    required this.statusCode,
    required this.message,
  });
}
