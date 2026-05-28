import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/fade_avatar.dart';
import '../services/debug_config.dart';
import '../widgets/loading_images.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/calculos_astrales.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';
import '../widgets/rueda_zodiacal.dart';
import 'lectura_carta_astral.dart';
import 'compra_carta_astral.dart';

class PantallaPerfilPropio extends StatefulWidget {
  final void Function(bool)? onCargandoChanged;
  const PantallaPerfilPropio({super.key, this.onCargandoChanged});

  @override
  State<PantallaPerfilPropio> createState() => _PantallaPerfilPropioState();
}

class _PantallaPerfilPropioState extends State<PantallaPerfilPropio>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _datos;
  CartaAstral? _carta;
  Map<String, double> _longitudes = {};
  double _ascLon = 0.0;
  List<Map<String, dynamic>> _guardadas = [];
  bool _cargando = true;
  late AnimationController _slideCtrl;
  int  _paginaCarta = 0;
  String? _planetaSeleccionado;
  double _dragStartX = 0;
  String _tabPerfil = 'carta';

  @override
  void initState() {
    super.initState();
    _cargar();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
      final p = (_slideCtrl.value + 0.5).floor().clamp(0, 1);
      if (p != _paginaCarta) setState(() => _paginaCarta = p);
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }


  Future<void> _cambiarFoto() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (imagen == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: imagen.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '',
          toolbarColor: const Color(0xFFF3EBD6),
          toolbarWidgetColor: Colors.black54,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: Colors.black,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: '',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseStorage.instance.ref().child('fotos_perfil/$uid.jpg');
    await ref.putData(await cropped.readAsBytes());
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({'fotoUrl': url});
    if (mounted) setState(() => _datos!['fotoUrl'] = url);
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!doc.exists) return;
    final datos = doc.data()!;

    final fecha = (datos['fechaNacimiento'] as dynamic).toDate() as DateTime;
    final horaParts = (datos['horaNacimiento'] as String).split(':');
    final latitud = (datos['latitud'] as num?)?.toDouble() ?? 0.0;
    final longitud = (datos['longitud'] as num?)?.toDouble() ?? 0.0;

    final hora = int.parse(horaParts[0]);
    final min  = int.parse(horaParts[1]);
    final carta = CalculosAstrales.calcular(
      fechaNacimiento: fecha,
      hora: hora,
      minutos: min,
      latitud: latitud,
      longitud: longitud,
    );
    final lons    = CalculosAstrales.calcularLongitudes(fecha, hora, min);
    final ascLon  = CalculosAstrales.calcularLongitudAscendente(fecha, hora, min, latitud, longitud);

    // Lectura por ámbitos — cache permanente por uid
    final uid2 = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cacheDoc = await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc('${uid2}_carta').get();

    Map<String, String> lectura = {};
    if (cacheDoc.exists) {
      final raw = cacheDoc.data()!;
      lectura = {
        'amor':    raw['amor']    as String? ?? '',
        'amistad': raw['amistad'] as String? ?? '',
        'suerte':  raw['suerte']  as String? ?? '',
        'familia': raw['familia'] as String? ?? '',
        'dinero':  raw['dinero']  as String? ?? '',
      };
    } else {
      final aspectos = AspectosNatales.calcular(fecha, int.parse(horaParts[0]), int.parse(horaParts[1]));
      final etiquetas = aspectos.map((a) =>
          '${a.planeta1} ${a.tipo} ${a.planeta2} (orbe ${a.orbe.toStringAsFixed(1)}°)').toList();
      final rawStr = await ClaudeService.generarLecturaProfunda(
        nombre:     datos['usuario'] as String? ?? '',
        signoSolar: carta.signoSolar,
        signoLunar: carta.signoLunar,
        ascendente: carta.ascendente,
        aspectos:   etiquetas,
      );
      try {
        final start = rawStr.indexOf('{');
        final end   = rawStr.lastIndexOf('}');
        final json  = jsonDecode(rawStr.substring(start, end + 1)) as Map<String, dynamic>;
        lectura = {
          'amor':    json['amor']    as String? ?? '',
          'amistad': json['amistad'] as String? ?? '',
          'suerte':  json['suerte']  as String? ?? '',
          'familia': json['familia'] as String? ?? '',
          'dinero':  json['dinero']  as String? ?? '',
        };
      } catch (_) {
        lectura = {};
      }
      if (lectura.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('lecturasProfundas').doc('${uid2}_carta')
            .set({...lectura, 'fecha': FieldValue.serverTimestamp()});
      }
    }

    final guardadasSnap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('lecturasGuardadas')
        .orderBy('fecha', descending: true)
        .get();

    final guardadas = guardadasSnap.docs.map((d) => d.data()).toList();

    if (mounted) {
      setState(() {
        _datos      = datos;
        _carta      = carta;
        _longitudes = lons;
        _ascLon     = ascLon;

        _guardadas  = guardadas;
        _cargando   = false;
      });
      widget.onCargandoChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: _cargando
            ? const LoadingImages(pegadoDerecha: true)
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + nombre + datos centrados
                    Center(
                      child: Column(
                        children: [
                          // Avatar con botón editar
                          GestureDetector(
                            onTap: _cambiarFoto,
                            child: Stack(
                              children: [
                                FadeAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.black12,
                                  fotoUrl: _datos?['fotoUrl'],
                                  fallbackChild: _datos?['fotoUrl'] == null
                                      ? Text(
                                          (_datos?['usuario'] ?? '?')[0].toLowerCase(),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 11, color: Color(0xFFF3EBD6)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Nombre + arroba
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _datos?['usuario'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF222222),
                                  fontSize: 28,
                                  fontFamily: 'PlayfairDisplay',
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '@${_datos?['usuario'] ?? ''}',
                                style: GoogleFonts.montserrat(
                                  color: Colors.black38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Fecha · hora · lugar en una línea
                          Text(
                            '${_formatearFechaCorta((_datos!['fechaNacimiento'] as dynamic).toDate() as DateTime)}  ·  ${_datos?['horaNacimiento'] ?? ''}  ·  ${(_datos?['lugarNacimiento'] ?? '').toUpperCase()}',
                            style: GoogleFonts.courierPrime(
                              color: const Color(0xFF777777),
                              fontSize: 11,
                              letterSpacing: 2.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 16),

                    // ── Tab selector ──
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0x1A000000), width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _TabBtn(label: 'Carta Natal', selected: _tabPerfil == 'carta',     onTap: () => setState(() => _tabPerfil = 'carta'))),
                          Expanded(child: _TabBtn(label: 'Guardadas',   selected: _tabPerfil == 'guardadas', onTap: () => setState(() => _tabPerfil = 'guardadas'))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (_tabPerfil == 'carta') ...[

                    // Carta natal — mapa deslizable → tabla
                    const Text(
                      'CARTA NATAL',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Indicadores de página
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(2, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width:  _paginaCarta == i ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _paginaCarta == i ? Colors.black54 : Colors.black12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                    ),

                    const SizedBox(height: 12),

                    // Rueda + chips (p0) ↔ tabla (p1) con slide animado
                    LayoutBuilder(builder: (context, constraints) {
                      final w = constraints.maxWidth;
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
                      final chipEntries = _longitudes.entries.toList();
                      final chipW = (w - 16) / 3;
                      final rows = <Widget>[];
                      for (var i = 0; i < chipEntries.length; i += 3) {
                        final rowItems = chipEntries.skip(i).take(3).toList();
                        rows.add(Row(
                          children: List.generate(3, (j) {
                            if (j >= rowItems.length) {
                              return SizedBox(width: chipW + (j < 2 ? 8 : 0));
                            }
                            final e = rowItems[j];
                            final nombre       = e.key;
                            final lon          = e.value;
                            final grado        = (lon % 30).floor();
                            final signo        = signosLista[((lon % 360) / 30).floor() % 12];
                            final simPlan      = simPlanetas[nombre] ?? '·';
                            final selec        = _planetaSeleccionado == nombre;
                            return _ChipPlaneta(
                              width: chipW,
                              margin: EdgeInsets.only(right: j < 2 ? 8 : 0),
                              simbolo: simPlan,
                              nombre: nombre,
                              grado: grado,
                              signo: signo,
                              seleccionado: selec,
                              onTap: () => setState(() =>
                                  _planetaSeleccionado = selec ? null : nombre),
                            );
                          }),
                        ));
                        if (i + 3 < chipEntries.length) rows.add(const SizedBox(height: 8));
                      }
                      final chipsWidget = Column(children: rows);

                      // Altura estimada para cada página
                      final totalPlanetas = 3 + (_carta?.planetas.length ?? 8);
                      final tableH  = totalPlanetas * 43.0 + 96.0;
                      final chipsH  = 272.0;
                      final wheelH  = w + 12.0 + chipsH;

                      return AnimatedBuilder(
                        animation: _slideCtrl,
                        builder: (context, _) {
                          final p = _slideCtrl.value;
                          final height = wheelH + (tableH - wheelH) * p;
                          return GestureDetector(
                            onHorizontalDragStart: (d) =>
                                _dragStartX = d.localPosition.dx,
                            onHorizontalDragUpdate: (d) {
                              final delta =
                                  (d.localPosition.dx - _dragStartX) / w;
                              _slideCtrl.value =
                                  (_slideCtrl.value - delta).clamp(0.0, 1.0);
                              _dragStartX = d.localPosition.dx;
                            },
                            onHorizontalDragEnd: (d) {
                              final vel = d.primaryVelocity ?? 0;
                              if (vel < -200 ||
                                  (_slideCtrl.value >= 0.4 && vel >= -200)) {
                                _slideCtrl.animateTo(1.0,
                                    curve: Curves.easeOut);
                              } else {
                                _slideCtrl.animateTo(0.0,
                                    curve: Curves.easeOut);
                              }
                            },
                            child: ClipRect(
                              child: SizedBox(
                                height: height,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Página 0: rueda + chips
                                    Positioned(
                                      left: -p * w,
                                      top: 0,
                                      width: w,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RepaintBoundary(
                                            child: SizedBox(
                                              width: w,
                                              height: w,
                                              child: CustomPaint(
                                                painter: RuedaZodiacalPainter(
                                                  planetasDesdeLongitudes(
                                                      _longitudes, _ascLon),
                                                  seleccionado:
                                                      _planetaSeleccionado,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          chipsWidget,
                                        ],
                                      ),
                                    ),
                                    // Página 1: tabla
                                    Positioned(
                                      left: (1 - p) * w,
                                      top: 0,
                                      width: w,
                                      child: _TablaNatal(carta: _carta!),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),

                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () {
                        final cartaActiva = _datos?['cartaActiva'] == true;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => cartaActiva
                                ? const PantallaLecturaCartaAstral()
                                : const PantallaCompraCarta(),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Text('✦', style: TextStyle(color: Color(0xFFB8973A), fontSize: 13)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('LECTURA PROFUNDA',
                                      style: TextStyle(color: Color(0xFFB8973A),
                                          fontSize: 10, letterSpacing: 3)),
                                  SizedBox(height: 4),
                                  Text('Tu carta natal completa',
                                      style: TextStyle(color: Color(0xFFE7D8C9),
                                          fontSize: 13, fontWeight: FontWeight.w300,
                                          letterSpacing: 0.3)),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                color: Color(0x44E7D8C9), size: 14),
                          ],
                        ),
                      ),
                    ),
                    if (DebugConfig.instance.activo) ...[
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PantallaCompraCarta())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('debug: ver pantalla de compra →',
                            style: TextStyle(color: const Color(0xFFB8973A).withValues(alpha: 0.4),
                                fontSize: 11, letterSpacing: 1.5)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;
                        await FirebaseFirestore.instance
                            .collection('lecturasProfundas')
                            .doc('${uid}_carta_v3')
                            .delete();
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const PantallaLecturaCartaAstral()));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('debug: regenerar reporte →',
                            style: TextStyle(color: const Color(0xFFB8973A).withValues(alpha: 0.4),
                                fontSize: 11, letterSpacing: 1.5)),
                      ),
                    ),
                    ],
                    const SizedBox(height: 48),

                    ], // end carta tab

                    if (_tabPerfil == 'guardadas') ...[
                      if (_guardadas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text('aún no tienes lecturas guardadas',
                              style: GoogleFonts.manrope(
                                  color: Colors.black26, fontSize: 13)),
                        )
                      else ...[
                        const Text('GUARDADAS',
                            style: TextStyle(color: Colors.black45, fontSize: 11, letterSpacing: 3)),
                        const SizedBox(height: 24),

                        ..._guardadas.map((g) {
                          final frase = g['frase'] as String? ?? '';
                          final ts = g['fecha'];
                          String fechaStr = '';
                          if (ts != null) {
                            final dt = (ts as dynamic).toDate() as DateTime;
                            const meses = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
                            fechaStr = '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fechaStr.isNotEmpty)
                                  Text(fechaStr,
                                      style: const TextStyle(
                                          color: Colors.black38, fontSize: 10, letterSpacing: 2)),
                                const SizedBox(height: 8),
                                Text(frase,
                                    style: const TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      color: Color(0xFF222222),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                      letterSpacing: 0.5,
                                    )),
                                const SizedBox(height: 16),
                                const Divider(color: Colors.black12),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  String _gradosASigno(double grados) {
    const signos = [
      'Aries','Tauro','Géminis','Cáncer','Leo','Virgo',
      'Libra','Escorpio','Sagitario','Capricornio','Acuario','Piscis'
    ];
    return signos[((grados % 360) / 30).floor() % 12];
  }

  String _signoCorto(String signo) {
    const abrevs = {
      'Aries':'♈','Tauro':'♉','Géminis':'♊','Cáncer':'♋',
      'Leo':'♌','Virgo':'♍','Libra':'♎','Escorpio':'♏',
      'Sagitario':'♐','Capricornio':'♑','Acuario':'♒','Piscis':'♓',
    };
    return abrevs[signo] ?? signo;
  }

  String _formatearFechaCorta(DateTime fecha) {
    const meses = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}'.toUpperCase();
  }
}

// ─── Tabla natal oscura agrupada por signo ────────────────────────────────────

class _TablaNatal extends StatelessWidget {
  final CartaAstral carta;

  const _TablaNatal({required this.carta});

  static const _simbolosPlaneta = {
    'Ascendente': '↑',
    'Sol':        '☉',
    'Luna':       '☽',
    'Mercurio':   '☿',
    'Venus':      '♀',
    'Marte':      '♂',
    'Júpiter':    '♃',
    'Saturno':    '♄',
    'Urano':      '♅',
    'Neptuno':    '♆',
    'Plutón':     '♇',
  };

  static const _acento = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    final entradas = <(String, String)>[
      ('Ascendente', carta.ascendente),
      ...carta.planetas.entries
          .where((e) => e.key != 'Sol' && e.key != 'Luna')
          .map((e) => (e.key, e.value)),
      ('Sol',        carta.signoSolar),
      ('Luna',       carta.signoLunar),
    ];

    final Map<String, List<String>> porSigno = {};
    for (final e in entradas) {
      porSigno.putIfAbsent(e.$2, () => []).add(e.$1);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tabla principal ──────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Títulos de columnas
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text('SIGNS',
                        style: TextStyle(
                            color: _acento, fontSize: 9, letterSpacing: 2)),
                  ),
                  Text('PLANET / POINT',
                      style: TextStyle(
                          color: _acento, fontSize: 9, letterSpacing: 2)),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(color: Colors.black12, height: 1),

              // Filas agrupadas por signo
              ...porSigno.entries.map((entry) {
                final signo    = entry.key;
                final planetas = entry.value;
                return Column(
                  children: planetas.asMap().entries.map((pe) {
                    final idx     = pe.key;
                    final planeta = pe.value;
                    final simPlan = _simbolosPlaneta[planeta] ?? '●';
                    final casa    = planeta == 'Ascendente' ? 1 : carta.casas[planeta];
                    return Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          // Signo — solo en primera fila del grupo
                          SizedBox(
                            width: 100,
                            child: idx == 0
                                ? Text(signo,
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: 0.3))
                                : const SizedBox.shrink(),
                          ),
                          // Planeta
                          Expanded(
                            child: Row(children: [
                              Text('$simPlan ',
                                  style: TextStyle(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      fontSize: 13)),
                              Text(planeta.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.5)),
                            ]),
                          ),
                          // Casa
                          SizedBox(
                            width: 28,
                            child: casa != null
                                ? Text('$casa',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500))
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        ),

        // ── Label "HOUSES" vertical ──────────────────────────────────────
        Container(
          width: 22,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: RotatedBox(
            quarterTurns: 1,
            child: Text('CASAS',
                style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.2),
                    fontSize: 8,
                    letterSpacing: 3)),
          ),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.black38,
                fontSize: 14,
                letterSpacing: 0.3,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                fontFamily: 'PlayfairDisplay',
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 1.5,
            color: selected ? Colors.black87 : Colors.transparent,
          ),
        ],
      ),
    );
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
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
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
                  color: selec ? const Color(0xFFF3EBD6).withValues(alpha: 0.7) : Colors.black38,
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
