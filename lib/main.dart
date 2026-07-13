import 'package:app_movil/complete_profile.dart';
import 'package:app_movil/firebase_options.dart';
import 'package:app_movil/home.dart';
import 'package:app_movil/login.dart';
import 'package:app_movil/notificaciones_service.dart';
import 'package:app_movil/plan_selection_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcademiApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          if (!snapshot.hasData) return const LogIn();
          // Verifica perfil en Firestore antes de ir a Home
          return _AuthWrapper(user: snapshot.data!);
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFB800),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

// Verifica si el usuario tiene perfil completo en Firestore
class _AuthWrapper extends StatefulWidget {
  final User user;
  const _AuthWrapper({required this.user});
  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  bool _checking = true;
  bool _tienePerfilCompleto = false;
  bool _tienePlan = false;

  @override
  void initState() {
    super.initState();
    _verificarPerfil();
  }

  Future<void> _verificarPerfil() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      final data = doc.data();
      final tieneNombre =
          data != null && (data['nombre'] ?? '').toString().isNotEmpty;
      final tienePlan = data != null && data['plan'] != null;
      setState(() {
        _tienePerfilCompleto = doc.exists && tieneNombre;
        _tienePlan = doc.exists && tienePlan;
        _checking = false;
      });
    } catch (e) {
      setState(() {
        _tienePerfilCompleto = true;
        _tienePlan = true;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();
    if (!_tienePerfilCompleto) return CompleteProfilePage(user: widget.user);
    if (!_tienePlan) return PlanSelectionPage(user: widget.user);
    return const Home();
  }
}
