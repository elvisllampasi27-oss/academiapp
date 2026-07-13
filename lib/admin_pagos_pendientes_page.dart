import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Panel mínimo de aprobación de pagos manuales por Yape.
/// Solo accesible para cuentas con el custom claim admin:true (ver
/// functions/scripts/hacer_admin.js). La protección REAL está en las
/// Cloud Functions (aprobarPagoManual/rechazarPagoManual comprueban el
/// claim); esta pantalla solo se oculta en el cliente por UX.
class AdminPagosPendientesPage extends StatefulWidget {
  const AdminPagosPendientesPage({super.key});

  @override
  State<AdminPagosPendientesPage> createState() =>
      _AdminPagosPendientesPageState();
}

class _AdminPagosPendientesPageState extends State<AdminPagosPendientesPage> {
  String? _procesandoId;

  Future<void> _aprobar(String pagoId) async {
    setState(() => _procesandoId = pagoId);
    try {
      await FirebaseFunctions.instance.httpsCallable('aprobarPagoManual').call({
        'pagoId': pagoId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago aprobado — usuario subido a Premium'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  Future<void> _rechazar(String pagoId) async {
    final motivoController = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar comprobante'),
        content: TextField(
          controller: motivoController,
          decoration: const InputDecoration(
            hintText: 'Motivo (opcional): borroso, monto no coincide, etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, motivoController.text),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (motivo == null) return;

    setState(() => _procesandoId = pagoId);
    try {
      await FirebaseFunctions.instance.httpsCallable('rechazarPagoManual').call(
        {'pagoId': pagoId, 'motivo': motivo},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pago rechazado')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Pagos pendientes (Yape manual)'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pagos')
            .where('estado', isEqualTo: 'pendiente')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB800)),
            );
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay comprobantes pendientes 🎉',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final procesando = _procesandoId == doc.id;

              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['comprobanteUrl'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            data['comprobanteUrl'],
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 100,
                              child: Center(
                                child: Text(
                                  'No se pudo cargar la imagen',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'UID: ${data['uid']}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Monto: S/ ${data['monto']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: procesando
                                  ? null
                                  : () => _rechazar(doc.id),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              child: const Text(
                                'Rechazar',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: procesando
                                  ? null
                                  : () => _aprobar(doc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                              ),
                              child: procesando
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Aprobar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
