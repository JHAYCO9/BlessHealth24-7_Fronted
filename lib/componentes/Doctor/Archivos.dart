import "dart:convert";
import "package:flutter/material.dart";
import "package:bless_health24/componentes/shared/app_logo_badge.dart";
import "package:http/http.dart" as http;
import "archivos_local_helper.dart";
import "InterpretacionUploadCard.dart";

class ArchivosPage extends StatefulWidget {
  final Map<String, dynamic> cita;
  final String nombrePaciente;
  final int? idRegistroConsulta;

  const ArchivosPage({
    super.key,
    required this.cita,
    required this.nombrePaciente,
    this.idRegistroConsulta,
  });

  @override
  State<ArchivosPage> createState() => _ArchivosPageState();
}

class _ArchivosPageState extends State<ArchivosPage> {
  List<Map<String, dynamic>> _archivos = [];
  bool _cargando = true;
  int? _idHistoriaClinica;
  int? _idPaciente;

  @override
  void initState() {
    super.initState();
    _cargarHistoriaClinica();
  }

  Future<void> _cargarHistoriaClinica() async {
    final rawIdPaciente = widget.cita['idPaciente'];
    final idPaciente = rawIdPaciente is int
        ? rawIdPaciente
        : int.tryParse('$rawIdPaciente');
    _idPaciente = idPaciente;

    if (idPaciente == null) {
      setState(() {
        _cargando = false;
      });
      _showSnack('No se encontro historia clinica del paciente');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://blesshealth24-7-backprocesosmedicos-1.onrender.com/api/historias-clinicas/paciente/$idPaciente',
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final lista = decoded is List
            ? decoded
            : (decoded is Map && decoded['data'] is List)
            ? decoded['data']
            : [];

        if (lista.isNotEmpty) {
          final primero = Map<String, dynamic>.from(lista.first as Map);
          final dynamic idHistoriaRaw = primero['idHistoriaClinica'];
          final idHistoria = idHistoriaRaw is int
              ? idHistoriaRaw
              : int.tryParse('$idHistoriaRaw');

          setState(() {
            _idHistoriaClinica = idHistoria;
          });

          await _cargarArchivos();
        } else {
          setState(() {
            _cargando = false;
          });
        }
      } else {
        setState(() {
          _cargando = false;
        });
        _showSnack('No se encontro historia clinica del paciente');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
      });
      _showSnack('Error al cargar historia clinica: $e');
    }
  }

  Future<void> _cargarArchivos() async {
    final locales = await ArchivosLocalHelper.load(_idHistoriaClinica);
    if (!mounted) return;
    setState(() {
      _archivos = locales;
      _cargando = false;
    });
  }

  Future<void> _eliminarArchivoLocal(Map<String, dynamic> archivo) async {
    if (_idHistoriaClinica == null) return;
    await ArchivosLocalHelper.delete(_idHistoriaClinica, archivo);
    await _cargarArchivos();
    _showSnack('Archivo eliminado');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _esImagen(Map<String, dynamic> archivo) {
    final tipo = (archivo['tipoArchivo'] ?? '').toString();
    return tipo.startsWith('image/');
  }

  void _visualizarArchivo(Map<String, dynamic> archivo) {
    final nombre = archivo['nombreArchivo'] ?? archivo['nombre'] ?? 'Archivo';
    final b64 = archivo['base64Data'];
    final tipo = (archivo['tipoArchivo'] ?? '').toString();

    if (b64 is String && tipo.startsWith('image/')) {
      try {
        final bytes = base64Decode(b64);
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        );
        return;
      } catch (_) {}
    }

    if (b64 is String && tipo.contains('text')) {
      try {
        final bytes = base64Decode(b64);
        final contenido = utf8.decode(bytes);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(nombre),
            content: SingleChildScrollView(child: SelectableText(contenido)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
        return;
      } catch (_) {}
    }

    _showSnack('Archivo: ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/Fondo.png', fit: BoxFit.cover),
          ),
          Column(
            children: [
              const SizedBox(height: 16),
              const Center(child: AppLogoBadge()),
              const SizedBox(height: 16),
              Container(
                color: const Color(0xFF00BCD4),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.nombrePaciente.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            if (_idHistoriaClinica != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                child: InterpretacionUploadCard(
                                  idHistoriaClinica: _idHistoriaClinica,
                                  idPaciente: _idPaciente,
                                  onSaved: _cargarArchivos,
                                ),
                              ),
                            const SizedBox(height: 16),
                            Expanded(child: _buildListadoArchivos()),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListadoArchivos() {
    if (_archivos.isEmpty) {
      return const Center(
        child: Text(
          'No hay archivos disponibles',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _archivos.length,
      itemBuilder: (context, index) {
        final archivo = _archivos[index];
        final nombreArchivo =
            archivo['nombreArchivo'] ??
            archivo['nombre'] ??
            'Archivo sin nombre';
        final tipoArchivo =
            archivo['tipoArchivo'] ?? archivo['tipo'] ?? 'desconocido';
        final fechaArchivo =
            archivo['fechaCreacion'] ?? archivo['fecha'] ?? 'Fecha desconocida';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              tipoArchivo.contains('pdf')
                  ? Icons.picture_as_pdf
                  : _esImagen(archivo)
                  ? Icons.image
                  : Icons.insert_drive_file,
              color: tipoArchivo.contains('pdf')
                  ? Colors.red
                  : _esImagen(archivo)
                  ? Colors.blue
                  : Colors.grey,
            ),
            title: Text(nombreArchivo),
            subtitle: Text(fechaArchivo),
            onTap: () => _visualizarArchivo(archivo),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () => _eliminarArchivoLocal(archivo),
            ),
          ),
        );
      },
    );
  }
}
