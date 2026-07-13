import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class YapePaymentPage extends StatefulWidget {
  final double monto;

  const YapePaymentPage({super.key, required this.monto});

  @override
  State<YapePaymentPage> createState() => _YapePaymentPageState();
}

class _YapePaymentPageState extends State<YapePaymentPage> {
  File? _comprobante;
  bool _loading = false;
  // Progreso de subida: 0.0 a 1.0
  double _progreso = 0.0;
  String _estado = '';

  Future<void> _seleccionarImagen() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // comprime un poco sin perder legibilidad
      maxWidth: 1920,
    );
    if (picked != null) {
      setState(() {
        _comprobante = File(picked.path);
        _estado = '';
      });
    }
  }

  Future<void> _enviarPago() async {
    if (_comprobante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona el comprobante primero")),
      );
      return;
    }

    setState(() {
      _loading = true;
      _progreso = 0.0;
      _estado = 'Subiendo comprobante...';
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // ── 1. Subir imagen a Firebase Storage ──────────────────────────────
      // Ruta: comprobantes/{uid}/{timestamp}.jpg
      // Así cada pago tiene su propio archivo y no se sobreescriben
      final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('comprobantes')
          .child(uid)
          .child(nombreArchivo);

      final uploadTask = storageRef.putFile(
        _comprobante!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Escuchar progreso real de subida
      uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
        if (!mounted) return;
        setState(() {
          _progreso = snap.bytesTransferred / snap.totalBytes;
        });
      });

      // Esperar a que termine la subida
      await uploadTask;

      // ── 2. Obtener URL pública de descarga ───────────────────────────────
      final comprobanteUrl = await storageRef.getDownloadURL();

      setState(() => _estado = 'Registrando pago...');

      // ── 3. Guardar en Firestore CON la URL del comprobante ───────────────
      await FirebaseFirestore.instance.collection('pagos').add({
        'uid': uid,
        'monto': widget.monto,
        'metodo': 'yape',
        'estado': 'pendiente',
        'comprobanteUrl': comprobanteUrl, // ← URL real en Storage
        'storagePath': storageRef.fullPath, // ← ruta para borrar si se rechaza
        'fecha': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pago enviado — revisaremos tu comprobante pronto"),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _progreso = 0.0;
        _estado = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al enviar el pago: ${e.message}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          "Pagar con Yape",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Monto ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Text(
                    "Monto a pagar",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "S/ ${widget.monto.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Color(0xFFFFB800),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Yapear al número:",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "979 791 085",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Selector de comprobante ──────────────────────────────────
            GestureDetector(
              onTap: _loading ? null : _seleccionarImagen,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _comprobante != null
                        ? const Color(0xFF4CAF50)
                        : Colors.white12,
                    width: _comprobante != null ? 1.5 : 0.8,
                  ),
                ),
                child: _comprobante != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_comprobante!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_rounded,
                            color: Colors.white24,
                            size: 36,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Toca para subir el comprobante",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Captura de pantalla del Yape",
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Barra de progreso (visible solo al subir) ────────────────
            if (_loading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progreso > 0 ? _progreso : null,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFFFB800),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _progreso > 0
                    ? '$_estado  ${(_progreso * 100).toStringAsFixed(0)}%'
                    : _estado,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // ── Botón confirmar ──────────────────────────────────────────
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _enviarPago,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const Text(
                        "Enviando...",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white38,
                        ),
                      )
                    : const Text(
                        "Confirmar pago",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
