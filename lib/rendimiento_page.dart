import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Panel de rendimiento (Bloque 7) — Premium. Usa los datos que ya se
/// guardan en el resto de la app:
///  - users/{uid}/progresoQuiz/{cursoId_temaId}: niveles aprobados por tema
///  - users/{uid}/examenesResueltos/{examenId}: historial de exámenes
/// No hace falta ninguna Cloud Function nueva — solo lectura en vivo.
class RendimientoPage extends StatelessWidget {
  const RendimientoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB800)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('progresoQuiz')
          .snapshots(),
      builder: (context, progresoSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('examenesResueltos')
              .orderBy('fecha', descending: true)
              .snapshots(),
          builder: (context, examenesSnap) {
            if (!progresoSnap.hasData || !examenesSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB800)),
              );
            }

            final progresoDocs = progresoSnap.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();
            final examenesDocs = examenesSnap.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();

            // Agrupar progreso por curso (nombreCurso)
            final Map<String, List<Map<String, dynamic>>> porCurso = {};
            for (final p in progresoDocs) {
              final curso = (p['nombreCurso'] as String?) ?? 'Curso';
              porCurso.putIfAbsent(curso, () => []).add(p);
            }

            // Resumen general
            int temasConBasico = 0;
            int temasConAvanzado = 0;
            for (final p in progresoDocs) {
              if (p['basico']?['aprobado'] == true) temasConBasico++;
              if (p['avanzado']?['aprobado'] == true) temasConAvanzado++;
            }
            final totalExamenes = examenesDocs.length;
            double promedioExamenes = 0;
            if (totalExamenes > 0) {
              final sumaPct = examenesDocs.fold<double>(0, (acc, e) {
                final aciertos = (e['aciertos'] as num?)?.toDouble() ?? 0;
                final total = (e['total'] as num?)?.toDouble() ?? 1;
                return acc + (total > 0 ? aciertos / total : 0);
              });
              promedioExamenes = (sumaPct / totalExamenes) * 100;
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Rendimiento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ResumenCard(
                        icono: Icons.check_circle_outline,
                        valor: '$temasConBasico',
                        etiqueta: 'Temas con Básico',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResumenCard(
                        icono: Icons.workspace_premium_outlined,
                        valor: '$temasConAvanzado',
                        etiqueta: 'Temas con Avanzado',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ResumenCard(
                        icono: Icons.assignment_turned_in_outlined,
                        valor: '$totalExamenes',
                        etiqueta: 'Exámenes rendidos',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResumenCard(
                        icono: Icons.percent_outlined,
                        valor: totalExamenes > 0
                            ? '${promedioExamenes.round()}%'
                            : '—',
                        etiqueta: 'Promedio exámenes',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                if (porCurso.isEmpty)
                  const _VacioCard(
                    mensaje:
                        'Todavía no has rendido ningún quiz de curso. '
                        'Entra a un tema en Cursos y prueba el nivel Básico.',
                  )
                else ...[
                  const Text(
                    'Progreso por curso',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...porCurso.entries.map(
                    (e) =>
                        _CursoProgresoCard(nombreCurso: e.key, temas: e.value),
                  ),
                ],

                const SizedBox(height: 28),
                const Text(
                  'Historial de exámenes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (examenesDocs.isEmpty)
                  const _VacioCard(
                    mensaje: 'Todavía no has rendido ningún examen.',
                  )
                else
                  ...examenesDocs.map((e) => _ExamenHistorialTile(data: e)),

                const SizedBox(height: 40),
              ],
            );
          },
        );
      },
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  const _ResumenCard({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: const Color(0xFFFFB800), size: 20),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _VacioCard extends StatelessWidget {
  final String mensaje;
  const _VacioCard({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mensaje,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}

class _CursoProgresoCard extends StatelessWidget {
  final String nombreCurso;
  final List<Map<String, dynamic>> temas;
  const _CursoProgresoCard({required this.nombreCurso, required this.temas});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombreCurso,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...temas.map((t) {
            final titulo = (t['tituloTema'] as String?) ?? 'Tema';
            final basico = t['basico']?['aprobado'] == true;
            final intermedio = t['intermedio']?['aprobado'] == true;
            final avanzado = t['avanzado']?['aprobado'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _puntoNivel('B', basico),
                  const SizedBox(width: 4),
                  _puntoNivel('I', intermedio),
                  const SizedBox(width: 4),
                  _puntoNivel('A', avanzado),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _puntoNivel(String letra, bool aprobado) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: aprobado
            ? const Color(0xFFFFB800)
            : Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Text(
        letra,
        style: TextStyle(
          color: aprobado ? Colors.black : Colors.white38,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ExamenHistorialTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ExamenHistorialTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final aciertos = data['aciertos'] ?? 0;
    final total = data['total'] ?? 0;
    final categoria = (data['categoria'] as String?) ?? '';
    final fecha = data['fecha'];
    String fechaTexto = '';
    if (fecha is Timestamp) {
      final d = fecha.toDate();
      fechaTexto =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['titulo'] as String?) ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${categoria.toUpperCase()} · $fechaTexto',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$aciertos/$total',
            style: const TextStyle(
              color: Color(0xFFFFB800),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
