import 'package:cloud_firestore/cloud_firestore.dart';

/// A qué pantalla debe ir un usuario justo después de autenticarse con
/// Google, según lo que ya exista (o no) en su documento de Firestore.
enum DestinoPostGoogle { completarPerfil, elegirPlan, home }

class DatabaseMethods {
  final _usersRef = FirebaseFirestore.instance.collection("users");

  // Reutilizado tal cual del original: escritura genérica. Se deja por
  // compatibilidad, pero desde el Bloque 1 el alta de usuario nuevo debe
  // pasar por crearPerfilConPlan(), que es la que respeta firestore.rules
  // (el documento tiene que nacer con "plan" incluido).
  Future<void> addUserInfoToDB(
    String userId,
    Map<String, dynamic> userInfoMap,
  ) async {
    return await _usersRef.doc(userId).set(userInfoMap, SetOptions(merge: true));
  }

  /// Alta atómica de un usuario nuevo: perfil + plan en una sola escritura.
  /// [datosPerfil] trae nombre/correo/carrera/fechaNacimiento/uid (ya
  /// recolectados por singup.dart o complete_profile.dart, todavía no
  /// persistidos). [plan] solo debería llegar como "free" desde el cliente:
  /// firestore.rules rechaza cualquier otro valor en el create.
  Future<void> crearPerfilConPlan({
    required String userId,
    required Map<String, dynamic> datosPerfil,
    required String plan,
  }) async {
    final data = {
      ...datosPerfil,
      "uid": userId,
      "plan": plan,
      "premium_hasta": null,
      "ultimo_bloque_examen_abierto": null,
    };
    await _usersRef.doc(userId).set(data);
  }

  /// Reparación única para documentos que ya existían sin "plan" (datos de
  /// prueba de seed_firestore.dart o cuentas creadas antes del Bloque 1).
  /// firestore.rules solo permite este update si resource.data.plan == null;
  /// si el usuario ya tiene plan asignado, esto no debería llamarse.
  Future<void> autoRepararPlanFaltante(String userId) async {
    await _usersRef.doc(userId).update({
      "plan": "free",
      "premium_hasta": null,
      "ultimo_bloque_examen_abierto": null,
    });
  }

  Future<Map<String, dynamic>?> obtenerUsuario(String userId) async {
    final doc = await _usersRef.doc(userId).get();
    return doc.data();
  }

  /// Se llama justo después de un signInConGoogle() exitoso. Decide, de
  /// forma explícita (sin depender de la reactividad del StreamBuilder raíz
  /// una vez que ya hay rutas empujadas encima), a qué pantalla navegar.
  Future<DestinoPostGoogle> destinoPostGoogle(String userId) async {
    final data = await obtenerUsuario(userId);
    final tieneNombre =
        data != null && (data['nombre'] ?? '').toString().isNotEmpty;
    final tienePlan = data != null && data['plan'] != null;
    if (!tieneNombre) return DestinoPostGoogle.completarPerfil;
    if (!tienePlan) return DestinoPostGoogle.elegirPlan;
    return DestinoPostGoogle.home;
  }
}
