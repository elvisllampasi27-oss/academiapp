import 'dart:ui';
import 'package:app_movil/complete_profile.dart';
import 'package:app_movil/home.dart';
import 'package:app_movil/plan_selection_page.dart';
import 'package:app_movil/services/auth.dart';
import 'package:app_movil/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app_movil/singup.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _cargando = false;
  bool _cargandoGoogle = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // mejor true
      body: Stack(
        children: [
          // Fondo
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset('images/imagen1.jpeg', fit: BoxFit.cover),
          ),

          // Contenido completo scrollable
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== TEXTO SUPERIOR =====
                  const Text(
                    "Bienvenido a Rafael's App",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    "¡Comienza tu viaje hoy!",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ===== TARJETA GLASS =====
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color.fromARGB(31, 56, 62, 150),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 0.6,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Hola, Bienvenido! 👋",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Text(
                                "Aquí puedes empezar sesión.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // INPUT CORREO
                              _buildInputField(
                                hintText: "Correo electrónico",
                                controller: _correoController,
                              ),

                              const SizedBox(height: 16),

                              // INPUT CONTRASEÑA
                              _buildInputField(
                                hintText: "Contraseña",
                                obscureText: true,
                                controller: _passwordController,
                              ),

                              const SizedBox(height: 16),

                              // MENSAJE DE ERROR
                              if (_error != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.5,
                                      ),
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

                              // BOTÓN INICIAR SESIÓN
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _cargando
                                      ? null
                                      : () async {
                                          final correo = _correoController.text
                                              .trim();
                                          final pass = _passwordController.text
                                              .trim();

                                          if (correo.isEmpty || pass.isEmpty) {
                                            setState(
                                              () => _error =
                                                  'Completa todos los campos',
                                            );
                                            return;
                                          }

                                          setState(() {
                                            _cargando = true;
                                            _error = null;
                                          });

                                          try {
                                            await AuthMethods().iniciarSesion(
                                              correo,
                                              pass,
                                            );
                                            if (!context.mounted) return;
                                            Navigator.pushReplacement(
                                              context,
                                              PageRouteBuilder(
                                                transitionDuration:
                                                    const Duration(
                                                      milliseconds: 500,
                                                    ),
                                                pageBuilder:
                                                    (context, animation, _) =>
                                                        FadeTransition(
                                                          opacity: animation,
                                                          child: const Home(),
                                                        ),
                                              ),
                                            );
                                          } on FirebaseAuthException catch (e) {
                                            setState(() {
                                              _error = switch (e.code) {
                                                'user-not-found' =>
                                                  'No existe una cuenta con ese correo',
                                                'wrong-password' =>
                                                  'Contraseña incorrecta',
                                                'invalid-email' =>
                                                  'El correo no tiene formato válido',
                                                'invalid-credential' =>
                                                  'Correo o contraseña incorrectos',
                                                'too-many-requests' =>
                                                  'Demasiados intentos. Espera un momento',
                                                'user-disabled' =>
                                                  'Esta cuenta ha sido deshabilitada',
                                                _ => 'Error: ${e.message}',
                                              };
                                            });
                                          } finally {
                                            if (mounted) {
                                              setState(() => _cargando = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 0.6,
                                      ),
                                    ),
                                  ),
                                  child: _cargando
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "Iniciar sesión",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // RECUPERAR CONTRASEÑA
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  const Text(
                                    "¿Olvidaste tu contraseña? ",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final correo = _correoController.text
                                          .trim();
                                      if (correo.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Ingresa tu correo primero",
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      AuthMethods().recuperarPassword(correo);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Correo de recuperación enviado",
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Recupérala aquí",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== DIVISOR GOOGLE =====
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          "O inicia con",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ===== BOTÓN GOOGLE =====
                  GestureDetector(
                    onTap: () async {
                      if (_cargandoGoogle) return;
                      setState(() => _cargandoGoogle = true);

                      final user = await AuthMethods().signInConGoogle();
                      if (!context.mounted) return;
                      if (user == null) {
                        setState(() => _cargandoGoogle = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "No se pudo iniciar sesión con Google",
                            ),
                          ),
                        );
                        return;
                      }

                      final destino = await DatabaseMethods().destinoPostGoogle(
                        user.uid,
                      );
                      if (!context.mounted) return;

                      final Widget siguiente = switch (destino) {
                        DestinoPostGoogle.completarPerfil =>
                          CompleteProfilePage(user: user),
                        DestinoPostGoogle.elegirPlan => PlanSelectionPage(
                          user: user,
                        ),
                        DestinoPostGoogle.home => const Home(),
                      };

                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 500),
                          pageBuilder: (context, animation, _) =>
                              FadeTransition(
                                opacity: animation,
                                child: siguiente,
                              ),
                        ),
                      );
                      // No hace falta setState(_cargandoGoogle = false) aquí:
                      // la pantalla ya se está reemplazando.
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 0.6,
                        ),
                      ),
                      child: _cargandoGoogle
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'images/googleImagen.png',
                                  width: 24,
                                  height: 24,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "Continuar con Google",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== DIVISOR REGISTRO =====
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          "¿No tienes una cuenta?",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ===== BOTÓN REGISTRO =====
                  GestureDetector(
                    onTap: () {
                      // Ir a pantalla de registro
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 500),
                          pageBuilder:
                              (context, animation, secondaryAnimation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: const SignUp(),
                                );
                              },
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 0.6,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "Registrarse aquí",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String hintText,
    bool obscureText = false,
    TextEditingController? controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
