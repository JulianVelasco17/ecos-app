import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../widgets/loading_images.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_planetarios.dart';
import '../services/calculos_astrales.dart';
import '../services/claude_service.dart';
import '../widgets/rueda_zodiacal.dart';
import 'lectura_clima_personal.dart';
import 'compra_ecos_plus.dart';

class PantallaClimaAstral extends StatefulWidget {
  final void Function(bool)? onCargandoChanged;
  const PantallaClimaAstral({super.key, this.onCargandoChanged});

  @override
  State<PantallaClimaAstral> createState() => _PantallaClimaAstralState();
}

class _PantallaClimaAstralState extends State<PantallaClimaAstral> {
  List<PlanetaInfo> _planetas = [];
  Map<String, double> _longitudes = {};
  String? _caption;
  bool _cargando = true;
  String? _seleccionado;
  bool _ecosPlusActivo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hoy = DateTime.now();
    final fechaKey = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    final utc = hoy.toUtc();
    final lons = CalculosAstrales.calcularLongitudes(utc, utc.hour, utc.minute);
    const _nombres = ['Sol','Luna','Mercurio','Venus','Marte','Júpiter','Saturno','Urano','Neptuno','Plutón'];
    const _simbolos = {'Sol':'☉','Luna':'☽','Mercurio':'☿','Venus':'♀','Marte':'♂','Júpiter':'♃','Saturno':'♄','Urano':'♅','Neptuno':'♆','Plutón':'♇'};
    const _signosLista = ['Aries','Tauro','Géminis','Cáncer','Leo','Virgo','Libra','Escorpio','Sagitario','Capricornio','Acuario','Piscis'];
    const _simbolosSignos = ['ARI','TAU','GEM','CAN','LEO','VIR','LIB','ESC','SAG','CAP','ACU','PIS'];
    final planetas = _nombres.where((n) => lons.containsKey(n)).map((n) {
      final lon = lons[n]!;
      final idx = ((lon % 360) / 30).floor() % 12;
      return PlanetaInfo(nombre: n, simbolo: _simbolos[n]!, signo: _signosLista[idx], simboloSigno: _simbolosSignos[idx], longitud: lon);
    }).toList();

    // Carta natal del usuario
    String? solar, lunar, asc;
    Map<String, String> natales = {};
    if (miUid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(miUid).get();
      final ud = userDoc.data();
      if (ud != null) {
        solar = ud['signoSolar'] as String?;
        lunar = ud['signoLunar'] as String?;
        asc   = ud['ascendente'] as String?;
        natales = (ud['planetas'] as Map?)?.cast<String, String>() ?? {};
        _ecosPlusActivo = ud['ecosPlusActivo'] == true;
      }
    }

    String caption;
    if (miUid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(miUid)
          .collection('climaPersonal')
          .doc(fechaKey)
          .get();

      if (doc.exists) {
        caption = doc.data()!['caption'] as String;
      } else {
        final resumenTransito = planetas.map((p) => '${p.nombre} en ${p.signo} ${(p.longitud % 30).floor()}°').join(', ');
        final resumenNatal = solar != null
            ? 'Sol natal $solar, Luna natal $lunar, Asc $asc${natales.isNotEmpty ? ', ${natales.entries.map((e) => '${e.key} natal ${e.value}').join(', ')}' : ''}'
            : '';
        caption = await ClaudeService.generarClimaAstral(resumenTransito, cartaNatal: resumenNatal);
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(miUid)
            .collection('climaPersonal')
            .doc(fechaKey)
            .set({'caption': caption, 'fecha': FieldValue.serverTimestamp()});
      }
    } else {
      final resumenTransito = planetas.map((p) => '${p.nombre} en ${p.signo} ${(p.longitud % 30).floor()}°').join(', ');
      caption = await ClaudeService.generarClimaAstral(resumenTransito);
    }

    if (mounted) {
      setState(() {
        _planetas   = planetas;
        _longitudes = lons;
        _caption    = caption;
        _cargando   = false;
      });
      widget.onCargandoChanged?.call(false);
    }
  }

  Future<void> _forzarRegen() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;
    final hoy = DateTime.now();
    final fechaKey = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    await FirebaseFirestore.instance
        .collection('usuarios').doc(miUid)
        .collection('climaPersonal').doc(fechaKey)
        .delete();
    if (mounted) setState(() { _caption = null; _cargando = true; });
    await _cargar();
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
            ? const LoadingImages(pegadoDerecha: true)
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
                        fontSize: 38,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF222222),
                        height: 1.1,
                        letterSpacing: 1.0,
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

                    if (_ecosPlusActivo) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const PantallaLecturaClimaPersonal())),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: const Color(0xFFF3EBD6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                            elevation: 0,
                          ),
                          child: const Text('NAVEGAR EL CLIMA ASTRAL', style: TextStyle(letterSpacing: 2, fontSize: 12)),
                        ),
                      ),
                    ],

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
                    LayoutBuilder(builder: (context, constraints) {
                      const simPlanetas = {
                        'Sol':        '☉︎',
                        'Luna':       '☽︎',
                        'Mercurio':   '☿︎',
                        'Venus':      '♀︎',
                        'Marte':      '♂︎',
                        'Júpiter':    '♃︎',
                        'Saturno':    '♄︎',
                        'Urano':      '♅︎',
                        'Neptuno':    '♆︎',
                        'Plutón':     '♇︎',
                        'Ascendente': '↑',
                      };
                      const signosLista = ['Aries','Tauro','Géminis','Cáncer','Leo','Virgo',
                        'Libra','Escorpio','Sagitario','Capricornio','Acuario','Piscis'];
                      final entries = _longitudes.entries.toList();
                      final chipW = (constraints.maxWidth - 16) / 3;
                      final rows = <Widget>[];
                      for (var i = 0; i < entries.length; i += 3) {
                        final rowItems = entries.skip(i).take(3).toList();
                        rows.add(Row(
                          children: List.generate(3, (j) {
                            if (j >= rowItems.length) {
                              return SizedBox(width: chipW + (j < 2 ? 8 : 0));
                            }
                            final e      = rowItems[j];
                            final nombre = e.key;
                            final lon    = e.value;
                            final selec  = _seleccionado == nombre;
                            final grado  = (lon % 30).floor();
                            final signo  = signosLista[((lon % 360) / 30).floor() % 12];
                            final simPlan = simPlanetas[nombre] ?? '·';
                            return _ChipPlaneta(
                              width: chipW,
                              margin: EdgeInsets.only(right: j < 2 ? 8 : 0),
                              simbolo: simPlan,
                              nombre: nombre,
                              grado: grado,
                              signo: signo,
                              seleccionado: selec,
                              onTap: () => setState(() =>
                                  _seleccionado = selec ? null : nombre),
                            );
                          }),
                        ));
                        if (i + 3 < entries.length) rows.add(const SizedBox(height: 8));
                      }
                      return Column(children: rows);
                    }),

                    const SizedBox(height: 32),

                    // ── Energía del día (tarjeta oscura) ────────────────────
                    if (_caption != null) ...[
                      _TarjetaEnergia(caption: _caption!),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final uid = FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;
                              await FirebaseFirestore.instance.collection('usuarios').doc(uid)
                                  .update({'ecosPlusActivo': false});
                              if (mounted) setState(() => _ecosPlusActivo = false);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Text('✕ cancelar ecos+',
                                style: TextStyle(fontSize: 11, color: Colors.black38, letterSpacing: 0.5)),
                            ),
                          ),
                          GestureDetector(
                            onTap: _forzarRegen,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Text('↺ regenerar',
                                style: TextStyle(fontSize: 11, color: Colors.black38, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Lectura profunda / paywall ──────────────────────────
                    if (!_ecosPlusActivo) ...[
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
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const PantallaCompraEcosPlus()));
                            if (!mounted) return;
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              final doc = await FirebaseFirestore.instance
                                  .collection('usuarios').doc(uid).get();
                              if (!mounted) return;
                              if (doc.data()?['ecosPlusActivo'] != true) return;
                              setState(() => _ecosPlusActivo = true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: const Color(0xFFF3EBD6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                            elevation: 0,
                          ),
                          child: const Text('DESBLOQUEAR CON ECOS+', style: TextStyle(letterSpacing: 2, fontSize: 12)),
                        ),
                      ),
                    ],

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
              fontFamily: 'PlayfairDisplay',
              color: Color(0xFFB8973A),
              fontSize: 14,
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _TextoDestacadoEnergia(
            texto: caption.replaceAll(RegExp(r'^#+\s.*\n?', multiLine: true), '').trim(),
          ),
        ],
      ),
    );
  }
}

class _TextoDestacadoEnergia extends StatefulWidget {
  final String texto;
  const _TextoDestacadoEnergia({required this.texto});
  @override
  State<_TextoDestacadoEnergia> createState() => _TextoDestacadoEnergiaState();
}

class _TextoDestacadoEnergiaState extends State<_TextoDestacadoEnergia> {
  late Set<int> _indicesNegrita;

  @override
  void initState() {
    super.initState();
    final palabras = widget.texto.split(' ');
    final candidatos = palabras.asMap().entries
        .where((e) => e.value.replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]'), '').length >= 6)
        .map((e) => e.key)
        .toList()..shuffle(Random());
    _indicesNegrita = candidatos.take(4).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final palabras = widget.texto.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < palabras.length; i++) {
      final negrita = _indicesNegrita.contains(i);
      spans.add(TextSpan(
        text: i < palabras.length - 1 ? '${palabras[i]} ' : palabras[i],
        style: GoogleFonts.manrope(
          color: const Color(0xFFF3EBD6),
          fontSize: 14,
          fontWeight: negrita ? FontWeight.w700 : FontWeight.w300,
          height: 1.75,
          letterSpacing: 0.1,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _ChipPlaneta extends StatefulWidget {
  final double width;
  final EdgeInsets margin;
  final String simbolo;
  final String nombre;
  final int grado;
  final String signo;
  final bool seleccionado;
  final VoidCallback onTap;
  const _ChipPlaneta({
    required this.width,
    required this.margin,
    required this.simbolo,
    required this.nombre,
    required this.grado,
    required this.signo,
    required this.seleccionado,
    required this.onTap,
  });
  @override
  State<_ChipPlaneta> createState() => _ChipPlanetaState();
}

class _ChipPlanetaState extends State<_ChipPlaneta> {
  bool _pressed = false;

  void _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final selec = widget.seleccionado;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          margin: widget.margin,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selec ? Colors.black : const Color(0xFFFAF6EE),
            borderRadius: BorderRadius.circular(10),
            boxShadow: selec ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.simbolo,
                      style: TextStyle(fontSize: 13, color: selec ? const Color(0xFFF3EBD6) : Colors.black87)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${widget.nombre}  ${widget.grado}°',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selec ? const Color(0xFFF3EBD6) : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'En ${widget.signo}',
                style: TextStyle(
                  fontSize: 10,
                  color: selec ? const Color(0xFFF3EBD6).withOpacity(0.7) : Colors.black38,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


