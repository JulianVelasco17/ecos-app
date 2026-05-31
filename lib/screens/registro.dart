import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../services/calculos_astrales.dart';
import 'constelacion_widget.dart';
import 'crear_credenciales.dart';
import 'home.dart';
import '../main.dart';

// ─── Posición de cada estación en el mundo 2D ─────────────────────────────────
class _Estacion {
  final Offset posicion;
  const _Estacion(this.posicion);
}

const _estaciones = [
  _Estacion(Offset(0, 0)),
  _Estacion(Offset(220, -140)),
  _Estacion(Offset(-180, -320)),
  _Estacion(Offset(200, -480)),
  _Estacion(Offset(-120, -640)),
];

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro>
    with SingleTickerProviderStateMixin {

  final _focusUsuario = FocusNode();

  late AnimationController _camaraCtrl;
  late Animation<Offset>   _offsetAnim;

  int _estacionActual = 1;
  bool _verificandoUsuario = false;
  String? _errorUsuario;
  bool _intentoAvanzarSinFecha  = false;
  bool _intentoAvanzarSinHora   = false;
  bool _intentoAvanzarSinLugar  = false;

  final _usuarioCtrl = TextEditingController();
  final _lugarCtrl   = TextEditingController();
  DateTime?  _fecha;
  TimeOfDay? _hora;
  double?    _lat, _lon;

  @override
  void initState() {
    super.initState();
    _camaraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _offsetAnim = AlwaysStoppedAnimation(_estaciones[_estacionActual].posicion);
  }

  @override
  void dispose() {
    _camaraCtrl.dispose();
    _usuarioCtrl.dispose();
    _lugarCtrl.dispose();
    _focusUsuario.dispose();
    super.dispose();
  }

  Future<void> _avanzar() async {
    if (_estacionActual == 1) {
      await _verificarYAvanzar();
    } else if (_estacionActual == 2 && _fecha == null) {
      setState(() => _intentoAvanzarSinFecha = true);
      return;
    } else if (_estacionActual == 3 && _hora == null) {
      setState(() => _intentoAvanzarSinHora = true);
      return;
    } else if (_estacionActual == 4 && _lat == null) {
      setState(() => _intentoAvanzarSinLugar = true);
      return;
    } else if (_estacionActual < _estaciones.length - 1) {
      _moverA(_estacionActual + 1);
    } else {
      _irAConstelacion();
    }
  }

  Future<void> _verificarYAvanzar() async {
    final usuario = _usuarioCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    if (usuario.isEmpty) return;

    setState(() { _verificandoUsuario = true; _errorUsuario = null; });

    final query = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('usuario', isEqualTo: usuario)
        .limit(1)
        .get();

    if (!mounted) return;

    if (query.docs.isNotEmpty) {
      setState(() { _verificandoUsuario = false; _errorUsuario = 'ese usuario ya existe'; });
    } else {
      setState(() { _verificandoUsuario = false; _errorUsuario = null; });
      _moverA(2);
    }
  }

  void _moverA(int idx) {
    final desde = _estaciones[_estacionActual];
    final hasta = _estaciones[idx];

    _offsetAnim = Tween<Offset>(begin: desde.posicion, end: hasta.posicion)
        .animate(CurvedAnimation(parent: _camaraCtrl, curve: Curves.easeOutCubic));

    setState(() {});
    _camaraCtrl.forward(from: 0).then((_) {
      setState(() => _estacionActual = idx);
      if (idx == 1) _focusUsuario.requestFocus();
    });
  }

  Future<void> _irAConstelacion() async {
    if (_fecha == null || _hora == null) return;
    final hora    = _hora!.hour;
    final minutos = _hora!.minute;
    final carta   = CalculosAstrales.calcular(
      fechaNacimiento: _fecha!,
      hora:     hora,
      minutos:  minutos,
      latitud:  _lat ?? 0.0,
      longitud: _lon ?? 0.0,
    );
    final usuario = _usuarioCtrl.text.toLowerCase().replaceAll(' ', '');

    // Guardar perfil en Firestore con uid anónimo para que la carta astral funcione
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'usuario':          usuario,
        'fechaNacimiento':  Timestamp.fromDate(_fecha!),
        'horaNacimiento':   '${hora.toString().padLeft(2,'0')}:${minutos.toString().padLeft(2,'0')}',
        'lugarNacimiento':  _lugarCtrl.text,
        'latitud':          _lat ?? 0.0,
        'longitud':         _lon ?? 0.0,
        'signoSolar':       carta.signoSolar,
        'signoLunar':       carta.signoLunar,
        'ascendente':       carta.ascendente,
        'planetas':         carta.planetas,
      }, SetOptions(merge: true));
    }
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => PantallaConstelacion(
          signo:           carta.signoSolar,
          nombre:          usuario,
          signoSolar:      carta.signoSolar,
          signoLunar:      carta.signoLunar,
          ascendente:      carta.ascendente,
          planetas:        carta.planetas,
          casas:           carta.casas,
          fechaNacimiento: _fecha!,
          hora:            hora,
          minutos:         minutos,
          onContinuar: (ctx) {
            final user = FirebaseAuth.instance.currentUser;
            final tieneSocial = user != null && !user.isAnonymous;
            Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(
                builder: (_) => tieneSocial
                    ? PantallaHome(nombre: usuario)
                    : PantallaCrearCredenciales(
                        nombre: usuario,
                        usuario: usuario,
                        fechaNacimiento: _fecha!,
                        horaNacimiento: _hora ?? const TimeOfDay(hour: 12, minute: 0),
                        lugarNacimiento: _lugarCtrl.text,
                        latitud: _lat ?? 0.0,
                        longitud: _lon ?? 0.0,
                      ),
              ),
            );
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buscarLugares(String query) async {
    if (query.length < 3) return [];
    final url = Uri.parse('https://photon.komoot.io/api/?q=$query&limit=5');
    final res = await http.get(url, headers: {'User-Agent': 'AstroApp/1.0'});
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return (data['features'] as List).map<Map<String, dynamic>>((item) {
      final props  = item['properties'];
      final coords = item['geometry']['coordinates'] as List;
      final nombre = props['name'] ?? '';
      final pais   = props['country'] ?? '';
      final estado = props['state'] ?? '';
      final label  = estado.isNotEmpty ? '$nombre, $estado, $pais' : '$nombre, $pais';
      return {'label': label, 'lat': (coords[1] as num).toDouble(), 'lon': (coords[0] as num).toDouble()};
    }).where((m) => (m['label'] as String).isNotEmpty).toList();
  }

  String _formatFecha(DateTime f) {
    const m = ['','enero','febrero','marzo','abril','mayo','junio',
                'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${f.day} de ${m[f.month]} de ${f.year}';
  }

  Widget _contenido(int idx, BuildContext ctx) {
    switch (idx) {
      case 1:
        return _Tarjeta(
          etiqueta: 'USUARIO',
          pregunta: '¿cómo quieres\nque te llamen?',
          onSiguiente: _avanzar,
          cargando: _verificandoUsuario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo(_usuarioCtrl, '@usuario', prefijo: '@', onSubmit: _avanzar, focusNode: _focusUsuario),
              if (_errorUsuario != null) ...[
                const SizedBox(height: 10),
                Text(_errorUsuario!,
                    style: const TextStyle(color: Color(0xFFE07070), fontSize: 12, letterSpacing: 0.5)),
              ],
            ],
          ),
        );
      case 2:
        return _Tarjeta(
          etiqueta: 'FECHA DE NACIMIENTO',
          pregunta: '¿cuándo\nnaciste?',
          onSiguiente: _avanzar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _selector(
                texto: _fecha != null ? _formatFecha(_fecha!) : 'seleccionar fecha',
                onTap: () async {
                  DateTime temp = _fecha ?? DateTime(1995);
                  await showModalBottomSheet(
                    context: ctx,
                    backgroundColor: const Color(0xFF111111),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => SizedBox(
                      height: 300,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('fecha de nacimiento',
                                    style: TextStyle(color: Color(0x88F3EBD6), fontSize: 12, letterSpacing: 1.5)),
                                GestureDetector(
                                  onTap: () {
                                    setState(() { _fecha = temp; _intentoAvanzarSinFecha = false; });
                                    Navigator.pop(ctx);
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('listo',
                                        style: TextStyle(color: Color(0xFFF3EBD6), fontSize: 13, letterSpacing: 1)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CupertinoTheme(
                              data: const CupertinoThemeData(brightness: Brightness.dark),
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.date,
                                initialDateTime: temp,
                                minimumDate: DateTime(1900),
                                maximumDate: DateTime.now(),
                                onDateTimeChanged: (d) => temp = d,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_intentoAvanzarSinFecha) ...[
                const SizedBox(height: 10),
                const Text('selecciona tu fecha de nacimiento',
                    style: TextStyle(color: Color(0xFFE07070), fontSize: 12, letterSpacing: 0.5)),
              ],
            ],
          ),
        );
      case 3:
        return _Tarjeta(
          etiqueta: 'HORA DE NACIMIENTO',
          pregunta: '¿a qué hora\nnaciste?',
          onSiguiente: _avanzar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _selector(
                texto: _hora != null ? _hora!.format(ctx) : 'seleccionar hora',
                onTap: () async {
                  DateTime temp = DateTime(2000, 1, 1, _hora?.hour ?? 12, _hora?.minute ?? 0);
                  await showModalBottomSheet(
                    context: ctx,
                    backgroundColor: const Color(0xFF111111),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => SizedBox(
                      height: 300,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('hora de nacimiento',
                                    style: TextStyle(color: Color(0x88F3EBD6), fontSize: 12, letterSpacing: 1.5)),
                                GestureDetector(
                                  onTap: () {
                                    setState(() { _hora = TimeOfDay(hour: temp.hour, minute: temp.minute); _intentoAvanzarSinHora = false; });
                                    Navigator.pop(ctx);
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('listo',
                                        style: TextStyle(color: Color(0xFFF3EBD6), fontSize: 13, letterSpacing: 1)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CupertinoTheme(
                              data: const CupertinoThemeData(brightness: Brightness.dark),
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.time,
                                initialDateTime: temp,
                                use24hFormat: true,
                                onDateTimeChanged: (d) => temp = d,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_intentoAvanzarSinHora) ...[
                const SizedBox(height: 10),
                const Text('la hora es necesaria para calcular tu carta astral',
                    style: TextStyle(color: Color(0xFFE07070), fontSize: 12, letterSpacing: 0.5)),
              ],
            ],
          ),
        );
      case 4:
      default:
        return _Tarjeta(
          etiqueta: 'LUGAR DE NACIMIENTO',
          pregunta: '¿dónde\nnaciste?',
          onSiguiente: _avanzar,
          labelBoton: 'CONTINUAR',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TypeAheadField<Map<String, dynamic>>(
                controller: _lugarCtrl,
                suggestionsCallback: _buscarLugares,
                builder: (context, ctrl, focus) => TextField(
                  controller: ctrl, focusNode: focus,
                  style: const TextStyle(color: Color(0xFFF3EBD6), fontSize: 22, fontWeight: FontWeight.w300),
                  decoration: const InputDecoration(
                    hintText: 'ciudad donde naciste',
                    hintStyle: TextStyle(color: Color(0x44F3EBD6)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0x33F3EBD6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0x88F3EBD6))),
                  ),
                ),
                itemBuilder: (_, lugar) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: ListTile(title: Text(lugar['label'] as String,
                      style: const TextStyle(color: Color(0xCCF3EBD6), fontSize: 13))),
                ),
                onSelected: (lugar) {
                  _lugarCtrl.text = lugar['label'] as String;
                  setState(() { _lat = lugar['lat']; _lon = lugar['lon']; _intentoAvanzarSinLugar = false; });
                },
              ),
              if (_intentoAvanzarSinLugar) ...[
                const SizedBox(height: 10),
                const Text('selecciona tu lugar de nacimiento de la lista',
                    style: TextStyle(color: Color(0xFFE07070), fontSize: 12, letterSpacing: 0.5)),
              ],
            ],
          ),
        );
    }
  }

  Widget _campo(TextEditingController ctrl, String hint,
      {String? prefijo, VoidCallback? onSubmit, bool autofocus = false, FocusNode? focusNode}) =>
      TextField(
        controller: ctrl, autofocus: autofocus, focusNode: focusNode,
        style: const TextStyle(color: Color(0xFFF3EBD6), fontSize: 26, fontWeight: FontWeight.w300),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Color(0x44F3EBD6), fontSize: 24),
          prefixText: prefijo,
          prefixStyle: const TextStyle(color: Color(0x88F3EBD6), fontSize: 26),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0x33F3EBD6))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0x88F3EBD6))),
        ),
        onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      );

  Widget _selector({required String texto, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x33F3EBD6)))),
          child: Text(texto, style: TextStyle(
            color: texto.startsWith('seleccionar') ? const Color(0x44F3EBD6) : const Color(0xFFF3EBD6),
            fontSize: 24, fontWeight: FontWeight.w300,
          )),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _estacionActual > 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaBienvenida()),
          (_) => false,
        );
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Estrellas de fondo ─────────────────────────────────────────────
          Positioned.fill(
            child: RepaintBoundary(
              child: CieloEstrellado(paralaje: _offsetAnim),
            ),
          ),
          // ── Mundo 2D (traslación sin rotación) ─────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _camaraCtrl,
              builder: (context, _) {
                final camara = _offsetAnim.value;
                return Stack(
                  alignment: Alignment.center,
                  children: _estaciones.asMap().entries.map((e) {
                    final i   = e.key;
                    final est = e.value;
                    final esCurrent = i == _estacionActual;
                    final relOffset = est.posicion - camara;
                    return Transform.translate(
                      offset: relOffset,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: esCurrent ? 1.0 : 0.0,
                        child: SizedBox(
                          width: 320,
                          child: esCurrent
                              ? Builder(builder: (ctx) => _contenido(i, ctx))
                              : const SizedBox.shrink(),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // ── Barra de progreso ────────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_estaciones.length - 1, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: (i + 1) == _estacionActual ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: (i + 1) == _estacionActual ? const Color(0xFFF3EBD6) : const Color(0x33F3EBD6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ),
            ),
          ),

          // ── Botón atrás ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Color(0x66F3EBD6), size: 18),
                onPressed: () {
                  if (_estacionActual > 1) {
                    _moverA(_estacionActual - 1);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

// ─── Tarjeta de campo ─────────────────────────────────────────────────────────
class _Tarjeta extends StatelessWidget {
  final String etiqueta;
  final String pregunta;
  final Widget child;
  final VoidCallback onSiguiente;
  final String labelBoton;
  final bool cargando;

  const _Tarjeta({
    required this.etiqueta,
    required this.pregunta,
    required this.child,
    required this.onSiguiente,
    this.labelBoton = 'SIGUIENTE',
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiqueta, style: const TextStyle(color: Color(0xAAF3EBD6), fontSize: 11, letterSpacing: 3)),
          const SizedBox(height: 20),
          Text(pregunta, style: const TextStyle(
            color: Color(0xFFF3EBD6), fontSize: 28,
            fontWeight: FontWeight.w300, letterSpacing: 1, height: 1.3,
          )),
          const SizedBox(height: 36),
          child,
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSiguiente,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3EBD6),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                elevation: 0,
              ),
              child: cargando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black45, strokeWidth: 1.5))
                  : Text(labelBoton, style: const TextStyle(letterSpacing: 3, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
