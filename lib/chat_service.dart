import 'package:cloud_functions/cloud_functions.dart';
import 'package:app_movil/models/chat_message.dart';

/// Chat con tutor IA, contextual por tema (transcripción del video +
/// material PDF). Ya no llama a Gemini directo desde el cliente — todo
/// pasa por Cloud Functions (functions/index.js), que verifican el plan
/// Premium en el backend y guardan la llave de Gemini en Secret Manager.
class ChatService {
  /// Llamar al ABRIR el chat, antes del primer mensaje: dispara (si hace
  /// falta) la extracción de transcripción/PDF de este tema en el
  /// backend. Si ya se generó antes, no hace nada (rápido).
  Future<void> prepararContexto({
    required String cursoId,
    required String temaId,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('prepararContextoTema').call(
      {'cursoId': cursoId, 'temaId': temaId},
    );
  }

  Future<String> getResponse({
    required String cursoId,
    required String temaId,
    required String mensaje,
    required List<ChatMessage> historial,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'procesarPreguntaChatVideo',
      );
      final result = await callable.call({
        'cursoId': cursoId,
        'temaId': temaId,
        'mensaje': mensaje,
        'historial': historial
            .map((m) => {'text': m.text, 'isUser': m.isUser})
            .toList(),
      });
      return (result.data as Map)['respuesta'] as String? ??
          'Lo siento, no pude procesar eso.';
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        return 'El chat con tutor IA es una función Premium.';
      }
      return 'AcademiBot no está disponible en este momento. '
          'Por favor intenta más tarde.';
    } catch (e) {
      return 'Error al conectar con AcademiBot: $e';
    }
  }
}
