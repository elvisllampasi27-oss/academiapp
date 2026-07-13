import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app_movil/widgets/texto_latex.dart';

/// Rinde un examen completo (pasado o tipo admisión). Las preguntas se
/// piden vía Cloud Function (obtenerExamen) — ahí es donde el backend
/// aplica el límite diario de Free y el candado de admisión-solo-Premium.
class ExamenSesionPage extends StatefulWidget {
  final String examenId;
  final String tituloPreview;

  const ExamenSesionPage({
    super.key,
    required this.examenId,
    required this.tituloPreview,
  });

  @override
  State<ExamenSesionPage> createState() => _ExamenSesionPageState();
}

class _ExamenSesionPageState extends State<ExamenSesionPage> {
  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _examen;
  List<Map<String, dynamic>> _preguntas = [];
  final Map<int, int> _respuestas = {}; // índice pregunta -> índice opción
  int _indice = 0;
  bool _enviando = false;
  bool _finalizado = false;
  int? _aciertos;

  Timer? _timer;
  int _segundosRestantes = 0;

  @override
  void initState() {
    super.initState();
    _cargarExamen();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarExamen() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('obtenerExamen')
          .call({'examenId': widget.examenId});
      final data = Map<String, dynamic>.from(result.data['examen'] as Map);
      final preguntas = (data['preguntas'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _examen = data;
        _preguntas = preguntas;
        _cargando = false;
      });

      final duracionMin = data['duracionMinutos'] as int?;
      if (data['categoria'] == 'admision' && duracionMin != null) {
        _segundosRestantes = duracionMin * 60;
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          setState(() {
            _segundosRestantes--;
            if (_segundosRestantes <= 0) {
              t.cancel();
              _finalizarExamen(); // se acabó el tiempo: se envía tal cual
            }
          });
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.message ?? 'No se pudo abrir el examen.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Error inesperado al abrir el examen.';
      });
    }
  }

  Future<void> _finalizarExamen() async {
    if (_enviando || _finalizado) return;
    setState(() => _enviando = true);
    try {
      final respuestasArray = List<int?>.generate(
        _preguntas.length,
        (i) => _respuestas[i],
      );
      final result = await FirebaseFunctions.instance
          .httpsCallable('enviarResultadoExamen')
          .call({'examenId': widget.examenId, 'respuestas': respuestasArray});
      if (!mounted) return;
      setState(() {
        _finalizado = true;
        _enviando = false;
        _aciertos = result.data['aciertos'] as int?;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el examen. Intenta de nuevo.'),
        ),
      );
    }
  }

  String get _tiempoFormateado {
    final m = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final esAdmision = _examen?['categoria'] == 'admision';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text(
          widget.tituloPreview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (esAdmision && !_finalizado && !_cargando)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _tiempoFormateado,
                  style: TextStyle(
                    color: _segundosRestantes < 300
                        ? Colors.redAccent
                        : const Color(0xFFFFB800),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB800)),
            )
          : _error != null
          ? _buildError()
          : _finalizado
          ? _buildResultado()
          : _buildPregunta(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white38, size: 36),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado() {
    final total = _preguntas.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFB800), size: 48),
            const SizedBox(height: 16),
            Text(
              '${_aciertos ?? 0} / $total correctas',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Volver a exámenes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPregunta() {
    if (_preguntas.isEmpty) {
      return const Center(
        child: Text(
          'Este examen no tiene preguntas cargadas.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    final pregunta = _preguntas[_indice];
    final opciones = List<String>.from(pregunta['opciones'] as List? ?? []);
    final seleccion = _respuestas[_indice];
    final imagenSvg = pregunta['imagenSvg'] as String?;
    final correcta = pregunta['respuestaCorrecta'] as int?;
    final explicacion = (pregunta['explicacion'] as String?)?.trim();

    // Modo práctica (ordinario/exonerados): se revela la respuesta
    // correcta apenas el usuario elige, con colores + explicación —
    // igual al diseño de referencia (badge verde con check en la
    // correcta, panel morado con "i" para la explicación).
    // Modo admisión: simula un examen real, no revela nada hasta el
    // final (comportamiento sin cambios respecto a antes).
    final esAdmision = _examen?['categoria'] == 'admision';
    final esPractica = !esAdmision;
    final revelado = esPractica && seleccion != null;

    return SafeArea(
      // El fix del bug de los botones tapados por la barra de gestos del
      // sistema: antes esta fila iba directo pegada al borde del body sin
      // SafeArea, así que en dispositivos con navegación por gestos
      // (Redmi/MIUI, por ejemplo) quedaba parcialmente tapada.
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pregunta ${_indice + 1} de ${_preguntas.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((pregunta['pregunta'] as String?)?.isNotEmpty == true)
                      TextoConLatex(texto: pregunta['pregunta'] as String),
                    if (imagenSvg != null && imagenSvg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _ImagenPregunta(url: imagenSvg),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ...List.generate(opciones.length, (i) {
                      final esSeleccion = seleccion == i;
                      final esCorrecta = correcta != null && i == correcta;

                      _EstadoOpcion estado;
                      if (!revelado) {
                        estado = esSeleccion
                            ? _EstadoOpcion.seleccionada
                            : _EstadoOpcion.normal;
                      } else if (esCorrecta) {
                        estado = _EstadoOpcion.correcta;
                      } else if (esSeleccion) {
                        estado = _EstadoOpcion.incorrecta;
                      } else {
                        estado = _EstadoOpcion.atenuada;
                      }

                      // En modo práctica, una vez contestada la pregunta
                      // queda bloqueada (no se puede cambiar la
                      // respuesta) — fuerza a leer la explicación antes
                      // de avanzar. En admisión se puede cambiar
                      // libremente, como antes.
                      final bloqueada = esPractica && seleccion != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: bloqueada
                              ? null
                              : () => setState(() => _respuestas[_indice] = i),
                          child: _OpcionRow(
                            letra: String.fromCharCode(65 + i),
                            texto: opciones[i],
                            estado: estado,
                          ),
                        ),
                      );
                    }),
                    if (revelado &&
                        explicacion != null &&
                        explicacion.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PanelExplicacion(texto: explicacion),
                    ],
                  ],
                ),
              ),
            ),
            Row(
              children: [
                if (_indice > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _indice--),
                      child: const Text('Anterior'),
                    ),
                  ),
                if (_indice > 0) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        (_enviando || (esPractica && seleccion == null))
                        ? null
                        : () {
                            if (_indice + 1 >= _preguntas.length) {
                              _finalizarExamen();
                            } else {
                              setState(() => _indice++);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB800),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(
                        0xFFFFB800,
                      ).withValues(alpha: 0.3),
                      disabledForegroundColor: Colors.black45,
                    ),
                    child: _enviando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _indice + 1 >= _preguntas.length
                                ? 'Terminar examen'
                                : 'Siguiente',
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado visual de una opción de respuesta, según el diseño de
/// referencia: normal (sin contestar), seleccionada (modo admisión, sin
/// revelar), correcta (verde + check), incorrecta (roja + X, fue la
/// elegida) y atenuada (las demás una vez que ya se reveló la correcta).
enum _EstadoOpcion { normal, seleccionada, correcta, incorrecta, atenuada }

class _OpcionRow extends StatelessWidget {
  final String letra;
  final String texto;
  final _EstadoOpcion estado;

  const _OpcionRow({
    required this.letra,
    required this.texto,
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    late final Color fondo;
    late final Color borde;
    late final Color? colorTexto;
    late final Color colorBadgeBg;
    late final Color colorBadgeTexto;
    Widget? icono;
    double opacidad = 1;

    switch (estado) {
      case _EstadoOpcion.normal:
        fondo = const Color(0xFF1A1A1A);
        borde = Colors.white24;
        colorTexto = null; // usa el blanco por defecto de TextoConLatex
        colorBadgeBg = const Color(0xFF2A2A2A);
        colorBadgeTexto = Colors.white54;
        break;
      case _EstadoOpcion.seleccionada:
        fondo = const Color(0xFFFFB800).withValues(alpha: 0.15);
        borde = const Color(0xFFFFB800);
        colorTexto = null;
        colorBadgeBg = const Color(0xFFFFB800);
        colorBadgeTexto = Colors.black;
        break;
      case _EstadoOpcion.correcta:
        fondo = const Color(0xFF22C55E).withValues(alpha: 0.14);
        borde = const Color(0xFF22C55E);
        colorTexto = const Color(0xFF4ADE80);
        colorBadgeBg = const Color(0xFF22C55E);
        colorBadgeTexto = Colors.white;
        icono = const Icon(
          Icons.check_circle,
          color: Color(0xFF22C55E),
          size: 20,
        );
        break;
      case _EstadoOpcion.incorrecta:
        fondo = const Color(0xFFEF4444).withValues(alpha: 0.14);
        borde = const Color(0xFFEF4444);
        colorTexto = const Color(0xFFF87171);
        colorBadgeBg = const Color(0xFFEF4444);
        colorBadgeTexto = Colors.white;
        icono = const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 20);
        break;
      case _EstadoOpcion.atenuada:
        fondo = const Color(0xFF1A1A1A);
        borde = Colors.white10;
        colorTexto = Colors.white38;
        colorBadgeBg = const Color(0xFF2A2A2A);
        colorBadgeTexto = Colors.white24;
        opacidad = 0.6;
        break;
    }

    return Opacity(
      opacity: opacidad,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorBadgeBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                letra,
                style: TextStyle(
                  color: colorBadgeTexto,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextoConLatex(texto: texto, color: colorTexto),
            ),
            if (icono != null) ...[const SizedBox(width: 8), icono],
          ],
        ),
      ),
    );
  }
}

/// Panel de explicación tras revelar la respuesta — mismo diseño morado
/// con ícono "i" del mockup de referencia. Soporta LaTeX igual que la
/// pregunta y las opciones.
class _PanelExplicacion extends StatelessWidget {
  final String texto;
  const _PanelExplicacion({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B3266).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'i',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextoConLatex(
              texto: texto,
              color: const Color(0xFFD6D2F0),
            ),
          ),
        ],
      ),
    );
  }
}

/// Imagen de una pregunta de examen. Antes todas las imágenes eran SVG
/// (por eso el campo se sigue llamando `imagenSvg` en el JSON/Firestore,
/// para no romper los exámenes ya subidos). Ahora las imágenes nuevas se
/// suben como JPG/PNG porque la conversión a SVG deformaba varios
/// diagramas. Este widget detecta la extensión real de la URL y usa el
/// renderer correcto para cada caso — así conviven exámenes viejos (SVG)
/// y nuevos (JPG/PNG) sin migrar nada.
class _ImagenPregunta extends StatelessWidget {
  final String url;
  const _ImagenPregunta({required this.url});

  bool get _esSvg {
    final limpia = url.toLowerCase().split('?').first; // ignora ?token=...
    return limpia.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    if (_esSvg) {
      return SvgPicture.network(
        url,
        placeholderBuilder: (_) => const _ImagenLoading(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ImagenLoading();
      },
      errorBuilder: (context, error, stack) => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 32,
        ),
      ),
    );
  }
}

class _ImagenLoading extends StatelessWidget {
  const _ImagenLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFB800),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

