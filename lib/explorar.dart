import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_movil/services/database.dart';
import 'package:app_movil/pago_premium_page.dart';
import 'package:app_movil/chatbot_page.dart'; // ChatFabGlass (ícono + panel glass)
import 'package:app_movil/quiz_video_page.dart';

// Convierte recursivamente lo que devuelve un httpsCallable (Cloud
// Functions) a Map<String, dynamic> de verdad, en todos los niveles. El
// resultado de Cloud Functions llega por el canal de plataforma como
// _Map<Object?, Object?> (claves y valores dynamic sin tipar) — un cast
// directo "as Map<String, dynamic>" solo funciona en el nivel más
// externo; cualquier Map anidado adentro sigue siendo el tipo crudo y
// revienta con un TypeError apenas alguien intenta castearlo más abajo.
Map<String, dynamic> _aMapaProfundo(dynamic valor) {
  if (valor is Map) {
    return valor.map((k, v) => MapEntry(k.toString(), _valorProfundo(v)));
  }
  return {};
}

dynamic _valorProfundo(dynamic v) {
  if (v is Map) return _aMapaProfundo(v);
  if (v is List) return v.map(_valorProfundo).toList();
  return v;
}

// ===================== EXPLORAR PAGE =====================
class ExplorarPage extends StatefulWidget {
  const ExplorarPage({super.key});

  @override
  State<ExplorarPage> createState() => _ExplorarPageState();
}

class _ExplorarPageState extends State<ExplorarPage> {
  late final Future<Map<String, dynamic>> _progresoFuture;

  @override
  void initState() {
    super.initState();
    _progresoFuture = _cargarProgreso();
  }

  // Trae, en UNA sola llamada, cuántos temas de cada curso ya están
  // disponibles según el calendario individual de este alumno (sin
  // cambiar su ritmo — sigue siendo por alumno, no por "salón"), cuántos
  // quizzes básicos ya aprobó, en qué día de su ruta está (diaActual) y
  // qué temas le tocan exactamente hoy (temasHoy). Si falla (sin
  // conexión, etc.) la UI simplemente no muestra los badges ni la
  // tarjeta de "hoy" — no bloquea la pantalla.
  Future<Map<String, dynamic>> _cargarProgreso() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('obtenerProgresoCursos')
          .call({});
      // Cloud Functions (a diferencia de Firestore) devuelve el Map por el
      // canal de plataforma como _Map<Object?, Object?>, NO como
      // Map<String, dynamic> — y solo convertir el nivel de arriba no
      // alcanza porque los niveles anidados (cursos -> temas) siguen
      // siendo el tipo crudo por dentro. Por eso el cast fallaba más
      // abajo con "type '_Map<Object?, Object?>' is not a subtype of
      // type 'Map<String, dynamic>?'" — hay que convertir profundo, no
      // solo la capa exterior.
      return _aMapaProfundo(result.data);
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Explorar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _progresoFuture,
                builder: (context, progresoSnap) {
                  final fullData = progresoSnap.data ?? {};
                  final progresoPorCurso = Map<String, dynamic>.from(
                    fullData['cursos'] ?? {},
                  );
                  final diaActual = fullData['diaActual'] as int?;
                  final temasHoy = (fullData['temasHoy'] as List?) ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('cursos')
                        .orderBy('orden')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFFB800),
                            strokeWidth: 2,
                          ),
                        );
                      }

                      final cursos = snapshot.data!.docs;

                      if (cursos.isEmpty) {
                        return Center(
                          child: Text(
                            'Sin cursos disponibles',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: cursos.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return _DiaActualCard(
                              diaActual: diaActual,
                              temasHoy: temasHoy,
                            );
                          }
                          final data =
                              cursos[i - 1].data() as Map<String, dynamic>;
                          return _CursoCard(
                            cursoId: cursos[i - 1].id,
                            data: data,
                            progreso:
                                progresoPorCurso[cursos[i - 1].id]
                                    as Map<String, dynamic>?,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== CURSO CARD =====================
class _CursoCard extends StatefulWidget {
  final String cursoId;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? progreso;
  const _CursoCard({required this.cursoId, required this.data, this.progreso});

  @override
  State<_CursoCard> createState() => _CursoCardState();
}

class _CursoCardState extends State<_CursoCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final progreso = widget.progreso;
    final temasDisponibles = progreso?['temasDisponibles'] as int?;
    final quizzesAprobados = progreso?['quizzesAprobados'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        widget.data['icono'] ?? '📚',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['nombre'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.data['area'] ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avance del curso — reemplaza la idea de mostrar un
                  // número de "semana" abstracto: esto es concreto y es
                  // por alumno (cada quien a su propio ritmo, según
                  // cuándo se hizo Premium, sin cambios ahí).
                  if (temasDisponibles != null && quizzesAprobados != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$quizzesAprobados/$temasDisponibles',
                          style: const TextStyle(
                            color: Color(0xFFFFB800),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'quizzes',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cursos')
                  .doc(widget.cursoId)
                  .collection('temas')
                  .orderBy('orden')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFB800),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                final temas = snapshot.data!.docs;
                if (temas.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(
                      'Sin temas cargados aún',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                final temasProgreso =
                    widget.progreso?['temas'] as Map<String, dynamic>?;
                return Column(
                  children: [
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    ...temas.map(
                      (tema) => _TemaRow(
                        cursoId: widget.cursoId,
                        temaId: tema.id,
                        temaData: tema.data() as Map<String, dynamic>,
                        estadoQuiz:
                            temasProgreso?[tema.id] as Map<String, dynamic>?,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ===================== TEMA ROW =====================
class _TemaRow extends StatelessWidget {
  final String cursoId;
  final String temaId;
  final Map<String, dynamic> temaData;
  final Map<String, dynamic>? estadoQuiz;
  const _TemaRow({
    required this.cursoId,
    required this.temaId,
    required this.temaData,
    this.estadoQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final tieneVideo = (temaData['videoId'] ?? '').isNotEmpty;
    final tienePdf =
        (temaData['pdfUrl'] ?? '').isNotEmpty ||
        (temaData['materiales'] is List &&
            (temaData['materiales'] as List).isNotEmpty);
    final bloqueado = !tieneVideo && !tienePdf;

    // Badge de estado del quiz para ESTE tema — usa el mismo dato que
    // ya se calculó una vez arriba (obtenerProgresoCursos), no hace
    // ninguna llamada extra por fila.
    final disponible = estadoQuiz?['disponible'] as bool?;
    final aprobado = estadoQuiz?['aprobado'] as bool?;
    Widget? badgeQuiz;
    if (aprobado == true) {
      badgeQuiz = const Icon(
        Icons.check_circle,
        color: Color(0xFF4ADE80),
        size: 14,
      );
    } else if (disponible == true) {
      badgeQuiz = Icon(
        Icons.hourglass_bottom_rounded,
        color: const Color(0xFFFFB800).withValues(alpha: 0.7),
        size: 13,
      );
    }

    return GestureDetector(
      onTap: bloqueado
          ? null
          : () => Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (context, animation, _) => FadeTransition(
                  opacity: animation,
                  child: TemaDetailPage(
                    cursoId: cursoId,
                    temaId: temaId,
                    temaData: temaData,
                  ),
                ),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '${temaData['orden'] ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                temaData['titulo'] ?? '',
                style: TextStyle(
                  color: bloqueado
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                if (badgeQuiz != null) ...[badgeQuiz, const SizedBox(width: 6)],
                if (tieneVideo)
                  const Icon(
                    Icons.play_circle_outline,
                    color: Color(0xFFFFB800),
                    size: 16,
                  ),
                if (tieneVideo && tienePdf) const SizedBox(width: 6),
                if (tienePdf)
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 16,
                  ),
                if (bloqueado)
                  Icon(
                    Icons.lock_outline,
                    color: Colors.white.withValues(alpha: 0.2),
                    size: 14,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== TEMA DETAIL PAGE =====================
class TemaDetailPage extends StatefulWidget {
  final String cursoId;
  final String temaId;
  final Map<String, dynamic> temaData;
  const TemaDetailPage({
    super.key,
    required this.cursoId,
    required this.temaId,
    required this.temaData,
  });

  @override
  State<TemaDetailPage> createState() => _TemaDetailPageState();
}

class _TemaDetailPageState extends State<TemaDetailPage> {
  YoutubePlayerController? _controller;
  late final Future<Map<String, dynamic>?> _usuarioFuture;

  @override
  void initState() {
    super.initState();
    final videoId = widget.temaData['videoId'] ?? '';
    if (videoId.isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _usuarioFuture = uid == null
        ? Future.value(null)
        : DatabaseMethods().obtenerUsuario(uid);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final temaData = widget.temaData;
    final tieneVideo = (temaData['videoId'] ?? '').isNotEmpty;

    // Junta el formato original (un solo pdfUrl) con el nuevo (lista
    // "materiales") para no romper nada de lo que ya tengas cargado.
    final materiales = <Map<String, String>>[
      if ((temaData['pdfUrl'] ?? '').toString().isNotEmpty)
        {'titulo': 'Material PDF', 'url': temaData['pdfUrl'].toString()},
      if (temaData['materiales'] is List)
        ...(temaData['materiales'] as List).whereType<Map>().map(
          (m) => {
            'titulo': (m['titulo'] ?? 'Material').toString(),
            'url': (m['url'] ?? '').toString(),
          },
        ),
    ].where((m) => m['url']!.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      // El panel del chat (ChatFabGlass) maneja el teclado por su cuenta
      // (sube su posición con MediaQuery.viewInsets.bottom, manteniendo
      // tamaño fijo). Si dejamos el auto-resize del Scaffold, el body
      // completo se encoge cuando aparece el teclado y el cálculo del
      // panel se descuadra — por eso se desactiva aquí. No afecta al
      // resto de la pantalla porque el único campo de texto de esta
      // página es el del chat.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          temaData['titulo'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video
                if (tieneVideo && _controller != null)
                  YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFFFFB800),
                    progressColors: const ProgressBarColors(
                      playedColor: Color(0xFFFFB800),
                      handleColor: Color(0xFFFFB800),
                    ),
                  ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    temaData['titulo'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Materiales (uno o varios)
                if (materiales.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Material',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...materiales.map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MaterialCard(
                              titulo: m['titulo']!,
                              url: m['url']!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Quiz por nivel. El chat con tutor IA ahora vive en el
                // ícono flotante (ChatFabGlass) — ya no es una card en esta
                // lista. Gratis ve el paywall del quiz; Premium ve el quiz
                // real según el calendario de su ruta de estudio.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: _usuarioFuture,
                    builder: (context, snapshot) {
                      final esPremium = snapshot.data?['plan'] == 'premium';
                      final user = FirebaseAuth.instance.currentUser;

                      if (!esPremium) {
                        return _ChatTeaserCard(
                          icono: Icons.quiz_outlined,
                          titulo: 'Quiz de este tema',
                          bloqueado: true,
                          onTap: user == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PagoPremiumPage(user: user),
                                  ),
                                ),
                        );
                      }
                      return FutureBuilder<Map<String, dynamic>>(
                        future: FirebaseFunctions.instance
                            .httpsCallable('obtenerEstadoCalendarioTema')
                            .call({
                              'cursoId': widget.cursoId,
                              'temaId': widget.temaId,
                            })
                            .then((r) => Map<String, dynamic>.from(r.data)),
                        builder: (context, calSnap) {
                          if (!calSnap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFFB800),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final habilitadoHoy =
                              calSnap.data!['habilitadoHoy'] as bool? ?? false;

                          if (!habilitadoHoy) {
                            return _QuizNoDisponibleCard(
                              diaAsignado: calSnap.data!['diaAsignado'] as int?,
                              diaActual: calSnap.data!['diaActual'] as int?,
                            );
                          }

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user!.uid)
                                .collection('progresoQuiz')
                                .doc('${widget.cursoId}_${widget.temaId}')
                                .snapshots(),
                            builder: (context, progresoSnap) {
                              final progreso =
                                  progresoSnap.data?.data()
                                      as Map<String, dynamic>?;
                              final basicoAprobado =
                                  (progreso?['basico']?['aprobado'] as bool?) ??
                                  false;
                              final intermedioAprobado =
                                  (progreso?['intermedio']?['aprobado']
                                      as bool?) ??
                                  false;

                              return _QuizNivelesCard(
                                intermedioBloqueado: !basicoAprobado,
                                avanzadoBloqueado: !intermedioAprobado,
                                onSeleccionarNivel: (nivel) {
                                  // Antes el video seguía sonando de fondo
                                  // mientras el estudiante hacía el quiz —
                                  // se pausa al salir a esa pantalla.
                                  _controller?.pause();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuizVideoPage(
                                        cursoId: widget.cursoId,
                                        temaId: widget.temaId,
                                        nivel: nivel,
                                        tituloTema: temaData['titulo'] ?? '',
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // Espacio reservado para que el contenido nunca quede pegado
                // a la zona del ícono flotante del chat. Se calcula con el
                // inset real de este dispositivo (barra de navegación de 3
                // botones, gestos, etc.) en vez de un número fijo adivinado
                // — antes el botón "Avanzado" del quiz terminaba tapado por
                // el ícono en dispositivos con barra de navegación alta.
                SizedBox(height: 90 + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
          // Ícono flotante del tutor IA — overlay sobre toda esta
          // pantalla, siempre visible mientras estás en este tema. El
          // control de qué área es "tocable" (solo el ícono cuando el
          // panel está cerrado, toda la pantalla cuando está abierto)
          // vive dentro de ChatFabGlass con su propio IgnorePointer.
          Positioned.fill(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _usuarioFuture,
              builder: (context, snapshot) {
                final esPremium = snapshot.data?['plan'] == 'premium';
                final user = FirebaseAuth.instance.currentUser;
                return ChatFabGlass(
                  cursoId: widget.cursoId,
                  temaId: widget.temaId,
                  tituloTema: temaData['titulo'] ?? '',
                  bloqueado: !esPremium,
                  youtubeController: _controller,
                  onBloqueadoTap: user == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PagoPremiumPage(user: user),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== TARJETA DE MATERIAL =====================
class _MaterialCard extends StatelessWidget {
  final String titulo;
  final String url;
  const _MaterialCard({required this.titulo, required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: Color(0xFFFFB800),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Toca para abrir',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

// ===================== TARJETA "DÍA ACTUAL" =====================
// Le muestra al postulante en qué día de su ruta de estudio está y qué
// temas le corresponden hoy exactamente — antes esta información solo
// existía dentro de la notificación push del día, sin ningún lugar
// dentro de la app para volver a consultarla. Cada tema es un botón que
// va directo a su pantalla (mismo destino que tocar el tema desde la
// lista del curso).
class _DiaActualCard extends StatefulWidget {
  final int? diaActual;
  final List temasHoy;
  const _DiaActualCard({required this.diaActual, required this.temasHoy});

  @override
  State<_DiaActualCard> createState() => _DiaActualCardState();
}

class _DiaActualCardState extends State<_DiaActualCard> {
  String? _cargandoTemaId;

  Future<void> _abrirTema(
    BuildContext context,
    String cursoId,
    String temaId,
  ) async {
    setState(() => _cargandoTemaId = temaId);
    try {
      final temaSnap = await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('temas')
          .doc(temaId)
          .get();
      if (!context.mounted) return;
      if (!temaSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este tema ya no está disponible.')),
        );
        return;
      }
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, _) => FadeTransition(
            opacity: animation,
            child: TemaDetailPage(
              cursoId: cursoId,
              temaId: temaId,
              temaData: temaSnap.data() as Map<String, dynamic>,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _cargandoTemaId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dia = widget.diaActual;
    // Sin ruta iniciada todavía (diaActual == 0 o null): no mostramos nada,
    // no hay "día" que reportar.
    if (dia == null || dia <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFFFB800)),
              const SizedBox(width: 10),
              Text(
                'Día $dia de tu preparación',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (widget.temasHoy.isEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Hoy no tienes temas nuevos — aprovecha para repasar.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 12),
            // Columna de ancho completo en vez de Wrap con chips: los
            // títulos largos de algunos temas desbordaban el chip
            // horizontal (RenderFlex overflowed). Con Expanded + softWrap
            // el texto se ajusta a 2 líneas dentro del ancho disponible
            // en vez de intentar salirse de la tarjeta.
            Column(
              children: widget.temasHoy.map((t) {
                final map = t as Map;
                final cursoId = map['cursoId']?.toString() ?? '';
                final temaId = map['temaId']?.toString() ?? '';
                final titulo = map['tituloTema']?.toString() ?? 'Tema';
                final cargando = _cargandoTemaId == temaId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: cargando
                        ? null
                        : () => _abrirTema(context, cursoId, temaId),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (cargando)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFB800),
                              ),
                            )
                          else
                            const Icon(
                              Icons.play_circle_outline,
                              size: 16,
                              color: Color(0xFFFFB800),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              titulo,
                              softWrap: true,
                              style: const TextStyle(
                                color: Color(0xFFFFB800),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== QUIZ NO DISPONIBLE HOY =====================
class _QuizNoDisponibleCard extends StatelessWidget {
  final int? diaAsignado;
  final int? diaActual;
  const _QuizNoDisponibleCard({this.diaAsignado, this.diaActual});

  @override
  Widget build(BuildContext context) {
    // Promote nullable fields to local variables so the analyzer can
    // properly narrow their types for the null-check and comparison.
    final _diaAsignado = diaAsignado;
    final _diaActual = diaActual;
    final yaPaso =
        _diaAsignado != null && _diaActual != null && _diaActual > _diaAsignado;
    final mensaje = yaPaso
        ? 'La fecha del quiz de este tema ya pasó — el video queda '
              'disponible solo para repaso.'
        : 'El quiz de este tema todavía no se habilita en tu ruta de '
              'estudio. Sigue avanzando día a día.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            yaPaso ? Icons.history_toggle_off : Icons.event_outlined,
            color: Colors.white38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quiz de este tema',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mensaje,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== TARJETA QUIZ POR NIVEL =====================
class _QuizNivelesCard extends StatelessWidget {
  final bool intermedioBloqueado;
  final bool avanzadoBloqueado;
  final ValueChanged<String> onSeleccionarNivel;
  const _QuizNivelesCard({
    required this.intermedioBloqueado,
    required this.avanzadoBloqueado,
    required this.onSeleccionarNivel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quiz_outlined, color: Color(0xFFFFB800)),
              SizedBox(width: 10),
              Text(
                'Quiz de este tema',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Necesitas 10/10 para aprobar cada nivel y desbloquear el siguiente.',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _botonNivel(context, 'Básico', 'basico', bloqueado: false),
              const SizedBox(width: 8),
              _botonNivel(
                context,
                'Intermedio',
                'intermedio',
                bloqueado: intermedioBloqueado,
              ),
              const SizedBox(width: 8),
              _botonNivel(
                context,
                'Avanzado',
                'avanzado',
                bloqueado: avanzadoBloqueado,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonNivel(
    BuildContext context,
    String label,
    String nivel, {
    required bool bloqueado,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          if (bloqueado) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Primero aprueba el nivel anterior (10/10).'),
              ),
            );
            return;
          }
          onSeleccionarNivel(nivel);
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: bloqueado ? Colors.white12 : Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (bloqueado) ...[
              const Icon(Icons.lock_outline, size: 12, color: Colors.white38),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: bloqueado ? Colors.white38 : Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ TARJETA "FUNCIÓN PREMIUM" (paywall genérico) ============
// Antes era solo para el chat con IA; ahora también la usa el paywall
// del quiz, ya que el chat se movió al ícono flotante (ChatFabGlass).
class _ChatTeaserCard extends StatelessWidget {
  final bool bloqueado;
  final VoidCallback? onTap;
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  const _ChatTeaserCard({
    required this.bloqueado,
    this.onTap,
    this.icono = Icons.smart_toy_rounded,
    this.titulo = 'Chat con tu tutor IA',
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(
              icono,
              color: bloqueado ? Colors.white38 : const Color(0xFFFFB800),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo ??
                        (bloqueado
                            ? 'Función Premium — toca para actualizar tu plan'
                            : 'Toca para continuar'),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              bloqueado ? Icons.lock_outline : Icons.chevron_right,
              color: Colors.white38,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
