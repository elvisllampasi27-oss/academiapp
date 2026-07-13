import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:app_movil/chat_service.dart';
import 'package:app_movil/models/chat_message.dart';

/// Ícono flotante del tutor IA (esquina inferior izquierda) + panel de
/// chat estilo "liquid glass" que crece desde ese ícono. Reemplaza la
/// versión anterior que navegaba a una página completa nueva — ahora es
/// un overlay contextual sobre el mismo tema, sin cambiar de pantalla.
///
/// El panel de chat (_ChatGlassPanel) se mantiene SIEMPRE montado en el
/// árbol de widgets (solo se oculta visualmente con opacidad/escala), así
/// que la conversación persiste mientras sigas en este tema, aunque
/// cierres y vuelvas a abrir el panel. Al salir del tema (se destruye
/// este widget junto con la página), la conversación se pierde — que es
/// justo el comportamiento pedido: "si se sale del video se borra".
///
/// Nota de diseño: esto NO intenta replicar el material "Liquid Glass"
/// de Apple al 100% (esa refracción en tiempo real del fondo requiere
/// shaders personalizados). Es una aproximación práctica: blur de fondo
/// + borde con degradado tipo brillo + animación elástica de expansión
/// desde el ícono — el mismo espíritu visual, con herramientas estándar
/// de Flutter.
class ChatFabGlass extends StatefulWidget {
  final String cursoId;
  final String temaId;
  final String tituloTema;
  final bool bloqueado; // true = no Premium, toca -> paywall
  final VoidCallback? onBloqueadoTap;
  // Si se pasa, se pausa automáticamente al abrir el chat — antes el
  // video seguía sonando de fondo mientras se conversaba con el tutor.
  final YoutubePlayerController? youtubeController;

  const ChatFabGlass({
    super.key,
    required this.cursoId,
    required this.temaId,
    required this.tituloTema,
    required this.bloqueado,
    this.onBloqueadoTap,
    this.youtubeController,
  });

  @override
  State<ChatFabGlass> createState() => _ChatFabGlassState();
}

class _ChatFabGlassState extends State<ChatFabGlass>
    with TickerProviderStateMixin {
  bool _abierto = false;
  late final AnimationController _pulso;
  late final AnimationController _panelAnim;

  @override
  void initState() {
    super.initState();
    // Pulso lento y sutil para que el ícono sea "llamativo" sin ser
    // molesto — deja de pulsar mientras el panel está abierto.
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
      reverseDuration: const Duration(milliseconds: 140),
    );
  }

  @override
  void dispose() {
    _pulso.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.bloqueado) {
      widget.onBloqueadoTap?.call();
      return;
    }
    final abriendo = !_abierto;
    setState(() => _abierto = abriendo);
    if (abriendo) {
      widget.youtubeController?.pause();
      _panelAnim.forward();
    } else {
      _panelAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final tamano = mq.size;
    final teclado = mq.viewInsets.bottom / 2;
    final insetInferior = mq.padding.bottom; // barra de gestos/sistema
    final insetSuperior = mq.padding.top; // notch / barra de estado

    final anchoPanel = (tamano.width - 32).clamp(0.0, 420.0);
    const margenBorde = 10.0; // "prácticamente pegado" al borde, pero no 0
    final fabAlto = 54.0;
    final espacioFabPanel = 10;

    // El panel sube por encima del teclado cuando este aparece — el
    // borde de ABAJO siempre queda pegado justo encima del teclado.
    final bottomPanel =
        insetInferior + margenBorde + fabAlto + espacioFabPanel + teclado;

    // El borde de ARRIBA ahora es FIJO — ya no se recalcula en función
    // de una altura deseada (58%) ni del teclado. Antes, ese cálculo
    // elástico hacía que el borde superior también se moviera como
    // efecto secundario (solo estaba pensado como límite de emergencia
    // para cuando el teclado empujaba demasiado). Ahora el panel queda
    // "clavado" arriba, justo debajo del status bar del sistema, todo
    // el tiempo — solo el borde de abajo se mueve con el teclado, así
    // que la altura total del panel varía (crece/achica), pero siempre
    // desde el mismo punto de partida arriba.
    final topPanel = insetSuperior + 8;

    return Stack(
      children: [
        // Panel — permanece montado siempre (para no perder el estado
        // del chat); se muestra/oculta con animación + IgnorePointer.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_abierto,
            child: AnimatedBuilder(
              animation: _panelAnim,
              builder: (context, child) {
                final tLineal = _panelAnim.value;
                final tElastico = Curves.easeOutBack.transform(
                  tLineal.clamp(0.0, 1.0),
                );
                if (tLineal == 0) return const SizedBox.shrink();

                return Stack(
                  children: [
                    // Toque fuera del panel = cerrar (invisible, no
                    // difumina nada — el blur real va solo detrás del
                    // panel, más abajo).
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggle,
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                    // Dim + blur SOLO en el área detrás del panel (no
                    // toda la pantalla) — el resto se ve normal.
                    //
                    // IMPORTANTE: esto usa Positioned normal, NO
                    // AnimatedPositioned. El teclado del sistema YA trae
                    // su propia animación (Android la anima solo,
                    // frame a frame, y Flutter reconstruye este widget
                    // en cada uno de esos frames vía MediaQuery). Si
                    // además animamos NOSOTROS el cambio de posición,
                    // el panel "persigue" al teclado con un retraso
                    // extra encima del que ya trae el sistema — se
                    // siente doble y lento. Con Positioned normal, el
                    // panel sigue exactamente, frame a frame, el mismo
                    // movimiento que ya trae el teclado — sin retraso
                    // adicional.
                    Positioned(
                      right: margenBorde,
                      top: topPanel,
                      bottom: bottomPanel,
                      width: anchoPanel,

                      child: Opacity(
                        opacity: tLineal.clamp(0.0, 1.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 14 * tLineal,
                              sigmaY: 14 * tLineal,
                            ),
                            child: Container(
                              color: Colors.black.withValues(
                                alpha: 0.30 * tLineal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Panel real, mismo rectángulo, encima.
                    Positioned(
                      right: margenBorde,
                      top: topPanel,
                      bottom: bottomPanel,
                      width: anchoPanel,
                      child: Opacity(
                        opacity: tLineal.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * tElastico,
                          alignment: Alignment.bottomRight,
                          child: _ChatGlassPanel(
                            cursoId: widget.cursoId,
                            temaId: widget.temaId,
                            tituloTema: widget.tituloTema,
                            onCerrar: _toggle,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Ícono flotante — esquina inferior derecha, pegado al borde
        // pero respetando el inset de sistema (nunca debajo/encima de
        // los botones de navegación del teléfono).
        Positioned(
          right: margenBorde,
          bottom: insetInferior + margenBorde,
          child: AnimatedBuilder(
            animation: _pulso,
            builder: (context, child) {
              final s = 1.0 + (_abierto ? 0.0 : 0.05 * _pulso.value);
              return Transform.scale(scale: s, child: child);
            },
            child: _BotonBotFlotante(
              bloqueado: widget.bloqueado,
              abierto: _abierto,
              onTap: _toggle,
            ),
          ),
        ),
      ],
    );
  }
}

/// El ícono en sí — cuadrado redondeado ("squircle") con vidrio
/// translúcido en tonos azul/violeta suaves (antes era un morado sólido
/// muy saturado; se bajó la intensidad y se le dio transparencia para
/// que combine con el resto del look "glass"), y un ícono de destellos
/// (más "IA futurista" que la carita de robot anterior).
class _BotonBotFlotante extends StatelessWidget {
  final bool bloqueado;
  final bool abierto;
  final VoidCallback onTap;
  final double tamano;

  const _BotonBotFlotante({
    required this.bloqueado,
    required this.abierto,
    required this.onTap,
    this.tamano = 54,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12, width: 1.5),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Icon(
            bloqueado
                ? Icons.lock_outline_rounded
                : (abierto ? Icons.close_rounded : Icons.auto_awesome_rounded),
            key: ValueKey(bloqueado ? 'lock' : (abierto ? 'close' : 'open')),
            color: Colors.white,
            size: tamano * 0.44,
          ),
        ),
      ),
    );
  }
}

/// Contenido del chat en sí, ahora dentro de un panel flotante con look
/// "glass" en vez de una página completa. Mantiene toda la lógica que ya
/// tenía ChatbotPage (preparar contexto, enviar mensaje, historial).
class _ChatGlassPanel extends StatefulWidget {
  final String cursoId;
  final String temaId;
  final String tituloTema;
  final VoidCallback onCerrar;

  const _ChatGlassPanel({
    required this.cursoId,
    required this.temaId,
    required this.tituloTema,
    required this.onCerrar,
  });

  @override
  State<_ChatGlassPanel> createState() => _ChatGlassPanelState();
}

class _ChatGlassPanelState extends State<_ChatGlassPanel> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  bool _preparando = true;
  bool _iniciado = false;

  void _mensajeBienvenida() {
    _messages.add(
      ChatMessage(
        text:
            "¡Hola! Soy tu tutor **AcademiBot**. Pregúntame lo que "
            "quieras sobre **${widget.tituloTema}** — si es un ejercicio, "
            "te voy guiando con pistas en vez de solo darte la "
            "respuesta 😉",
        isUser: false,
      ),
    );
  }

  Future<void> _iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    try {
      await _chatService.prepararContexto(
        cursoId: widget.cursoId,
        temaId: widget.temaId,
      );
    } catch (_) {
      // Si falla la preparación, igual dejamos entrar al chat: el
      // backend reintentará al procesar el primer mensaje.
    }
    if (!mounted) return;
    setState(() {
      _preparando = false;
      _mensajeBienvenida();
    });
  }

  void _sendMessage() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _isLoading || _preparando) return;

    final historialPrevio = _messages.reversed.toList();

    setState(() {
      _messages.insert(0, ChatMessage(text: texto, isUser: true));
      _isLoading = true;
    });
    _controller.clear();

    final response = await _chatService.getResponse(
      cursoId: widget.cursoId,
      temaId: widget.temaId,
      mensaje: texto,
      historial: historialPrevio,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.insert(0, ChatMessage(text: response, isUser: false));
      });
    }
  }

  void _limpiarConversacion() {
    setState(() {
      _messages.clear();
      _mensajeBienvenida();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dispara la preparación del contexto la primera vez que el panel se
    // pinta (no en initState, así el layout ya tiene tamaño listo).
    if (!_iniciado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ).withValues(alpha: 0.10),
                const Color.fromARGB(
                  255,
                  145,
                  145,
                  145,
                ).withValues(alpha: 0.55),
                const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.75),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: _preparando
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Color.fromARGB(255, 0, 225, 255),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Preparando el material de este tema...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildBubble(_messages[index]),
                      ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: SizedBox(
                      width: 100,
                      height: 2,
                      child: LinearProgressIndicator(
                        color: Color.fromARGB(255, 0, 225, 255),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              _buildInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "AcademiBot IA",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white38,
              size: 20,
            ),
            tooltip: 'Borrar conversación',
            onPressed: _preparando ? null : _limpiarConversacion,
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white38,
              size: 20,
            ),
            tooltip: 'Cerrar',
            onPressed: widget.onCerrar,
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Align(
            alignment: msg.isUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.88,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? const Color.fromARGB(255, 0, 225, 255)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
              ),
              child: msg.isUser
                  ? Text(
                      msg.text,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  : _MathMarkdownRenderer(text: msg.text),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: "Escribe tu duda...",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ).withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white12,
                  width: 1.5, // ajusta el grosor que quieras
                ),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.black,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// RENDERER: Markdown + LaTeX inline ($) y bloque ($$)
// ══════════════════════════════════════════════════
class _MathMarkdownRenderer extends StatelessWidget {
  final String text;
  const _MathMarkdownRenderer({required this.text});

  static const TextStyle _base = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.55,
  );
  static const TextStyle _bold = TextStyle(
    color: Color(0xFFFFB800),
    fontWeight: FontWeight.bold,
    fontSize: 14,
    height: 1.55,
  );

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(text);

    if (segments.every((s) => s.type == _SegType.text)) {
      return _buildMarkdown(text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: segments.map(_renderSegment).toList(),
    );
  }

  Widget _renderSegment(_Segment seg) {
    switch (seg.type) {
      case _SegType.mathBlock:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              seg.content,
              textStyle: const TextStyle(color: Colors.white, fontSize: 15),
              mathStyle: MathStyle.display,
              onErrorFallback: (_) => Text(
                seg.content,
                style: _base.copyWith(
                  color: Colors.orangeAccent,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        );

      case _SegType.text:
        if (seg.content.contains(r'$') || seg.content.contains('**')) {
          return _buildInlineRich(seg.content);
        }
        return _buildMarkdown(seg.content);
    }
  }

  Widget _buildMarkdown(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    return MarkdownBody(
      data: trimmed,
      styleSheet: MarkdownStyleSheet(
        p: _base,
        strong: _bold,
        em: _base.copyWith(fontStyle: FontStyle.italic),
        listBullet: _base,
        h3: _base.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: const Color(0xFFFFB800),
        ),
        code: _base.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.white10,
          color: const Color(0xFFFFB800),
        ),
      ),
      softLineBreak: true,
    );
  }

  Widget _buildInlineRich(String input) {
    final pattern = RegExp(r'\*\*(.+?)\*\*|\$([^$\n]+?)\$');
    final spans = <InlineSpan>[];
    int last = 0;

    for (final m in pattern.allMatches(input)) {
      if (m.start > last) {
        spans.add(TextSpan(text: input.substring(last, m.start), style: _base));
      }

      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1)!, style: _bold));
      } else if (m.group(2) != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              m.group(2)!,
              textStyle: _base,
              mathStyle: MathStyle.text,
              onErrorFallback: (_) => Text(
                m.group(2)!,
                style: _base.copyWith(
                  color: Colors.orangeAccent,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        );
      }
      last = m.end;
    }

    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last), style: _base));
    }

    if (spans.isEmpty) return const SizedBox.shrink();
    return RichText(text: TextSpan(children: spans), softWrap: true);
  }

  List<_Segment> _parseSegments(String input) {
    final result = <_Segment>[];
    final blockRx = RegExp(r'\$\$([^$]+?)\$\$', dotAll: true);
    int last = 0;

    for (final m in blockRx.allMatches(input)) {
      if (m.start > last) {
        result.add(_Segment(_SegType.text, input.substring(last, m.start)));
      }
      result.add(_Segment(_SegType.mathBlock, m.group(1)!.trim()));
      last = m.end;
    }
    if (last < input.length) {
      result.add(_Segment(_SegType.text, input.substring(last)));
    }

    return result.where((s) => s.content.isNotEmpty).toList();
  }
}

enum _SegType { text, mathBlock }

class _Segment {
  final _SegType type;
  final String content;
  const _Segment(this.type, this.content);
}
