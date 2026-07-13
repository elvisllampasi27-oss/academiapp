import 'dart:ui';
import 'package:app_movil/admin_pagos_pendientes_page.dart';
import 'package:app_movil/examenes_page.dart';
import 'package:app_movil/explorar.dart';
import 'package:app_movil/login.dart';
import 'package:app_movil/notificaciones_service.dart';
import 'package:app_movil/pago_premium_page.dart';
import 'package:app_movil/rendimiento_page.dart';
import 'package:app_movil/services/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tabActual = 0;
  bool _esAdmin = false;

  final _tabs = const [
    _TabInfo(
      icono: Icons.insights_outlined,
      label: 'Rendimiento',
      color: Color(0xFF3B82F6), // azul: estadísticas / análisis
    ),
    _TabInfo(
      icono: Icons.play_circle_outline,
      label: 'Cursos',
      color: Color(0xFF22C55E), // verde: progreso / play
    ),
    _TabInfo(
      icono: Icons.assignment_outlined,
      label: 'Exámenes',
      color: Color(0xFFF97316), // naranja: evaluación
    ),
    _TabInfo(
      icono: Icons.person_outline,
      label: 'Perfil',
      color: Color(0xFFA855F7), // morado: personal
    ),
  ];

  @override
  void initState() {
    super.initState();
    _chequearAdmin();
    NotificacionesService.inicializar(context);
  }

  Future<void> _chequearAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final resultado = await user.getIdTokenResult(true);
    if (!mounted) return;
    setState(() => _esAdmin = resultado.claims?['admin'] == true);
  }

  Future<void> _cerrarSesion() async {
    await NotificacionesService.limpiarTokenAlCerrarSesion();
    await AuthMethods().cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, _) =>
            FadeTransition(opacity: animation, child: const LogIn()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      // extendBody permite que el contenido se dibuje detrás de la barra flotante
      // sin que Flutter reserve espacio duplicado por su cuenta.
      extendBody: true,
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFB800)),
                );
              }
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final nombre = data?['nombre'] ?? '';
              final plan = data?['plan'] ?? 'free';
              final esPremium = plan == 'premium';

              return SafeArea(
                // Solo protegemos arriba/lados aquí; el espacio inferior
                // seguro lo maneja la barra flotante para evitar duplicarlo.
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Hola, $nombre',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _BadgePlan(esPremium: esPremium),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _tabActual,
                        children: [
                          _TabRendimiento(esPremium: esPremium, user: user),
                          const _TabCursos(),
                          const _TabExamenes(),
                          _TabPerfil(
                            esAdmin: _esAdmin,
                            onCerrarSesion: _cerrarSesion,
                          ),
                        ],
                      ),
                    ),
                    // Reservamos espacio para que el contenido no quede
                    // tapado por la barra flotante (altura de la barra +
                    // margen). El padding seguro del sistema se suma aparte
                    // dentro del SafeArea de la barra.
                    const SizedBox(height: 96),
                  ],
                ),
              );
            },
          ),

          // Barra de navegación flotante envuelta en su propio SafeArea
          // para que respete el área segura inferior del dispositivo
          // (botones de navegación de Android o el home indicator de iOS).
          // Antes este Positioned quedaba fuera del SafeArea y su
          // "bottom: 20" se medía desde el borde físico de la pantalla,
          // por lo que en celulares con navegación por botones la barra
          // de la app terminaba superpuesta con la barra del sistema.
          // El "minimum" de 20 dejaba muy poco aire visualmente en
          // celulares con navegación de 3 botones (que no siempre suman
          // tanto padding seguro como la navegación por gestos) — se
          // sube a 32 para que quede claramente separada.
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _GlassBottomNavBar(
              tabs: _tabs,
              indiceSeleccionado: _tabActual,
              onTap: (i) => setState(() => _tabActual = i),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabInfo {
  final IconData icono;
  final String label;
  final Color color;
  const _TabInfo({
    required this.icono,
    required this.label,
    required this.color,
  });
}

class _BadgePlan extends StatelessWidget {
  final bool esPremium;
  const _BadgePlan({required this.esPremium});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: esPremium
            ? const Color(0xFFFFB800)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        esPremium ? 'PREMIUM' : 'FREE',
        style: TextStyle(
          color: esPremium ? Colors.black : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GlassBottomNavBar extends StatelessWidget {
  final List<_TabInfo> tabs;
  final int indiceSeleccionado;
  final ValueChanged<int> onTap;

  const _GlassBottomNavBar({
    required this.tabs,
    required this.indiceSeleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(tabs.length, (i) {
              final seleccionado = i == indiceSeleccionado;
              final tab = tabs[i];
              // Color de texto/ícono con buen contraste sobre el color
              // del tab (blanco sobre colores saturados que usamos aquí).
              final colorContenido = seleccionado
                  ? Colors.white
                  : Colors.white70;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: seleccionado ? 16 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    // Cada tab usa su propio color acorde a su nombre/función
                    // cuando está seleccionado.
                    color: seleccionado ? tab.color : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icono,
                        color: seleccionado ? Colors.white : Colors.white54,
                        size: 22,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: seleccionado
                            ? Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  tab.label,
                                  style: TextStyle(
                                    color: colorContenido,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : const SizedBox(width: 0),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Widget child;
  const _Tarjeta({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: child,
    );
  }
}

Widget _proximamente(String titulo, String bloque, {String detalle = ''}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _Tarjeta(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.construction,
              color: Color.fromARGB(255, 0, 60, 255),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              '$titulo llega en el $bloque',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (detalle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget _paywall(BuildContext context, String funcion, User user) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _Tarjeta(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFFFFB800), size: 36),
            const SizedBox(height: 12),
            Text(
              '$funcion es una función Premium',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Actualiza tu plan para desbloquearla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PagoPremiumPage(user: user),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Actualizar a Premium',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TabRendimiento extends StatelessWidget {
  final bool esPremium;
  final User user;
  const _TabRendimiento({required this.esPremium, required this.user});

  @override
  Widget build(BuildContext context) {
    if (!esPremium) return _paywall(context, 'Panel de rendimiento', user);
    return const RendimientoPage();
  }
}

class _TabCursos extends StatelessWidget {
  const _TabCursos();
  @override
  Widget build(BuildContext context) => const ExplorarPage();
}

class _TabExamenes extends StatelessWidget {
  const _TabExamenes();
  @override
  Widget build(BuildContext context) => const ExamenesPage();
}

class _TabPerfil extends StatelessWidget {
  final bool esAdmin;
  final VoidCallback onCerrarSesion;

  const _TabPerfil({required this.esAdmin, required this.onCerrarSesion});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null)
            StreamBuilder<DocumentSnapshot>(
              // StreamBuilder (no Future) para que si un admin aprueba tu
              // pago mientras tienes la app abierta, el plan se actualice
              // solo, sin que tengas que recargar la pantalla.
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                return _PerfilCard(data: data, user: user);
              },
            ),
          const SizedBox(height: 16),

          if (esAdmin) ...[
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPagosPendientesPage(),
                ),
              ),
              child: _Tarjeta(
                child: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFFFFB800),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Panel de administración — pagos pendientes',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCerrarSesion,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Datos reales del alumno: nombre, correo, carrera, y su plan con fecha
/// de vencimiento si es Premium (o un botón para mejorar si es Free).
class _PerfilCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final User user;
  const _PerfilCard({required this.data, required this.user});

  String _formatearFecha(DateTime d) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (data['nombre'] as String?)?.trim();
    final correo = (data['correo'] as String?) ?? user.email ?? '';
    final carrera = (data['carrera'] as String?)?.trim();
    final plan = data['plan'] as String? ?? 'free';
    final esPremium = plan == 'premium';
    final premiumHasta = data['premium_hasta'] as Timestamp?;
    final rutaIniciadaEn = data['rutaIniciadaEn'] as Timestamp?;

    final tieneNombre = nombre != null && nombre.isNotEmpty;
    final inicial = tieneNombre
        ? nombre[0].toUpperCase()
        : (correo.isNotEmpty ? correo[0].toUpperCase() : '?');

    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFB800), Color(0xFFFF8A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tieneNombre ? nombre : 'Sin nombre registrado',
                      style: TextStyle(
                        color: tieneNombre ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontStyle: tieneNombre
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      correo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    if (carrera != null && carrera.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        carrera,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: esPremium
                  ? const Color(0xFFFFB800).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: esPremium
                    ? const Color(0xFFFFB800).withValues(alpha: 0.3)
                    : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  esPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_outline,
                  color: esPremium ? const Color(0xFFFFB800) : Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esPremium
                        ? 'Premium'
                              '${premiumHasta != null ? ' · vence ${_formatearFecha(premiumHasta.toDate())}' : ''}'
                        : 'Plan Free',
                    style: TextStyle(
                      color: esPremium
                          ? const Color(0xFFFFB800)
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!esPremium)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagoPremiumPage(user: user),
                      ),
                    ),
                    child: const Text(
                      'Mejorar →',
                      style: TextStyle(
                        color: Color(0xFFFFB800),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (esPremium && rutaIniciadaEn != null) ...[
            const SizedBox(height: 10),
            Text(
              'Estudiando desde el ${_formatearFecha(rutaIniciadaEn.toDate())}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
