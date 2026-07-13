import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app_movil/examen_sesion_page.dart';
import 'package:app_movil/pago_premium_page.dart';
import 'package:app_movil/services/database.dart';

/// Lista los exámenes disponibles, separados en dos secciones:
///  - Exámenes pasados (exonerados y ordinario): visibles para todos;
///    Free tiene 1 por día, Premium sin límite (el límite real se aplica
///    en el backend al abrir el examen, no aquí — esto es solo la lista).
///  - Exámenes tipo admisión (con temporizador): exclusivo Premium.
class ExamenesPage extends StatelessWidget {
  const ExamenesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB800)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: DatabaseMethods().obtenerUsuario(user.uid),
          builder: (context, userSnap) {
            final esPremium = userSnap.data?['plan'] == 'premium';

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('examenesIndice')
                  .orderBy('orden')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFB800)),
                  );
                }
                final docs = snapshot.data!.docs;
                final pasados = docs
                    .where((d) => (d.data() as Map)['categoria'] != 'admision')
                    .toList();
                final admision = docs
                    .where((d) => (d.data() as Map)['categoria'] == 'admision')
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Exámenes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SeccionTitulo(
                      'Exámenes pasados',
                      esPremium
                          ? 'Sin límite diario'
                          : '1 por día en plan Free',
                    ),
                    const SizedBox(height: 10),
                    if (pasados.isEmpty)
                      const _SinExamenes()
                    else
                      ...pasados.map(
                        (d) => _ExamenTile(
                          examenId: d.id,
                          data: d.data() as Map<String, dynamic>,
                          bloqueado: false,
                          user: user,
                        ),
                      ),
                    const SizedBox(height: 28),
                    _SeccionTitulo(
                      'Exámenes tipo admisión',
                      'Simulacro con tiempo — función Premium',
                    ),
                    const SizedBox(height: 10),
                    if (admision.isEmpty)
                      const _SinExamenes()
                    else
                      ...admision.map(
                        (d) => _ExamenTile(
                          examenId: d.id,
                          data: d.data() as Map<String, dynamic>,
                          bloqueado: !esPremium,
                          user: user,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  const _SeccionTitulo(this.titulo, this.subtitulo);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitulo,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

class _SinExamenes extends StatelessWidget {
  const _SinExamenes();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Sin exámenes cargados todavía.',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}

class _ExamenTile extends StatelessWidget {
  final String examenId;
  final Map<String, dynamic> data;
  final bool bloqueado;
  final User user;
  const _ExamenTile({
    required this.examenId,
    required this.data,
    required this.bloqueado,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final esAdmision = data['categoria'] == 'admision';
    final duracion = data['duracionMinutos'] as int?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          if (bloqueado) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PagoPremiumPage(user: user)),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExamenSesionPage(
                examenId: examenId,
                tituloPreview: data['titulo'] ?? '',
              ),
            ),
          );
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
              Icon(
                esAdmision ? Icons.timer_outlined : Icons.assignment_outlined,
                color: bloqueado ? Colors.white38 : const Color(0xFFFFB800),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['titulo'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (data['anio'] != null) '${data['anio']}',
                        if (data['categoria'] != null)
                          (data['categoria'] as String).toUpperCase(),
                        if (esAdmision && duracion != null) '$duracion min',
                      ].join(' · '),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
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
      ),
    );
  }
}
