import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Texto con soporte de LaTeX inline ($formula$). No usa markdown completo
/// a propósito — para preguntas de examen/quiz es texto simple + fórmulas,
/// nada más. Compartido entre exámenes (JSON subido por el admin) y el
/// quiz generado por IA (Gemini), para no tener dos copias del mismo
/// parser desincronizándose con el tiempo.
class TextoConLatex extends StatelessWidget {
  final String texto;
  final Color? color;
  final double fontSize;
  final FontWeight? fontWeight;

  const TextoConLatex({
    super.key,
    required this.texto,
    this.color,
    this.fontSize = 14,
    this.fontWeight,
  });

  TextStyle get _estilo => TextStyle(
    color: color ?? Colors.white,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: 1.5,
  );

  @override
  Widget build(BuildContext context) {
    if (!texto.contains(r'$')) {
      return Text(texto, style: _estilo);
    }

    final pattern = RegExp(r'\$([^$\n]+?)\$');
    final spans = <InlineSpan>[];
    int last = 0;

    for (final m in pattern.allMatches(texto)) {
      if (m.start > last) {
        spans.add(TextSpan(text: texto.substring(last, m.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            m.group(1)!,
            textStyle: _estilo,
            onErrorFallback: (_) => Text(
              m.group(1)!,
              style: _estilo.copyWith(
                color: Colors.orangeAccent,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
      last = m.end;
    }
    if (last < texto.length) {
      spans.add(TextSpan(text: texto.substring(last)));
    }

    return RichText(text: TextSpan(style: _estilo, children: spans));
  }
}
