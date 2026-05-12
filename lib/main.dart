import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/registro.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'package:home_widget/home_widget.dart';
import 'widget_background.dart';

// Shader cargado una sola vez al arranque y compartido globalmente
FragmentShader? shaderMarble;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  HomeWidget.registerInteractivityCallback(widgetBackground);
  // Cargar shader y notificaciones en paralelo para no bloquear el arranque
  final results = await Future.wait([
    FragmentProgram.fromAsset('shaders/marble.frag'),
    NotificationService.inicializar().then((_) => null),
  ]);
  shaderMarble = (results[0] as FragmentProgram).fragmentShader();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.08),
          boldText: false,
        ),
        child: child!,
      ),
      home: const PantallaBienvenida(),
    );
  }
}

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida>
    with TickerProviderStateMixin {

  // Animaciones de entrada iniciales
  late AnimationController _controladorEntrada;
  late Animation<double> _opacidadTitulo;
  late Animation<double> _opacidadBoton;
  late Animation<Offset> _posicionBoton;

  // Animaciones al pulsar "SUMERGIRTE"
  late AnimationController _controladorOscurecer;

  late Animation<double> _oscurecimiento;

  bool _panelVisible = false;
  bool _procesandoGoogle = false;
  bool _procesandoApple = false;

  @override
  void initState() {
    super.initState();
    _verificarSesion();

    // Entrada inicial: título y botón
    _controladorEntrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _opacidadTitulo = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controladorEntrada,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _opacidadBoton = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controladorEntrada,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _posicionBoton = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controladorEntrada,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Oscurecimiento al pulsar
    _controladorOscurecer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _oscurecimiento = Tween<double>(begin: 0.0, end: 0.60).animate(
      CurvedAnimation(parent: _controladorOscurecer, curve: Curves.easeIn),
    );

  }

  @override
  void dispose() {

    _controladorEntrada.dispose();
    _controladorOscurecer.dispose();
    super.dispose();
  }

  Future<void> _verificarSesion() async {
    final usuario = AuthService.usuarioActual;
    if (usuario == null || usuario.isAnonymous) return;
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(usuario.uid).get();
    if (!mounted) return;
    if (doc.exists) {
      NotificationService.guardarTokenFCM();
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => PantallaHome(nombre: doc.data()?['nombre'] ?? 'viajero'),
      ));
    }
  }

  Future<void> _sumergirse() async {
    setState(() => _panelVisible = true);
    _controladorOscurecer.forward();
  }

  Future<void> _irARegistro(Offset origen) async {
    if (AuthService.usuarioActual != null && !AuthService.usuarioActual!.isAnonymous) {
      await AuthService.cerrarSesion();
    }
    await AuthService.loginAnonimo();
    if (!mounted) return;
    Navigator.push(context, _CircularRevealRoute(
      origin: origen,
      builder: (_) => const PantallaRegistro(),
    ));
  }

  Future<void> _loginConApple() async {
    setState(() => _procesandoApple = true);
    final usuario = await AuthService.loginConApple();
    if (!mounted) return;
    setState(() => _procesandoApple = false);
    if (usuario == null) return;

    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(usuario.uid).get();
    if (!mounted) return;

    if (doc.exists) {
      final datos = doc.data()!;
      NotificationService.guardarTokenFCM();
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => PantallaHome(nombre: datos['nombre'] ?? 'viajero'),
      ));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PantallaRegistro()));
    }
  }

  Future<void> _loginConGoogle() async {
    setState(() => _procesandoGoogle = true);
    final usuario = await AuthService.loginConGoogle();
    if (!mounted) return;
    setState(() => _procesandoGoogle = false);
    if (usuario == null) return;

    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(usuario.uid).get();
    if (!mounted) return;

    if (doc.exists) {
      final datos = doc.data()!;
      NotificationService.guardarTokenFCM();
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => PantallaHome(nombre: datos['nombre'] ?? 'viajero'),
      ));
    } else {
      final fotoUrl = usuario.photoURL;
      if (fotoUrl != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(usuario.uid)
            .set({'fotoUrl': fotoUrl}, SetOptions(merge: true));
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PantallaRegistro()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: Stack(
        children: [
          // Capa 1: fondo mármol fluido
          const _FondoMarmol(),

          // Capa 2: título + botón SUMERGIRTE
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _opacidadTitulo,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: const Text(
                      'ecos',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 64),

                SlideTransition(
                  position: _posicionBoton,
                  child: FadeTransition(
                    opacity: _opacidadBoton,
                    child: _panelVisible
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: _sumergirse,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text(
                                'SUMERGIRTE',
                                style: TextStyle(
                                  color: Color(0xFFF3EBD6),
                                  letterSpacing: 4,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Capa 3: oscurecimiento progresivo
          AnimatedBuilder(
            animation: _oscurecimiento,
            builder: (context, w) => IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: _oscurecimiento.value)),
            ),
          ),

          // Capa 4: panel arrastrable
          if (_panelVisible)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                if (n.extent <= 0.02) {
                  setState(() => _panelVisible = false);
                  _controladorOscurecer.reverse();
                }
                return true;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.48,
                minChildSize: 0.0,
                maxChildSize: 0.48,
                snap: true,
                snapSizes: const [0.0, 0.48],
                builder: (_, controller) => SingleChildScrollView(
                  controller: controller,
                  physics: const ClampingScrollPhysics(),
                  child: _PanelOpciones(
                    onRegistro: _irARegistro,
                    onLogin: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PantallaLogin()),
                    ),
                    onGoogle: _loginConGoogle,
                    procesandoGoogle: _procesandoGoogle,
                    onApple: _loginConApple,
                    procesandoApple: _procesandoApple,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Panel que emerge al oscurecer ───────────────────────────────────────────

class _PanelOpciones extends StatelessWidget {
  final void Function(Offset) onRegistro;
  final VoidCallback onLogin;
  final VoidCallback onGoogle;
  final bool procesandoGoogle;
  final VoidCallback onApple;
  final bool procesandoApple;

  const _PanelOpciones({
    required this.onRegistro,
    required this.onLogin,
    required this.onGoogle,
    required this.procesandoGoogle,
    required this.onApple,
    required this.procesandoApple,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bloque beige que tapa el hueco debajo del border radius
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(height: 60, color: const Color(0xFFF3EBD6)),
        ),
        Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(32, 40, 32, MediaQuery.of(context).padding.bottom + 40),
      decoration: const BoxDecoration(
        color: Color(0xFFF3EBD6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle visual
          Center(
            child: Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(bottom: 36),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Crear cuenta
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                final box = ctx.findRenderObject() as RenderBox;
                final center = box.localToGlobal(box.size.center(Offset.zero));
                onRegistro(center);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: const Color(0xFFF3EBD6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                elevation: 0,
              ),
              child: const Text('CREAR CUENTA', style: TextStyle(letterSpacing: 3, fontSize: 12)),
            ),
          ),

          const SizedBox(height: 12),

          // Iniciar sesión
          OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: const BorderSide(color: Colors.black26),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
            child: const Text('INICIAR SESIÓN', style: TextStyle(letterSpacing: 3, fontSize: 12)),
          ),

          const SizedBox(height: 36),

          // Divisor
          Row(
            children: const [
              Expanded(child: Divider(color: Colors.black12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o', style: TextStyle(color: Colors.black26, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.black12)),
            ],
          ),

          const SizedBox(height: 24),

          // Google
          _BotonSocial(
            onTap: onGoogle,
            cargando: procesandoGoogle,
            texto: 'continuar con Google',
          ),

          const SizedBox(height: 12),

          // Apple — solo iOS
          if (Platform.isIOS)
            _BotonSocial(
              onTap: onApple,
              cargando: procesandoApple,
              texto: 'continuar con Apple',
            ),
        ],
      ),
        ),
      ],
    );
  }
}

class _BotonSocial extends StatelessWidget {
  final VoidCallback onTap;
  final bool cargando;
  final String texto;

  const _BotonSocial({required this.onTap, required this.cargando, required this.texto});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.black12),
        ),
        child: Center(
          child: cargando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black45, strokeWidth: 1.5))
              : Text(texto, style: const TextStyle(color: Colors.black45, letterSpacing: 1, fontSize: 13)),
        ),
      ),
    );
  }
}

// ─── Transición circular desde el botón ──────────────────────────────────────

class _CircularRevealRoute extends PageRoute<void> {
  final WidgetBuilder builder;
  final Offset origin;

  _CircularRevealRoute({required this.builder, required this.origin});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 720);

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String get barrierLabel => '';

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) => builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        final maxRadius = sqrt(size.width * size.width + size.height * size.height);
        final radius = Curves.easeInOut.transform(animation.value) * maxRadius;
        return ClipPath(
          clipper: _CircleClipper(center: origin, radius: radius),
          child: child,
        );
      },
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  const _CircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.center != center || old.radius != radius;
}

// ─── Fondo de mármol fluido (fragment shader) ─────────────────────────────────

class _FondoMarmol extends StatefulWidget {
  const _FondoMarmol();

  @override
  State<_FondoMarmol> createState() => _FondoMarmolState();
}

class _FondoMarmolState extends State<_FondoMarmol>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 200),
    )..repeat();
    _cargarShader();
  }

  void _cargarShader() {
    if (shaderMarble != null) {
      setState(() => _shader = shaderMarble);
    } else {
      FragmentProgram.fromAsset('shaders/marble.frag').then((p) {
        if (mounted) setState(() => _shader = p.fragmentShader());
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) {
      return const ColoredBox(color: Color(0xFFF3EBD6));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _MarblePainter(_shader!, _ctrl.value * 60.0),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MarblePainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  const _MarblePainter(this.shader, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_MarblePainter old) => old.time != time;
}
