import 'dart:ui';
import 'package:app_movil/home.dart';
import 'package:app_movil/pago_premium_page.dart';
import 'package:app_movil/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Pantalla "Elige tu plan".
///
/// Dos modos de uso:
/// - Alta nueva: [datosPerfilPendiente] trae el perfil recién recolectado
///   (aún no escrito en Firestore). Elegir Free hace la escritura atómica
///   perfil + plan. Premium navega al placeholder de pago (Bloque 2).
/// - Reparación: [datosPerfilPendiente] es null porque el documento del
///   usuario YA existe en Firestore pero le falta "plan" (cuentas legacy o
///   datos de seed_firestore.dart). Elegir Free solo completa el campo.
class PlanSelectionPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? datosPerfilPendiente;

  const PlanSelectionPage({
    super.key,
    required this.user,
    this.datosPerfilPendiente,
  });

  @override
  State<PlanSelectionPage> createState() => _PlanSelectionPageState();
}

class _PlanSelectionPageState extends State<PlanSelectionPage> {
  bool _cargando = false;
  String? _error;

  Future<void> _elegirFree() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (widget.datosPerfilPendiente != null) {
        await DatabaseMethods().crearPerfilConPlan(
          userId: widget.user.uid,
          datosPerfil: widget.datosPerfilPendiente!,
          plan: "free",
        );
      } else {
        await DatabaseMethods().autoRepararPlanFaltante(widget.user.uid);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, _) =>
              FadeTransition(opacity: animation, child: const Home()),
        ),
      );
    } catch (e) {
      setState(() => _error = "No se pudo guardar tu plan. Intenta de nuevo.");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _elegirPremium() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: PagoPremiumPage(
            user: widget.user,
            datosPerfilPendiente: widget.datosPerfilPendiente,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset('images/imagen1.jpeg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Elige tu plan",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Puedes cambiar de plan cuando quieras",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  _buildPlanCard(
                    titulo: "Free",
                    subtitulo: "Para empezar sin costo",
                    features: const [
                      "Cursos: video, sin chat ni quiz",
                      "Exámenes pasados: 1 bloque por día",
                      "Sin Panel de rendimiento",
                      "Sin Exámenes tipo admisión",
                    ],
                    botonTexto: "Continuar gratis",
                    onTap: _cargando ? null : _elegirFree,
                    cargando: _cargando,
                    destacado: false,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    titulo: "Premium",
                    subtitulo: "Acceso completo",
                    features: const [
                      "Cursos: video + chat contextual + quiz adaptativo",
                      "Exámenes pasados: sin límite diario",
                      "Exámenes tipo admisión (simulacro cronometrado)",
                      "Panel de rendimiento por tema",
                    ],
                    botonTexto: "Quiero Premium",
                    onTap: _cargando ? null : _elegirPremium,
                    cargando: false,
                    destacado: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String titulo,
    required String subtitulo,
    required List<String> features,
    required String botonTexto,
    required VoidCallback? onTap,
    required bool cargando,
    required bool destacado,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: destacado
                ? const Color.fromARGB(60, 255, 184, 0)
                : const Color.fromARGB(31, 56, 62, 150),
            border: Border.all(
              color: destacado
                  ? const Color(0xFFFFB800)
                  : Colors.white.withValues(alpha: 0.6),
              width: destacado ? 1.2 : 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 14),
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destacado
                          ? const Color(0xFFFFB800)
                          : Colors.white.withValues(alpha: 0.2),
                      foregroundColor: destacado ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: cargando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            botonTexto,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
