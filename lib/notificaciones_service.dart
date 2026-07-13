import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Handler de mensajes en segundo plano/app cerrada. DEBE ser una función
/// top-level (no un método de clase) y se registra en main.dart ANTES de
/// runApp(). Con la app en background o cerrada, el sistema operativo ya
/// muestra la notificación solo (no hace falta código acá para eso) —
/// esta función corre además, por si quieres reaccionar a datos extra.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Sin lógica por ahora — el sistema ya muestra la notificación.
}

/// Servicio de notificaciones push (Bloque 9). Llamar a `inicializar()`
/// una vez que el usuario ya inició sesión (por ejemplo, en el initState
/// de Home) — no antes, porque necesita el uid para guardar el token.
class NotificacionesService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> inicializar(BuildContext context) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // El usuario dijo que no — respetamos su decisión, no insistimos.
      return;
    }

    await _guardarToken();
    _messaging.onTokenRefresh.listen((_) => _guardarToken());

    // Mensaje que llega con la app ABIERTA en primer plano: el sistema no
    // muestra nada solo en este caso, así que mostramos un banner simple.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1A1A),
          content: Row(
            children: [
              const Icon(Icons.notifications, color: Color(0xFFFFB800)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (notification.body != null)
                      Text(
                        notification.body!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  static Future<void> _guardarToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// Llamar al cerrar sesión, para no seguirle mandando notificaciones a
  /// este dispositivo a nombre de una cuenta con la que ya no está.
  static Future<void> limpiarTokenAlCerrarSesion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }
}
