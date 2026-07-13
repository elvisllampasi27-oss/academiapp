import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // google_sign_in v7 es un singleton: GoogleSignIn.instance.initialize()
  // debe llamarse UNA vez antes de usar cualquier otro método. Se hace de
  // forma perezosa aquí (en vez de en main.dart) para no tocar el Bloque 0.
  static bool _googleInicializado = false;
  static Future<void> _asegurarGoogleInicializado() async {
    if (_googleInicializado) return;
    await GoogleSignIn.instance.initialize();
    _googleInicializado = true;
  }

  // REGISTRO
  // No atrapa FirebaseAuthException a propósito: la pantalla que llama
  // (singup.dart) necesita el código de error real (email-already-in-use,
  // weak-password, etc.) para mostrar un mensaje específico.
  Future<User?> registrarUsuario(String correo, String password) async {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: correo,
      password: password,
    );
    return result.user;
  }

  // INICIO DE SESIÓN
  Future<User> iniciarSesion(String correo, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: correo,
      password: password,
    );
    return result.user!;
  }

  // GOOGLE SIGN-IN (API v7)
  // Devuelve null si el usuario cancela el picker; relanza cualquier otro
  // error para que la pantalla que llama decida qué mostrar.
  Future<User?> signInConGoogle() async {
    try {
      await _asegurarGoogleInicializado();

      // 1. Autenticación (identidad) — abre el selector de cuenta.
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      // 2. Autorización (permisos) — necesaria en v7 para obtener accessToken.
      final GoogleSignInClientAuthorization clientAuth = await googleUser
          .authorizationClient
          .authorizeScopes(['email']);

      // 3. Credencial de Firebase con idToken (síncrono en v7) + accessToken.
      final credential = GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
        accessToken: clientAuth.accessToken,
      );

      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );
      return result.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // Usuario cerró el selector de cuenta: no es un error real.
        return null;
      }
      debugPrint("Error Google Sign-In: ${e.code} ${e.description}");
      return null;
    } catch (e) {
      debugPrint("Error Google Sign-In: $e");
      return null;
    }
  }

  // RECUPERAR CONTRASEÑA
  Future<void> recuperarPassword(String correo) async {
    try {
      await _auth.sendPasswordResetEmail(email: correo);
    } catch (e) {
      debugPrint("Error al recuperar contraseña: $e");
    }
  }

  // CERRAR SESIÓN
  Future<void> cerrarSesion() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
