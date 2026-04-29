import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_planetarios.dart';
import '../services/calculos_astrales.dart';
import '../services/claude_service.dart';
import '../widgets/rueda_zodiacal.dart';
import 'lectura_clima_personal.dart';

class PantallaClimaAstral extends StatefulWidget {
  const PantallaClimaAstral({super.key});

  @override
  State<PantallaClimaAstral> createState() => _PantallaClimaAstralState();
}

class _PantallaClimaAstralState extends State<PantallaClimaAstral> {
  List<PlanetaInfo> _planetas = [];
  Map<String, double> _longitudes = {};
  String? _caption;
  bool _cargando = true;
  bool _expandido = false;
  String? _seleccionado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hoy = DateTime.now();
    final fechaKey = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    final planetas = CalculosPlanetarios.calcularPosiciones(hoy);
    final lons = CalculosAstrales.calcularLongitudes(hoy, 0, 0);

    String caption;
    if (miUid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('climaAstral')
          .doc(fechaKey)
          .get();

      if (doc.exists) {
        caption = doc.data()!['caption'] as String;
      } else {
        final resumen = planetas.map((p) => '${p.nombre} en ${p.signo}').join(', ');
        caption = await ClaudeService.generarClimaAstral(resumen);
        await FirebaseFirestore.instance
            .collection('climaAstral')
            .doc(fechaKey)
            .set({'caption': caption, 'fecha': FieldValue.serverTimestamp()});
      }
    } else {
      final resumen = planetas.map((p) => '${p.nombre} en ${p.signo}').join(', ');
      caption = await ClaudeService.generarClimaAstral(resumen);
    }

    if (mounted) {
      setState(() {
        _planetas   = planetas;
        _longitudes = lons;
        _caption    = caption;
        _cargando   = false;
      });
    }
  }

  PlanetaInfo? _planeta(String nombre) {
    try {
      return _planetas.firstWhere((p) => p.nombre.toLowerCase() == nombre.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    const meses = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                   'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final fechaStr = '${hoy.day} de ${meses[hoy.month]}';

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 1.5))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Título serif ────────────────────────────────────────
                    Text(
                      'El cielo, hoy',
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 34,
                        fontWeight: FontWeight.w300,
                        color: Colors.black87,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fechaStr,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
                        letterSpacing: 1.8,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Rectángulo unificado Sol / Luna ─────────────────────
                    Builder(builder: (_) {
                      final sol = _planeta('Sol');
                      final luna = _planeta('Luna');
                      if (sol == null || luna == null) return const SizedBox.shrink();
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF6ED),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                  _seleccionado = _seleccionado == 'Sol' ? null : 'Sol'),
                                child: _CeldaPlaneta(
                                  simbolo: sol.simbolo,
                                  label: 'Sol en',
                                  signo: sol.signo,
                                  activo: _seleccionado == 'Sol',
                                  isLeft: true,
                                ),
                              ),
                            ),
                            Container(width: 0.5, height: 48, color: Colors.black12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                  _seleccionado = _seleccionado == 'Luna' ? null : 'Luna'),
                                child: _CeldaPlaneta(
                                  simbolo: luna.simbolo,
                                  label: 'Luna en',
                                  signo: luna.signo,
                                  activo: _seleccionado == 'Luna',
                                  isLeft: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // ── Info posición precisa ───────────────────────────────
                    if (_seleccionado != null) ...[
                      Builder(builder: (_) {
                        final p = _planeta(_seleccionado!);
                        if (p == null) return const SizedBox.shrink();
                        final grados = p.longitud % 30;
                        final gradosStr = grados.toStringAsFixed(1);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F3E8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFB8973A), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${p.simbolo}  ', style: const TextStyle(fontSize: 16)),
                              Text(
                                '${p.nombre}  ·  $gradosStr° ${p.signo}  ·  ${p.longitud.toStringAsFixed(2)}° eclíptica',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── Rueda zodiacal ──────────────────────────────────────
                    Center(
                      child: RepaintBoundary(
                        child: SizedBox(
                          width: 420,
                          height: 420,
                          child: CustomPaint(
                            painter: RuedaZodiacalPainter(_planetas, seleccionado: _seleccionado),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Chips de planetas ───────────────────────────────────
                    if (_longitudes.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _longitudes.entries.map((e) {
                        final nombre = e.key;
                        final lon    = e.value;
                        final selec  = _seleccionado == nombre;
                        const signos = ['Aries','Tauro','Géminis','Cáncer','Leo','Virgo',
                          'Libra','Escorpio','Sagitario','Capricornio','Acuario','Piscis'];
                        const abrevs = {
                          'Aries':'Ari','Tauro':'Tau','Géminis':'Gém','Cáncer':'Cnc',
                          'Leo':'Leo','Virgo':'Vir','Libra':'Lib','Escorpio':'Esc',
                          'Sagitario':'Sag','Capricornio':'Cap','Acuario':'Acu','Piscis':'Pis',
                        };
                        final signo = signos[((lon % 360) / 30).floor() % 12];
                        final grado = (lon % 30).floor();
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _seleccionado = selec ? null : nombre),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selec ? Colors.black : Colors.transparent,
                              border: Border.all(color: selec ? Colors.black : Colors.black26),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '$nombre  ${abrevs[signo] ?? signo} $grado°',
                              style: TextStyle(
                                color: selec ? const Color(0xFFF3EBD6) : Colors.black54,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // ── Energía del día (tarjeta oscura) ────────────────────
                    if (_caption != null) ...[
                      _TarjetaEnergia(caption: _caption!),
                      const SizedBox(height: 14),

                      // ── Acordeón interpretación ────────────────────────
                      _Acordeon(
                        expandido: _expandido,
                        onTap: () => setState(() => _expandido = !_expandido),
                        caption: _caption!,
                      ),

                      const SizedBox(height: 32),
                    ],

                    // ── Lista de planetas ───────────────────────────────────
                    const Divider(color: Colors.black26),
                    const SizedBox(height: 20),

                    ..._planetas.map((p) {
                      final lon = _longitudes[p.nombre];
                      final grado = lon != null ? (lon % 30).floor() : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text('${p.simbolo}︎', style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              p.nombre,
                              style: const TextStyle(color: Colors.black54, fontSize: 12, letterSpacing: 1.5),
                            ),
                            const Spacer(),
                            if (grado != null)
                              Text(
                                '$grado°  ',
                                style: const TextStyle(color: Colors.black26, fontSize: 11),
                              ),
                            Text(
                              p.signo,
                              style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w300, letterSpacing: 1),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 40),

                    // ── Paywall premium ─────────────────────────────────────
                    const Divider(color: Colors.black26),
                    const SizedBox(height: 28),

                    const Text(
                      'LECTURA PROFUNDA',
                      style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cómo afecta el clima de hoy a tu carta natal.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Descubre qué casas están activadas, qué tránsitos te tocan directamente y cómo navegar el día con tu carta como mapa.',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const PantallaLecturaClimaPersonal())),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: const Color(0xFFF3EBD6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                          elevation: 0,
                        ),
                        child: const Text('DESBLOQUEAR · \$3.99/mes', style: TextStyle(letterSpacing: 2, fontSize: 12)),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Celda dentro del rectángulo unificado ────────────────────────────────────

class _CeldaPlaneta extends StatelessWidget {
  final String simbolo;
  final String label;
  final String signo;
  final bool activo;
  final bool isLeft;

  const _CeldaPlaneta({
    required this.simbolo,
    required this.label,
    required this.signo,
    required this.activo,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final colorIcono = activo ? const Color(0xFFB8973A) : Colors.black45;
    final colorSub   = activo ? const Color(0xFFB8973A) : Colors.black38;
    final colorTexto = activo ? const Color(0xFF2C2C2C) : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: activo ? const Color(0xFFF0EAD8) : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft:     isLeft  ? const Radius.circular(12) : Radius.zero,
          bottomLeft:  isLeft  ? const Radius.circular(12) : Radius.zero,
          topRight:    !isLeft ? const Radius.circular(12) : Radius.zero,
          bottomRight: !isLeft ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          Text('$simbolo︎', style: TextStyle(fontSize: 20, color: colorIcono)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: colorSub, letterSpacing: 0.3)),
              Text(signo, style: TextStyle(fontSize: 14, color: colorTexto, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta Energía del Día ──────────────────────────────────────────────────

class _TarjetaEnergia extends StatelessWidget {
  final String caption;
  const _TarjetaEnergia({required this.caption});

  String _frasePrincipal() {
    final sentences = caption.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.isNotEmpty ? sentences.first : caption;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ENERGÍA DEL DÍA',
            style: TextStyle(
              color: Color(0xFFB8973A),
              fontSize: 9,
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _frasePrincipal(),
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: Color(0xFFF3EBD6),
              fontSize: 18,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Acordeón interpretación ──────────────────────────────────────────────────

class _Acordeon extends StatelessWidget {
  final bool expandido;
  final VoidCallback onTap;
  final String caption;

  const _Acordeon({required this.expandido, required this.onTap, required this.caption});

  String _cuerpo() {
    final sentences = caption.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 1) return caption;
    return sentences.sublist(1).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final cuerpo = _cuerpo();
    if (cuerpo.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Interpretación del día',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                cuerpo,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.7,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            crossFadeState: expandido ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

