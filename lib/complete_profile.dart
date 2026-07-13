import 'dart:ui';
import 'package:app_movil/plan_selection_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompleteProfilePage extends StatefulWidget {
  final User user;
  const CompleteProfilePage({super.key, required this.user});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _nombreController = TextEditingController();
  String? _fechaNacimiento;
  String? _carreraSeleccionada;
  String? _error;

  final List<String> _carreras = [
    'Ingeniería de Sistemas',
    'Ingeniería Civil',
    'Ingeniería En Industrias Alimentarias',
    'Ingeniería Agroindustrial',
    'Ingeniería de Minas',
    'Administración de Empresas',
    'Agronomía',
    'Ingenieria Ambiental',
    'Ingenieria Agrícola',
    'Ingeniería Agroinsdustrial',
    'Ingeniería Agroforestal',
    'Ingeniera Química',
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

  Future<void> _seleccionarFecha() async {
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

  void _guardar() async {
    final nombre = _nombreController.text.trim();

    if (nombre.isEmpty ||
        _carreraSeleccionada == null ||
        _fechaNacimiento == null) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }

    Map<String, dynamic> datosPerfilPendiente = {
      "nombre": nombre,
      "correo": widget.user.email ?? "",
      "carrera": _carreraSeleccionada!,
      "fechaNacimiento": _fechaNacimiento!,
    };

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: PlanSelectionPage(
            user: widget.user,
            datosPerfilPendiente: datosPerfilPendiente,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                    "Un último paso 👋",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Completa tu perfil para continuar",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),

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
                              // Correo (solo lectura, viene de Google)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.user.email ?? "",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Nombre completo
                              _buildInputField(
                                hintText: "Nombre completo",
                                controller: _nombreController,
                              ),
                              const SizedBox(height: 16),

                              // Carrera
                              _buildDropdownCarrera(),
                              const SizedBox(height: 16),

                              // Fecha de nacimiento
                              _buildFechaNacimiento(),

                              // Error
                              if (_error != null) ...[
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
                                      _error!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _guardar,
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
                                  child: const Text(
                                    "Guardar y continuar",
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
          dropdownColor: const Color.fromARGB(255, 115, 115, 230),
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
            setState(() => _carreraSeleccionada = value);
          },
        ),
      ),
    );
  }

  Widget _buildFechaNacimiento() {
    return GestureDetector(
      onTap: _seleccionarFecha,
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
