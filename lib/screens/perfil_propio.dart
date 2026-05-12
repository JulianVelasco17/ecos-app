import 'dart:convert';
import 'package:flutter/material.dart';
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
import 'lectura_carta_profunda.dart';
import 'compra_carta_astral.dart';

class PantallaPerfilPropio extends StatefulWidget {
  final void Function(bool)? onCargandoChanged;
  const PantallaPerfilPropio({super.key, this.onCargandoChanged});

  @override
  State<PantallaPerfilPropio> createState() => _PantallaPerfilPropioState();
}

class _PantallaPerfilPropioState extends State<PantallaPerfilPropio> {
  Map<String, dynamic>? _datos;
  CartaAstral? _carta;
  Map<String, double> _longitudes = {};
  double _ascLon = 0.0;
  Map<String, String> _lectura = {};
  List<Map<String, dynamic>> _guardadas = [];
  bool _cargando = true;
  final _pageCtrl  = PageController();
  int  _paginaCarta = 0;
  String? _planetaSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargar();
    _pageCtrl.addListener(() {
      final p = _pageCtrl.page?.round() ?? 0;
      if (p != _paginaCarta) setState(() => _paginaCarta = p);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
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
        nombre:     datos['nombre'] as String? ?? '',
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
        _lectura    = lectura;
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
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black12))
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
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.black12,
                                  backgroundImage: _datos?['fotoUrl'] != null
                                      ? NetworkImage(_datos!['fotoUrl'])
                                      : null,
                                  child: _datos?['fotoUrl'] == null
                                      ? Text(
                                          (_datos?['nombre'] ?? '?')[0].toLowerCase(),
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
                                _datos?['nombre'] ?? '',
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

                    // PageView horizontal: rueda ↔ tabla
                    LayoutBuilder(builder: (context, constraints) {
                      final ruedaSize = constraints.maxWidth;
                      final alturaPageView = ruedaSize; // siempre cuadrado
                      return SizedBox(
                        height: alturaPageView,
                        child: PageView(
                          controller: _pageCtrl,
                          children: [
                            // Página 1: rueda
                            RepaintBoundary(
                              child: SizedBox(
                                width:  ruedaSize,
                                height: ruedaSize,
                                child: CustomPaint(
                                  painter: RuedaZodiacalPainter(
                                    planetasDesdeLongitudes(_longitudes, _ascLon),
                                    seleccionado: _planetaSeleccionado,
                                  ),
                                ),
                              ),
                            ),

                            // Página 2: tabla scrolleable
                            SingleChildScrollView(child: _TablaNatal(carta: _carta!)),
                          ],
                        ),
                      );
                    }),

                    // Indicadores de página
                    const SizedBox(height: 12),
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

                    const SizedBox(height: 16),

                    // Chips de planetas
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _longitudes.entries.map((e) {
                        final nombre   = e.key;
                        final lon      = e.value;
                        final gradoEnSigno = lon % 30;
                        final signoAbrev = _signoCorto(_gradosASigno(lon));
                        final selec    = _planetaSeleccionado == nombre;
                        return GestureDetector(
                          onTap: () => setState(() =>
                            _planetaSeleccionado = selec ? null : nombre),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selec ? Colors.black : Colors.transparent,
                              border: Border.all(
                                color: selec ? Colors.black : Colors.black26,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '$nombre  $signoAbrev ${gradoEnSigno.floor()}°',
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
                    GestureDetector(
                      onTap: () {
                        final cartaActiva = _datos?['cartaActiva'] == true;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => cartaActiva
                                ? const PantallaLecturaCartaProfunda()
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
                    const SizedBox(height: 48),

                    if (_lectura.isNotEmpty) ...[
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 40),

                      const Text('TU LECTURA',
                          style: TextStyle(color: Colors.black45, fontSize: 11, letterSpacing: 3)),
                      const SizedBox(height: 32),

                      ...[
                        ('AMOR',    '♡', _lectura['amor']    ?? ''),
                        ('AMISTAD', '◇', _lectura['amistad'] ?? ''),
                        ('SUERTE',  '✦', _lectura['suerte']  ?? ''),
                        ('FAMILIA', '○', _lectura['familia'] ?? ''),
                        ('DINERO',  '△', _lectura['dinero']  ?? ''),
                      ].where((e) => e.$3.isNotEmpty).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(e.$2, style: const TextStyle(color: Colors.black38, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text(e.$1, style: const TextStyle(color: Colors.black38,
                                  fontSize: 10, letterSpacing: 3)),
                            ]),
                            const SizedBox(height: 10),
                            Text(e.$3, style: const TextStyle(color: Colors.black87,
                                fontSize: 14, fontWeight: FontWeight.w300, height: 1.75)),
                          ],
                        ),
                      )),

                      const SizedBox(height: 12),
                    ],

                    if (_guardadas.isNotEmpty) ...[
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 40),

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
  };

  static const _gold = Color(0xFFB8973A);
  static const _bg   = Color(0xFF1C1C1C);

  @override
  Widget build(BuildContext context) {
    // Construir lista planeta → signo en orden fijo
    final entradas = <(String, String)>[
      ('Ascendente', carta.ascendente),
      ('Sol',        carta.signoSolar),
      ('Luna',       carta.signoLunar),
      ...carta.planetas.entries.map((e) => (e.key, e.value)),
    ];

    // Agrupar por signo manteniendo orden de primera aparición
    final Map<String, List<String>> porSigno = {};
    for (final e in entradas) {
      porSigno.putIfAbsent(e.$2, () => []).add(e.$1);
    }

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabecera
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tu carta natal',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.3)),
                Text('Posiciones planetarias',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                        letterSpacing: 0.5)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Fila de títulos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text('SIGNO',
                      style: TextStyle(
                          color: _gold, fontSize: 10, letterSpacing: 2)),
                ),
                Expanded(
                  child: Text('PLANETA / PUNTO',
                      style: TextStyle(
                          color: _gold, fontSize: 10, letterSpacing: 2)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

          // Filas agrupadas
          ...porSigno.entries.map((entry) {
            final signo    = entry.key;
            final planetas = entry.value;
            final simboloSigno = simbolosSignos[signo] ?? '';
            return Column(
              children: planetas.asMap().entries.map((pe) {
                final idx     = pe.key;
                final planeta = pe.value;
                final simPlan = _simbolosPlaneta[planeta] ?? '●';
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      // Columna signo — solo en primera fila del grupo
                      Expanded(
                        child: idx == 0
                            ? Row(children: [
                                Text('$simboloSigno ',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 16)),
                                Text(signo,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: 0.3)),
                              ])
                            : const SizedBox.shrink(),
                      ),
                      // Columna planeta
                      Expanded(
                        child: Row(children: [
                          Text('$simPlan ',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 15)),
                          Text(planeta.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1.5)),
                        ]),
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
    );
  }
}
