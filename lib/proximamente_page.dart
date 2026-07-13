import 'package:flutter/material.dart';

/// Placeholder genérico para módulos que todavía no están construidos.
/// Se retira cuando el bloque correspondiente (4, 5, 6 o 7) se construya:
/// simplemente se cambia la navegación en home.dart para apuntar a la
/// pantalla real en vez de esta.
class ProximamentePage extends StatelessWidget {
  final String titulo;
  final String bloque;
  final String descripcion;

  const ProximamentePage({
    super.key,
    required this.titulo,
    required this.bloque,
    this.descripcion = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text(titulo),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction,
                color: Color(0xFFFFB800),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '$titulo llega en el $bloque',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (descripcion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  descripcion,
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
}
