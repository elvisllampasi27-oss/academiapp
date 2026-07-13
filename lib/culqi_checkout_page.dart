import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// TODO: reemplaza por tu llave PÚBLICA real de Culqi
// (CulqiPanel > Desarrollo > API Keys). La llave pública es segura de
// embeber en el cliente — la llave SECRETA nunca va aquí, solo en la
// Cloud Function (functions/index.js) vía Secret Manager.
const String _culqiPublicKey = 'pk_test_C7dDH5VA7JhGTFd8';

// Solo para mostrar el precio en pantalla. El monto que realmente se
// cobra lo decide procesarPagoCulqi en el backend — debe coincidir con
// PRECIO_SOLES de functions/index.js, pero aunque no coincidiera, el
// backend manda: nadie puede pagar menos manipulando la app.
const int _precioSolesReferencial = 29;

/// TODO: Culqi anunció el retiro de "Checkout v4" (el que usa este archivo)
/// en favor de "Checkout Custom". v4 sigue funcionando hoy, pero conviene
/// revisar el estado en CulqiPanel antes de ir a producción y migrar si
/// ya no está disponible.
class CulqiCheckoutPage extends StatefulWidget {
  final User user;
  const CulqiCheckoutPage({super.key, required this.user});

  @override
  State<CulqiCheckoutPage> createState() => _CulqiCheckoutPageState();
}

class _CulqiCheckoutPageState extends State<CulqiCheckoutPage> {
  late final WebViewController _controller;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A0A))
      ..addJavaScriptChannel('CulqiChannel', onMessageReceived: _onCulqiMessage)
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    final amountCents = _precioSolesReferencial * 100;
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>html,body{margin:0;padding:0;height:100%;background:#0A0A0A;}</style>
</head>
<body>
<script src="https://checkout.culqi.com/js/v4"></script>
<script>
  Culqi.publicKey = '$_culqiPublicKey';
  Culqi.settings({
    title: 'AcademiApp Premium',
    currency: 'PEN',
    amount: $amountCents,
    description: 'Suscripcion Premium AcademiApp (90 dias)'
  });
  Culqi.options({
    lang: 'auto',
    installments: false,
    paymentMethods: {
      tarjeta: true,
      yape: true,
      bancaMovil: false,
      agente: false,
      billetera: false,
      cuotealo: false
    }
  });
  function culqi() {
    if (Culqi.token) {
      CulqiChannel.postMessage(JSON.stringify({
        status: 'token', id: Culqi.token.id, email: Culqi.token.email
      }));
    } else {
      CulqiChannel.postMessage(JSON.stringify({
        status: 'error', error: Culqi.error
      }));
    }
  }
  Culqi.culqi = culqi;
  window.addEventListener('load', function () { Culqi.open(); });
</script>
</body>
</html>
''';
  }

  Future<void> _onCulqiMessage(JavaScriptMessage message) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (data['status'] == 'error') {
      setState(
        () => _error = 'No se pudo generar el token de pago. Intenta de nuevo.',
      );
      return;
    }

    if (data['status'] == 'token') {
      final tokenId = data['id'] as String?;
      if (tokenId == null) return;
      await _procesarPago(tokenId);
    }
  }

  Future<void> _procesarPago(String tokenId) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'procesarPagoCulqi',
      );
      final result = await callable.call({'tokenId': tokenId});
      final ok = (result.data as Map)['ok'] == true;
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true); // true = pago exitoso
      } else {
        setState(() => _error = 'El pago no pudo procesarse.');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.code) {
          'failed-precondition' =>
            'El pago fue rechazado por el banco. Intenta con otra tarjeta.',
          'unauthenticated' => 'Tu sesión expiró. Vuelve a iniciar sesión.',
          _ => 'Error al procesar el pago: ${e.message}',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado al procesar el pago.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Pago Premium'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          if (_procesando)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB800)),
              ),
            ),
        ],
      ),
    );
  }
}
