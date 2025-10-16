import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:bless_health24/services/nlp_hc_service.dart';
import 'package:image_picker/image_picker.dart';

import 'archivos_local_helper.dart';

class InterpretacionUploadCard extends StatefulWidget {
  final int? idHistoriaClinica;
  final int? idPaciente;
  final VoidCallback? onSaved;
  final bool enviarANlp;

  const InterpretacionUploadCard({
    super.key,
    required this.idHistoriaClinica,
    this.idPaciente,
    this.onSaved,
    this.enviarANlp = true,
  });

  @override
  State<InterpretacionUploadCard> createState() =>
      _InterpretacionUploadCardState();
}

class _InterpretacionUploadCardState extends State<InterpretacionUploadCard> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _bytesSeleccionados;
  String? _nombreArchivo;
  String? _tipoArchivo;
  bool _guardando = false;

  bool get _puedeGuardar =>
      !_guardando &&
      _bytesSeleccionados != null &&
      widget.idHistoriaClinica != null;

  Future<void> _guardar() async {
    if (!_puedeGuardar) {
      _mostrarMensaje('Selecciona un archivo antes de guardar.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final archivoNombre =
          _nombreArchivo ?? 'archivo_${DateTime.now().millisecondsSinceEpoch}';
      final mime = _tipoArchivo ?? 'application/octet-stream';
      final bytes = _bytesSeleccionados!;

      await ArchivosLocalHelper.addBytes(
        idHistoriaClinica: widget.idHistoriaClinica,
        nombre: archivoNombre,
        mimeType: mime,
        bytes: bytes,
      );

      if (_debeEnviarAlServicioNlp) {
        await _enviarAlServicioNlp(bytes, archivoNombre);
      }

      setState(() {
        _bytesSeleccionados = null;
        _nombreArchivo = null;
        _tipoArchivo = null;
      });
      widget.onSaved?.call();
      if (!_debeEnviarAlServicioNlp) {
        final extraNlp = widget.enviarANlp && widget.idPaciente == null
            ? '\nAgrega el idPaciente para enviar el archivo al servicio NLP.'
            : '';
        _mostrarMensaje('Archivo guardado correctamente.$extraNlp');
      }
    } catch (e) {
      _mostrarMensaje('No se pudo guardar el archivo: $e');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  bool get _debeEnviarAlServicioNlp =>
      widget.enviarANlp &&
      widget.idHistoriaClinica != null &&
      widget.idPaciente != null;

  Future<void> _enviarAlServicioNlp(
    Uint8List bytes,
    String nombreArchivo,
  ) async {
    try {
      final result = await NlpHcService.processHistoriaClinica(
        idHistoriaClinica: widget.idHistoriaClinica!,
        idPaciente: widget.idPaciente!,
        fileBytes: bytes,
        fileName: nombreArchivo,
      );

      var mensaje = result.message;
      if (result.excelReady == true) {
        mensaje +=
            '\nEl Excel ha sido generado. Puedes descargarlo desde el panel de NLP.';
      }
      _mostrarMensaje(mensaje);
    } catch (e) {
      _mostrarMensaje(
        'Archivo guardado, pero el servicio NLP no está disponible: $e',
      );
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _tomarFoto() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      _actualizarSeleccion(
        bytes,
        xfile.name.isNotEmpty ? xfile.name : _nombreTemporal('jpg'),
      );
    } catch (e) {
      _mostrarMensaje('No se pudo tomar la foto: $e');
    }
  }

  Future<void> _seleccionarGaleria() async {
    try {
      final xfile = await _picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      _actualizarSeleccion(
        bytes,
        xfile.name.isNotEmpty ? xfile.name : _nombreTemporal('jpg'),
      );
    } catch (e) {
      _mostrarMensaje('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _seleccionarDocumento() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('El archivo seleccionado no contiene datos.');
      }
      _actualizarSeleccion(file.bytes!, file.name);
    } catch (e) {
      _mostrarMensaje('Error al seleccionar documento: $e');
    }
  }

  void _actualizarSeleccion(Uint8List bytes, String nombre) {
    setState(() {
      _bytesSeleccionados = bytes;
      _nombreArchivo = nombre;
      _tipoArchivo = ArchivosLocalHelper.guessMimeType(nombre);
    });
  }

  String _nombreTemporal(String extension) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'captura_$ts.$extension';
  }

  IconData _iconoPorTipo() {
    final tipo = (_tipoArchivo ?? '').toLowerCase();
    if (tipo.startsWith('image/')) return Icons.image_outlined;
    if (tipo.contains('pdf')) return Icons.picture_as_pdf;
    if (tipo.contains('word') || tipo.contains('msword')) {
      return Icons.description_outlined;
    }
    if (tipo.contains('excel')) return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final nombreMostrado = _nombreArchivo ?? 'Sin archivo seleccionado';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B0BD), Color(0xFF59CADA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    _iconoPorTipo(),
                    size: 32,
                    color: const Color(0xFF00B0BD),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nombreMostrado,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _puedeGuardar ? _guardar : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7DD1D8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            _buildOpcionCarga(
              icon: Icons.camera_alt_outlined,
              label: 'Subir foto',
              onTap: _tomarFoto,
            ),
            const SizedBox(height: 12),
            _buildOpcionCarga(
              icon: Icons.photo_library_outlined,
              label: 'Subir galeria',
              onTap: _seleccionarGaleria,
            ),
            const SizedBox(height: 12),
            _buildOpcionCarga(
              icon: Icons.description_outlined,
              label: 'Subir documento',
              onTap: _seleccionarDocumento,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcionCarga({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _guardando ? null : onTap,
        icon: Icon(icon, color: Colors.black87),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(label, style: const TextStyle(color: Colors.black87)),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black54, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
