import 'package:app_movil/culqi_checkout_page.dart';
import 'package:app_movil/home.dart';
import 'package:app_movil/services/database.dart';
import 'package:app_movil/yape_payment_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Precio mostrado al usuario. Debe coincidir con PRECIO_SOLES de
/// functions/index.js (solo visual: el cobro real siempre lo decide el
/// backend, nunca el cliente).
const int _precioSoles = 29;

class PagoPremiumPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? datosPerfilPendiente;

  const PagoPremiumPage({
    super.key,
    required this.user,
    this.datosPerfilPendiente,
  });

  @override
  State<PagoPremiumPage> createState() => _PagoPremiumPageState();
}

class _PagoPremiumPageState extends State<PagoPremiumPage> {
  bool _cargando = false;

  Future<void> _persistirPerfilSiHaceFalta() async {
    // Si venimos del flujo de alta nueva (singup/complete_profile), el
    // perfil todavía no se escribió en Firestore — hay que crearlo (en
    // "free" por ahora; si el pago tiene éxito, procesarPagoCulqi lo sube
    // a "premium" un instante después). Si el doc ya existía (usuario
    // recurrente que va a Premium), no hace falta tocar nada aquí.
    if (widget.datosPerfilPendiente != null) {
      await DatabaseMethods().crearPerfilConPlan(
        userId: widget.user.uid,
        datosPerfil: widget.datosPerfilPendiente!,
        plan: "free",
      );
    }
  }

  Future<void> _pagarConCulqi() async {
    setState(() => _cargando = true);
    try {
      await _persistirPerfilSiHaceFalta();
      if (!mounted) return;

      final exito = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => CulqiCheckoutPage(user: widget.user)),
      );

      if (!mounted) return;
      if (exito == true) {
        _irAHome();
      }
      // Si exito != true, el usuario canceló o falló el pago: se queda en
      // esta pantalla para reintentar u optar por otro medio.
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _pagarConYapeManual() async {
    setState(() => _cargando = true);
    try {
      await _persistirPerfilSiHaceFalta();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => YapePaymentPage(monto: _precioSoles.toDouble()),
        ),
      );
      // YapePaymentPage solo registra el comprobante en la colección
      // "pagos" con estado "pendiente" — el plan sigue en "free" hasta que
      // un administrador lo apruebe manualmente (Bloque 8). Volvemos a
      // Home igual, con acceso Free mientras se revisa.
      if (!mounted) return;
      _irAHome();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _continuarComoFreePorAhora() async {
    setState(() => _cargando = true);
    try {
      await _persistirPerfilSiHaceFalta();
      if (!mounted) return;
      _irAHome();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _irAHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, _) =>
            FadeTransition(opacity: animation, child: const Home()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Pago Premium"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Premium",
              style: TextStyle(
                color: Color(0xFFFFB800),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "S/ $_precioSoles.00 / 90 días",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cargando ? null : _pagarConCulqi,
                icon: const Icon(Icons.credit_card),
                label: const Text("Pagar con tarjeta o Yape"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cargando ? null : _pagarConYapeManual,
                icon: const Icon(Icons.qr_code, color: Colors.white),
                label: const Text(
                  "Ya yapeé — subir comprobante",
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Se revisa manualmente en 1-2 días. Mientras tanto sigues en plan Free.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),

            const Spacer(),

            if (_cargando)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB800)),
              ),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _cargando ? null : _continuarComoFreePorAhora,
                child: const Text(
                  "Continuar con Free por ahora",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
