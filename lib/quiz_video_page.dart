import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:app_movil/widgets/texto_latex.dart';

/// Quiz de un tema, para un nivel específico (básico/intermedio/avanzado).
/// La generación con IA ya NO ocurre aquí — la hace un admin desde el
/// panel de control, quien también la revisa y aprueba antes de que
/// cualquier alumno la vea. Esta pantalla solo LEE lo que ya está
/// aprobado; si todavía no hay nada aprobado, muestra un aviso (no un
/// error) en vez de intentar generar.
class QuizVideoPage extends StatefulWidget {
  final String cursoId;
  final String temaId;
  final String nivel; // 'basico' | 'intermedio' | 'avanzado'
  final String tituloTema;

  const QuizVideoPage({
    super.key,
    required this.cursoId,
    required this.temaId,
    required this.nivel,
    required this.tituloTema,
  });

  @override
  State<QuizVideoPage> createState() => _QuizVideoPageState();
}

class _QuizVideoPageState extends State<QuizVideoPage> {
  bool _cargando = true;
  String? _error;
  bool _noDisponibleAun = false;
  List<Map<String, dynamic>> _preguntas = [];
  int _indice = 0;
  int _aciertos = 0;
  final Map<int, int> _respuestas = {}; // índice de pregunta -> opción elegida
  int? _seleccion;
  bool _mostrarResultado = false;
  bool _enviandoResultado = true;
  bool? _aprobado;

  @override
  void initState() {
    super.initState();
    _cargarQuiz();
  }

  Future<void> _cargarQuiz() async {
    setState(() {
      _cargando = true;
      _error = null;
      _noDisponibleAun = false;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('obtenerQuizTema')
          .call({
            'cursoId': widget.cursoId,
            'temaId': widget.temaId,
            'nivel': widget.nivel,
          });
      final data = result.data as Map;
      final lista = (data['preguntas'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _preguntas = lista;
        _cargando = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        // "failed-precondition" es el código que usa el backend tanto
        // para "todavía no te toca" como para "el admin no lo ha
        // aprobado todavía" — ambos son estados normales, no errores de
        // verdad, así que se muestran distinto (sin rojo/ícono de error).
        _noDisponibleAun = e.code == 'failed-precondition';
        _error = e.message ?? 'No se pudo cargar el quiz.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Error inesperado al generar el quiz.';
      });
    }
  }

  void _seleccionar(int i) {
    if (_seleccion != null) return; // ya respondió esta pregunta
    setState(() {
      _seleccion = i;
      _respuestas[_indice] = i;
      // _aciertos local solo se usa para el feedback visual inmediato en
      // esta pantalla (revelado por pregunta); la calificación real que
      // decide "aprobado" ahora la hace el servidor con las respuestas
      // reales (ver _enviarResultado), no este contador.
      if (i == _preguntas[_indice]['respuestaCorrecta']) {
        _aciertos++;
      }
    });
  }

  void _siguiente() {
    if (_indice + 1 >= _preguntas.length) {
      setState(() => _mostrarResultado = true);
      _enviarResultado();
      return;
    }
    setState(() {
      _indice++;
      _seleccion = null;
    });
  }

  Future<void> _enviarResultado() async {
    setState(() => _enviandoResultado = true);
    try {
      final respuestasArray = List<int?>.generate(
        _preguntas.length,
        (i) => _respuestas[i],
      );
      final result = await FirebaseFunctions.instance
          .httpsCallable('enviarResultadoQuiz')
          .call({
            'cursoId': widget.cursoId,
            'temaId': widget.temaId,
            'nivel': widget.nivel,
            'respuestas': respuestasArray,
          });
      if (!mounted) return;
      final data = result.data as Map;
      setState(() {
        _aprobado = data['aprobado'] as bool?;
        _enviandoResultado = false;
      });
    } catch (_) {
      // Si falla el envío, igual mostramos el score local — el usuario
      // no se queda trabado, aunque el progreso no haya quedado guardado.
      if (!mounted) return;
      setState(() => _enviandoResultado = false);
    }
  }

  String get _tituloNivel => switch (widget.nivel) {
    'basico' => 'Básico',
    'intermedio' => 'Intermedio',
    _ => 'Avanzado',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text('Quiz $_tituloNivel'),
      ),
      body: _cargando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFB800)),
                  SizedBox(height: 16),
                  Text(
                    'Cargando quiz...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _noDisponibleAun
                          ? Icons.hourglass_empty_rounded
                          : Icons.error_outline,
                      color: _noDisponibleAun
                          ? const Color(0xFFFFB800)
                          : Colors.redAccent,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _cargarQuiz,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _mostrarResultado
          ? _buildResultado()
          : _buildPregunta(),
    );
  }

  Widget _buildResultado() {
    final total = _preguntas.length;

    if (_enviandoResultado) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB800)),
      );
    }

    final aprobado = _aprobado ?? (_aciertos >= total);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              aprobado ? Icons.emoji_events : Icons.replay,
              color: aprobado ? const Color(0xFFFFB800) : Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '$_aciertos / $total correctas',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              aprobado
                  ? '¡Aprobado! Ya puedes intentar el siguiente nivel.'
                  : 'Necesitas las $total correctas para aprobar este nivel. ¡Vuelve a intentarlo!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, aprobado),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Volver al tema'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPregunta() {
    final pregunta = _preguntas[_indice];
    final opciones = List<String>.from(pregunta['opciones'] as List);
    final correcta = pregunta['respuestaCorrecta'] as int;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pregunta ${_indice + 1} de ${_preguntas.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextoConLatex(
            texto: pregunta['pregunta'] as String,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 20),
          ...List.generate(opciones.length, (i) {
            Color color = const Color(0xFF1A1A1A);
            Color borde = Colors.white24;
            if (_seleccion != null) {
              if (i == correcta) {
                color = Colors.green.withValues(alpha: 0.15);
                borde = Colors.green;
              } else if (i == _seleccion) {
                color = Colors.red.withValues(alpha: 0.15);
                borde = Colors.redAccent;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _seleccionar(i),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borde),
                  ),
                  child: TextoConLatex(texto: opciones[i]),
                ),
              ),
            );
          }),
          if (_seleccion != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextoConLatex(
                texto: pregunta['explicacion'] as String? ?? '',
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _siguiente,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  _indice + 1 >= _preguntas.length
                      ? 'Ver resultado'
                      : 'Siguiente',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
