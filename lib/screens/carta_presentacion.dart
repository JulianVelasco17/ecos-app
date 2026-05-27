import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lectura_carta_astral.dart';
import 'compra_carta_astral.dart';

class PantallaCartaPresentacion extends StatefulWidget {
  const PantallaCartaPresentacion({super.key});

  @override
  State<PantallaCartaPresentacion> createState() => _PantallaCartaPresentacionState();
}

class _PantallaCartaPresentacionState extends State<PantallaCartaPresentacion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  bool _activando = false;

  static const _beige = Color(0xFFE8DFD0);
  static const _gold  = Color(0xFFB8973A);
  static const _fondo = Color(0xFF0A0A0A);

  static const _secciones = [
    _Seccion('◉', 'tu big 3 en profundidad',
        'Sol, Luna y Ascendente interpretados juntos como un sistema. No por separado — la tensión y sinergia entre los tres.'),
    _Seccion('✦', 'aspectos natales',
        'Las tensiones y armonías entre tus planetas que definen cómo experimentas el mundo. Lo que te cuesta y lo que te sale natural.'),
    _Seccion('○', 'lectura por ámbitos',
        'Amor, amistad, suerte, familia y dinero — cada uno desde tu configuración natal.'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _activarYAbrir() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _activando = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios').doc(uid).get();
      final tieneAcceso = doc.data()?['cartaActiva'] == true;
      if (!mounted) return;
      if (tieneAcceso) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const PantallaLecturaCartaAstral()));
      } else {
        setState(() => _activando = false);
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const PantallaCompraCarta()));
      }
    } catch (_) {
      if (mounted) setState(() => _activando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _encabezado(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FilaSeccion(seccion: _secciones[i]),
                  childCount: _secciones.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _pie()),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 28),
              child: Icon(Icons.arrow_back_ios, color: Colors.white24, size: 18),
            ),
          ),
          const Text(
            'lo que\ncontiene',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: _beige,
              fontSize: 46,
              fontWeight: FontWeight.w400,
              height: 1.15,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(width: 28, height: 1.5, color: _gold),
          const SizedBox(height: 20),
          const Text(
            'Tu carta natal es un mapa de lo que ya eres. Estas 3 lecturas lo ponen en palabras.',
            style: TextStyle(
              color: Color(0x88E8DFD0),
              fontSize: 15,
              height: 1.75,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pie() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: double.infinity, height: 1,
              color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 40),
          const Text(
            'una sola lectura.\npersonal, directa, tuya.',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: _beige,
              fontSize: 28,
              fontWeight: FontWeight.w400,
              height: 1.3,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No es genérica. Se genera específicamente para tu configuración natal — la posición exacta de cada planeta el día que naciste.',
            style: TextStyle(color: Color(0x77E8DFD0), fontSize: 14, height: 1.75),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _activando ? null : _activarYAbrir,
              style: ElevatedButton.styleFrom(
                backgroundColor: _beige,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                elevation: 0,
              ),
              child: const Text('DESBLOQUEAR MI CARTA — \$59',
                  style: TextStyle(letterSpacing: 2.5, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('pago único · revisita cuando quieras',
                style: TextStyle(color: Colors.white24, fontSize: 11, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _Seccion {
  final String simbolo;
  final String titulo;
  final String cuerpo;
  const _Seccion(this.simbolo, this.titulo, this.cuerpo);
}

class _FilaSeccion extends StatelessWidget {
  final _Seccion seccion;
  const _FilaSeccion({required this.seccion});

  static const _beige = Color(0xFFE8DFD0);
  static const _gold  = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(seccion.simbolo,
                style: TextStyle(color: _gold.withValues(alpha: 0.8), fontSize: 14, height: 1.6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seccion.titulo,
                    style: TextStyle(
                        color: _beige.withValues(alpha: 0.5),
                        fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                Text(seccion.cuerpo,
                    style: const TextStyle(
                        color: Color(0xCCE8DFD0), fontSize: 15,
                        height: 1.7, fontWeight: FontWeight.w300, letterSpacing: 0.1)),
                const SizedBox(height: 28),
                Container(width: double.infinity, height: 1,
                    color: Colors.white.withValues(alpha: 0.06)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
