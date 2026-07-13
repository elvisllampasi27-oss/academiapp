import 'dart:ui';
import 'package:app_movil/complete_profile.dart';
import 'package:app_movil/home.dart';
import 'package:app_movil/plan_selection_page.dart';
import 'package:app_movil/services/auth.dart';
import 'package:app_movil/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _fechaNacimiento;
  String? _carreraSeleccionada;
  String? _errorPassword;
  bool _cargando = false;
  bool _cargandoGoogle = false;

  final List<String> _carreras = [
    'Ingeniería de Sistemas',
    'Ingeniería Civil',
    'Ingeniería En Industrias Alimentarias',
    'Ingeniería Agroindustrial',
    'Ingeniería de Minas',
    'Administración de Empresas',
    'Agronomía',
    'Ingeniería Ambiental',
    'Ingeniería Agrícola',
    'Ingeniería Agroindustrial',
    'Ingeniería Agroforestal',
    'Ingeniería Química',
    'Ciencias Físico Matemático',
    'Contabilidad y Auditoría',
    'Economía',

    'Arquitectura',
    'Educación Inicial',
    'Educación Primaria',
    'Educación Secundaria',
    'Educación Física',
    'Derecho',
    'Trabajo Social',
    'Antropología Social',
    'Ciencias de la Comunicación',
    'Arqueología e História',

    'Biología',
    'Psicología',
    'Enfermería',
    'Medicina Humana',
    'Obstetricia',
    'Farmacia y Bioquímica',
    'Medicina Veterinaria',
  ];

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaNacimiento =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  void _registrar() async {
    if (_cargando) return; // evita doble-tap mientras ya está registrando

    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final correo = _correoController.text.trim();
    final nombre = _nombreController.text.trim();

    final emailValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo);

    if (nombre.isEmpty) {
      setState(() => _errorPassword = 'Ingresa tu nombre completo');
      return;
    }
    if (!emailValido) {
      setState(() => _errorPassword = 'Ingresa un correo válido');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _errorPassword = 'La contraseña debe tener al menos 6 caracteres',
      );
      return;
    }
    if (password != confirm) {
      setState(() => _errorPassword = 'Las contraseñas no coinciden');
      return;
    }
    if (_carreraSeleccionada == null) {
      setState(() => _errorPassword = 'Selecciona tu carrera profesional');
      return;
    }
    if (_fechaNacimiento == null) {
      setState(() => _errorPassword = 'Selecciona tu fecha de nacimiento');
      return;
    }

    setState(() {
      _errorPassword = null;
      _cargando = true;
    });

    try {
      final user = await AuthMethods().registrarUsuario(correo, password);
      if (user == null) {
        if (mounted) {
          setState(
            () => _errorPassword =
                'No se pudo crear la cuenta. Intenta de nuevo.',
          );
        }
        return;
      }

      // Perfil recolectado, TODAVÍA no se escribe en Firestore: la escritura
      // atómica (perfil + plan) la hace PlanSelectionPage al elegir plan.
      Map<String, dynamic> datosPerfilPendiente = {
        "nombre": nombre,
        "correo": correo,
        "carrera": _carreraSeleccionada ?? "",
        "fechaNacimiento": _fechaNacimiento ?? "",
      };

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, _) => FadeTransition(
            opacity: animation,
            child: PlanSelectionPage(
              user: user,
              datosPerfilPendiente: datosPerfilPendiente,
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorPassword = switch (e.code) {
          'email-already-in-use' => 'Ya existe una cuenta con ese correo',
          'invalid-email' => 'El correo no tiene un formato válido',
          'weak-password' => 'La contraseña es demasiado débil',
          'operation-not-allowed' =>
            'El registro por correo no está habilitado. Contacta al administrador',
          _ => 'Error: ${e.message}',
        };
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Fondo
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
                    "Bienvenido a Rafael's App",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                                "Crea tu cuenta ",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Nombre completo
                              _buildInputField(
                                hintText: "Nombre completo",
                                controller: _nombreController,
                              ),
                              const SizedBox(height: 16),

                              // Correo
                              _buildInputField(
                                hintText: "Correo electrónico",
                                controller: _correoController,
                              ),
                              const SizedBox(height: 16),

                              // Contraseña
                              _buildInputField(
                                hintText: "Contraseña",
                                controller: _passwordController,
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),

                              // Confirmar contraseña
                              _buildInputField(
                                hintText: "Confirmar contraseña",
                                controller: _confirmPasswordController,
                                obscureText: true,
                              ),

                              // Error contraseña
                              if (_errorPassword != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _errorPassword!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Carrera profesional (dropdown)
                              _buildDropdownCarrera(),
                              const SizedBox(height: 16),

                              // Fecha de nacimiento (date picker)
                              _buildFechaNacimiento(context),
                              const SizedBox(height: 24),

                              // Botón registrar
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _cargando ? null : _registrar,
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
                                          "Crear cuenta",
                                          style: TextStyle(
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
                  ),

                  const SizedBox(height: 20),

                  // Divisor
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
                          style: TextStyle(color: Colors.white),
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

                  // Botón Google
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
                                  "Registrarse con Google",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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

  // ===== CAMPO DE TEXTO GENÉRICO =====
  Widget _buildInputField({
    required String hintText,
    TextEditingController? controller,
    bool obscureText = false,
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

  // ===== DROPDOWN CARRERA =====
  Widget _buildDropdownCarrera() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _carreraSeleccionada,
          hint: Text(
            "Carrera profesional",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          dropdownColor: const Color.fromARGB(
            255,
            115,
            115,
            230,
          ).withValues(alpha: 0.9),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: _carreras.map((carrera) {
            return DropdownMenuItem<String>(
              value: carrera,
              child: Text(carrera),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _carreraSeleccionada = value;
            });
          },
        ),
      ),
    );
  }

  // ===== DATE PICKER FECHA DE NACIMIENTO =====
  Widget _buildFechaNacimiento(BuildContext context) {
    return GestureDetector(
      onTap: () => _seleccionarFecha(context),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fechaNacimiento ?? "Fecha de nacimiento",
              style: TextStyle(
                color: _fechaNacimiento != null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            Icon(
              Icons.calendar_today,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
