import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/claude_service.dart';

// ─── Banco de preguntas (lunes) — 52 semanas ─────────────────────────────────
const _preguntas = [
  '¿Cuál es tu recuerdo favorito de nosotros?',
  '¿Qué es lo primero que piensas cuando te despiertas a mi lado?',
  '¿Qué cosa pequeña hago que te hace sonreír sin que yo lo sepa?',
  '¿Qué lugar del mundo quieres visitar conmigo?',
  '¿Cuándo fue el momento en que supiste que esto era real?',
  '¿Qué es lo que más admiras de mí?',
  '¿Qué canción te recuerda a nosotros?',
  '¿Qué harías si pudiéramos desaparecer un día entero sin planes?',
  '¿Qué aprendiste de mí que no sabías de ti mismo?',
  '¿Cuál es tu versión favorita de nosotros?',
  '¿Qué momento de esta semana quisieras repetir?',
  '¿Qué es lo que más extrañas cuando no estamos juntos?',
  '¿Cuál es nuestra conversación favorita que hemos tenido?',
  '¿Qué cosa sencilla te hace sentir más querido por mí?',
  '¿Qué aventura pequeña quieres que hagamos pronto?',
  '¿En qué momento me ves más tú mismo?',
  '¿Qué me dirías si supieras que te escucho sin juzgarte?',
  '¿Qué es lo que más te tranquiliza de estar conmigo?',
  '¿Qué rutina nuestra te gusta más?',
  '¿Qué te sorprende todavía de mí?',
  '¿Cuál es la mejor decisión que hemos tomado juntos?',
  '¿Qué cosa de mí te genera ternura?',
  '¿Qué te gustaría que hiciéramos más seguido?',
  '¿Cuándo te sientes más conectado conmigo?',
  '¿Qué es lo que más te gusta de cómo nos reímos juntos?',
  '¿Qué miedos has perdido desde que estamos juntos?',
  '¿Qué versión de mi futuro te emociona más?',
  '¿Qué cosa tuya crees que yo no valoro suficiente?',
  '¿Qué momento nuestro guardarías en un frasco?',
  '¿Qué parte de mí conoces que nadie más conoce?',
  '¿Qué cosa de nuestra historia contarías primero a alguien?',
  '¿Cuándo fue la última vez que pensaste "qué suerte tengo"?',
  '¿Qué harías por mí sin que yo te lo pidiera?',
  '¿Qué palabra te describe cuando estás conmigo?',
  '¿Qué cosa de nosotros quieres que nunca cambie?',
  '¿Qué sueño tuyo quieres que yo sea parte?',
  '¿Cuándo fue la última vez que te sorprendí de una forma que te gustó?',
  '¿Qué parte de mí te costó más entender?',
  '¿Qué cosa pequeña nuestra te parece especial aunque nadie más lo entienda?',
  '¿Qué harías si pudieras darme un día perfecto?',
  '¿Cuál es tu gesto favorito mío?',
  '¿Qué te hace sentir que estoy orgulloso de ti?',
  '¿Qué emoción sientes más seguido conmigo?',
  '¿Qué te gustaría que supiéramos hacer juntos?',
  '¿Qué escena de película nos parece más nuestra?',
  '¿Qué cosa nueva quieres aprender conmigo?',
  '¿Cuál es tu hora favorita del día cuando estamos juntos?',
  '¿Qué me dirías en una nota anónima?',
  '¿Qué momento inesperado se convirtió en uno de tus favoritos?',
  '¿Qué es lo que más te gusta de cómo me quieres?',
  '¿Qué frase tuya podría ser nuestra?',
  '¿Qué te gustaría que fuera tradición entre nosotros?',
];

// ─── Banco de retos (sábado) — 52 semanas ────────────────────────────────────
const _retos = [
  'Cocinemos algo nuevo juntos hoy, sin receta.',
  'Daos un masaje de 10 minutos cada uno. Sin prisa.',
  'Elegid una película que ninguno haya visto y no la pauséis.',
  'Haced una lista de 10 cosas que os gustan del otro. Compartidla.',
  'Id a dar un paseo sin destino. Solo seguid lo que os llame.',
  'Elegid una canción que describa vuestra historia. Escuchadla juntos.',
  'Preparad el desayuno favorito del otro.',
  'Haced algo que el otro siempre ha querido hacer pero nunca han hecho.',
  'Pasad una hora sin teléfonos. Solo vosotros.',
  'Escribid cada uno una carta de una página al otro. Leedlas en voz alta.',
  'Buscad un sitio nuevo en vuestra ciudad al que nunca hayáis ido.',
  'Cread una playlist juntos. 10 canciones cada uno.',
  'Mirad fotos antiguas vuestras y contad la historia detrás de una.',
  'Haced algo físico juntos: bailar, caminar, estirarse.',
  'Comprad algo pequeño para el otro sin gastar más de 5 euros.',
  'Elegid un tema que ninguno sabe nada y aprended algo juntos.',
  'Haced una cena con velas aunque sea en casa.',
  'Contad cada uno algo que no habéis contado nunca.',
  'Dibujad al otro. Sin juzgar el resultado.',
  'Elegid un juego de mesa o de cartas. El que pierde hace un forfait.',
  'Buscad un atardecer o un amanecer para verlo juntos.',
  'Escribid vuestros planes para el próximo año. Comparadlos.',
  'Daos un abrazo largo. Más de 30 segundos. Sin soltaros antes.',
  'Cocinad una receta del país favorito del otro.',
  'Cread un ritual pequeño que sea solo vuestro.',
  'Elegid una serie nueva y ved el primer episodio.',
  'Id al mercado o supermercado y elegid juntos algo que nunca hayáis probado.',
  'Haced una lista de lugares a los que queréis ir juntos algún día.',
  'Pasad una hora haciendo cada uno lo que el otro disfruta.',
  'Contad el mejor recuerdo de infancia que tengáis.',
  'Tomad café o té en silencio cómodo, sin distracciones.',
  'Elegid una foto favorita de vosotros y explicad por qué.',
  'Haced algo creativo juntos: dibujar, escribir, cantar, lo que sea.',
  'Daos un tour mental de vuestra casa soñada.',
  'Contad cómo os habéis visto cambiar desde que estáis juntos.',
  'Preparad una cesta de picnic aunque sea en el salón.',
  'Leed juntos un artículo sobre algo que os interese a los dos.',
  'Haced algo que os dé un poco de miedo juntos.',
  'Buscad en internet el lugar más bonito cerca de vosotros e id.',
  'Elegid cada uno su película favorita. Votad cuál ver.',
  'Haced una lista de "las cosas que hacemos bien juntos".',
  'Pasad la tarde sin agenda. Lo que surja.',
  'Cocinad algo sin mirarse, solo guiándose por la voz.',
  'Elegid un podcast y escuchadlo dando un paseo.',
  'Haced una llamada a alguien que queráis los dos.',
  'Escribid juntos la historia de cómo os conocisteis, con todos los detalles.',
  'Buscad un mercadillo, feria o mercado de segunda mano.',
  'Descubrid juntos un artista, músico o fotógrafo que no conocíais.',
  'Haced algo bueno por alguien más, juntos.',
  'Elegid una actividad manual: origami, pintura de uñas, trenzas, lo que queráis.',
  'Cread un menú de restaurante imaginario con vuestros platos favoritos.',
  'Pasad el día haciéndoos pequeños gestos sin decir por qué.',
];

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _semanaKey() {
  final hoy    = DateTime.now();
  final inicio = DateTime(hoy.year, 1, 1);
  final semana = ((hoy.difference(inicio).inDays) / 7).floor();
  return '${hoy.year}-$semana';
}

int _semanaIndex() {
  final hoy    = DateTime.now();
  final inicio = DateTime(hoy.year, 1, 1);
  return ((hoy.difference(inicio).inDays) / 7).floor() % 52;
}

// ─── Widget principal ─────────────────────────────────────────────────────────

class VenusActividadDiaria extends StatefulWidget {
  final String miUid;
  final String parejaUid;
  final String miNombre;
  final String parejaName;

  const VenusActividadDiaria({
    super.key,
    required this.miUid,
    required this.parejaUid,
    required this.miNombre,
    required this.parejaName,
  });

  @override
  State<VenusActividadDiaria> createState() => _VenusActividadDiariaState();
}

class _VenusActividadDiariaState extends State<VenusActividadDiaria> {
  final _ctrl      = TextEditingController();
  bool _enviado    = false;
  bool _cargando   = true;
  bool _enviando   = false;
  String? _miRespuesta;
  String? _suRespuesta;   // respuesta de la pareja (viernes)
  String? _planClaude;    // viernes: plan combinado Claude

  // Miércoles
  File?   _imagenSeleccionada;

  // Martes: caption Claude
  String? _captionMartes;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _debugDia = 0; // 0 = usar día real
  int get _diaSemana => _debugDia > 0 ? _debugDia : DateTime.now().weekday;

  Future<void> _cargar() async {
    final sk = _semanaKey();

    // ── Ver si ya respondí esta actividad ──
    final miDoc = await FirebaseFirestore.instance
        .collection('venus_actividades')
        .doc('${sk}_dia$_diaSemana')
        .collection('respuestas')
        .doc(widget.miUid)
        .get();

    if (miDoc.exists) {
      _miRespuesta = miDoc.data()!['respuesta'] as String?;
      _enviado = true;
    }

    // ── Viernes: cargar también la respuesta de la pareja ──
    if (_diaSemana == 5) {
      final parejaDoc = await FirebaseFirestore.instance
          .collection('venus_actividades')
          .doc('${sk}_dia4') // jueves
          .collection('respuestas')
          .doc(widget.parejaUid)
          .get();
      if (parejaDoc.exists) {
        _suRespuesta = parejaDoc.data()!['respuesta'] as String?;
      }
      final miPlan = await FirebaseFirestore.instance
          .collection('venus_actividades')
          .doc('${sk}_dia4')
          .collection('respuestas')
          .doc(widget.miUid)
          .get();
      if (miPlan.exists) {
        _miRespuesta = miPlan.data()!['respuesta'] as String?;
      }

      // Plan Claude cacheado
      if (_miRespuesta != null && _suRespuesta != null) {
        final cacheDoc = await FirebaseFirestore.instance
            .collection('venus_actividades')
            .doc('${sk}_plan_combinado')
            .get();
        if (cacheDoc.exists) {
          _planClaude = cacheDoc.data()!['plan'] as String?;
        } else {
          _planClaude = await ClaudeService.generarPlanFinde(
            nombre1: widget.miNombre,
            plan1:   _miRespuesta!,
            nombre2: widget.parejaName,
            plan2:   _suRespuesta!,
          );
          await FirebaseFirestore.instance
              .collection('venus_actividades')
              .doc('${sk}_plan_combinado')
              .set({'plan': _planClaude, 'fecha': FieldValue.serverTimestamp()});
        }
      }
    }

    // ── Martes: generar caption Claude ──
    if (_diaSemana == 2) {
      final cacheDoc = await FirebaseFirestore.instance
          .collection('venus_actividades')
          .doc('${sk}_martes_${widget.miUid}')
          .get();
      if (cacheDoc.exists) {
        _captionMartes = cacheDoc.data()!['caption'] as String?;
      } else {
        _captionMartes = await ClaudeService.generarCaptionValoracion(
          miNombre:     widget.miNombre,
          parejaName:   widget.parejaName,
        );
        await FirebaseFirestore.instance
            .collection('venus_actividades')
            .doc('${sk}_martes_${widget.miUid}')
            .set({'caption': _captionMartes, 'fecha': FieldValue.serverTimestamp()});
      }
    }

    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _enviar({String? textoExtra}) async {
    final texto = textoExtra ?? _ctrl.text.trim();
    if (texto.isEmpty && _imagenSeleccionada == null) return;
    setState(() => _enviando = true);

    final sk = _semanaKey();
    String respuesta = texto;

    // Miércoles: subir imagen si hay
    if (_diaSemana == 3 && _imagenSeleccionada != null) {
      final ref = FirebaseStorage.instance
          .ref('venus_fotos/${widget.miUid}_$sk.jpg');
      await ref.putFile(_imagenSeleccionada!);
      final url = await ref.getDownloadURL();
      respuesta = '$texto||IMG||$url'; // texto + url separados
    }

    await FirebaseFirestore.instance
        .collection('venus_actividades')
        .doc('${sk}_dia$_diaSemana')
        .collection('respuestas')
        .doc(widget.miUid)
        .set({
          'respuesta': respuesta,
          'nombre':    widget.miNombre,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Notificar a la pareja con una "carta"
    if (_diaSemana == 1 || _diaSemana == 3 || _diaSemana == 7) {
      await FirebaseFirestore.instance
          .collection('venus_cartas')
          .doc(widget.parejaUid)
          .collection('cartas')
          .add({
            'de':       widget.miNombre,
            'deUid':    widget.miUid,
            'mensaje':  texto,
            'imagenUrl': (_diaSemana == 3 && respuesta.contains('||IMG||'))
                ? respuesta.split('||IMG||')[1]
                : null,
            'semana':   sk,
            'dia':      _diaSemana,
            'leida':    false,
            'timestamp': FieldValue.serverTimestamp(),
          });
    }

    if (mounted) {
      setState(() {
        _enviado     = true;
        _enviando    = false;
        _miRespuesta = texto;
      });
    }
  }

  Future<void> _elegirImagen() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1080,
    );
    if (picked != null && mounted) {
      setState(() => _imagenSeleccionada = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 1.5)),
      );
    }

    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Debug: selector de día ─────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 1; i <= 7; i++)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _debugDia = (_debugDia == i) ? 0 : i;
                      _cargando = true;
                      _enviado = false;
                      _miRespuesta = null;
                      _suRespuesta = null;
                      _planClaude = null;
                      _captionMartes = null;
                    });
                    _cargar();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _diaSemana == i ? Colors.black : Colors.transparent,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      dias[i - 1],
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: _diaSemana == i ? Colors.white : Colors.black38,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        switch (_diaSemana) {
          1 => _buildLunes(),
          2 => _buildMartes(),
          3 => _buildMiercoles(),
          4 => _buildJueves(),
          5 => _buildViernes(),
          6 => _buildSabado(),
          7 => _buildDomingo(),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  // ── Lunes: pregunta semanal → carta ──────────────────────────────────────────
  Widget _buildLunes() {
    final pregunta = _preguntas[_semanaIndex()];
    return _TarjetaActividad(
      etiqueta: 'LA PREGUNTA DE HOY',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pregunta,
              style: const TextStyle(color: Colors.black87, fontSize: 15,
                  fontWeight: FontWeight.w300, height: 1.7)),
          const SizedBox(height: 24),
          if (_enviado)
            _respuestaEnviada(_miRespuesta ?? '')
          else ...[
            _campoTexto('tu respuesta…', maxLength: 160),
            const SizedBox(height: 16),
            _botonEnviar('Enviar como carta', onTap: () => _enviar()),
            const SizedBox(height: 8),
            Text('Tu respuesta llegará como carta a $_placeholder.',
                style: const TextStyle(color: Colors.black26, fontSize: 11, height: 1.5)),
          ],
        ],
      ),
    );
  }

  // ── Martes: caption de valoración ────────────────────────────────────────────
  Widget _buildMartes() {
    return _TarjetaActividad(
      etiqueta: 'DÍSELO HOY',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Una cosa para decirle hoy:',
            style: TextStyle(color: Colors.black45, fontSize: 12, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          if (_captionMartes != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '"$_captionMartes"',
                style: const TextStyle(color: Colors.black87, fontSize: 14,
                    fontWeight: FontWeight.w300, height: 1.7, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 20),
          if (_enviado)
            const Text('✓ enviado', style: TextStyle(color: Colors.black38, fontSize: 12, letterSpacing: 2))
          else
            _botonEnviar('Enviar a $_placeholder',
                onTap: () => _enviar(textoExtra: _captionMartes ?? '')),
        ],
      ),
    );
  }

  // ── Miércoles: foto + mensaje → carta visual ──────────────────────────────────
  Widget _buildMiercoles() {
    return _TarjetaActividad(
      etiqueta: 'EL MOMENTO',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comparte un momento de esta semana.',
              style: TextStyle(color: Colors.black45, fontSize: 13, height: 1.6)),
          const SizedBox(height: 20),
          if (_enviado)
            _respuestaEnviada(_miRespuesta ?? '')
          else ...[
            // Selector de imagen
            GestureDetector(
              onTap: _elegirImagen,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.black.withValues(alpha: 0.02),
                ),
                child: _imagenSeleccionada != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.file(_imagenSeleccionada!, fit: BoxFit.cover))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: Colors.black26, size: 32),
                          SizedBox(height: 8),
                          Text('elegir foto', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 1)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            _campoTexto('añade un mensaje…', maxLength: 160),
            const SizedBox(height: 16),
            _botonEnviar('Enviar como carta', onTap: () => _enviar()),
          ],
        ],
      ),
    );
  }

  // ── Jueves: planes del finde ──────────────────────────────────────────────────
  Widget _buildJueves() {
    return _TarjetaActividad(
      etiqueta: 'EL PLAN',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Qué te gustaría hacer este fin de semana?',
              style: TextStyle(color: Colors.black87, fontSize: 15,
                  fontWeight: FontWeight.w300, height: 1.7)),
          const SizedBox(height: 24),
          if (_enviado)
            _respuestaEnviada(_miRespuesta ?? '')
          else ...[
            _campoTexto('escribe tu idea…', maxLength: 160),
            const SizedBox(height: 16),
            _botonEnviar('Guardar plan', onTap: () => _enviar()),
            const SizedBox(height: 8),
            const Text('El viernes veréis los planes del otro.',
                style: TextStyle(color: Colors.black26, fontSize: 11, height: 1.5)),
          ],
        ],
      ),
    );
  }

  // ── Viernes: revelar planes + Claude ─────────────────────────────────────────
  Widget _buildViernes() {
    final n1 = widget.miNombre.split(' ').first;
    final n2 = widget.parejaName.split(' ').first;

    return _TarjetaActividad(
      etiqueta: 'EL FINDE',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Esto es lo que cada uno quería hacer:',
              style: TextStyle(color: Colors.black45, fontSize: 12)),
          const SizedBox(height: 20),
          if (_miRespuesta != null)
            _burbujaPlan(n1, _miRespuesta!, esMio: true),
          const SizedBox(height: 12),
          if (_suRespuesta != null)
            _burbujaPlan(n2, _suRespuesta!, esMio: false)
          else
            const Text('Tu pareja aún no ha respondido.',
                style: TextStyle(color: Colors.black26, fontSize: 12)),
          if (_planClaude != null) ...[
            const SizedBox(height: 28),
            const Divider(color: Colors.black12),
            const SizedBox(height: 20),
            const Text('PROPUESTA PARA EL FINDE',
                style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
            const SizedBox(height: 12),
            Text(_planClaude!,
                style: const TextStyle(color: Colors.black87, fontSize: 14,
                    fontWeight: FontWeight.w300, height: 1.7)),
          ],
        ],
      ),
    );
  }

  // ── Sábado: reto de pareja ────────────────────────────────────────────────────
  Widget _buildSabado() {
    final reto = _retos[_semanaIndex()];
    return _TarjetaActividad(
      etiqueta: 'EL RETO DE HOY',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(reto,
                style: const TextStyle(color: Colors.black87, fontSize: 15,
                    fontWeight: FontWeight.w300, height: 1.7)),
          ),
          const SizedBox(height: 20),
          if (_enviado)
            const Text('✓ marcado como hecho',
                style: TextStyle(color: Colors.black38, fontSize: 12, letterSpacing: 2))
          else
            _botonEnviar('Lo hicimos ✓',
                onTap: () => _enviar(textoExtra: '✓ reto completado')),
        ],
      ),
    );
  }

  // ── Domingo: reflexión → carta de cierre ─────────────────────────────────────
  Widget _buildDomingo() {
    return _TarjetaActividad(
      etiqueta: 'EL RECUERDO',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Cuál fue tu momento favorito de esta semana juntos?',
              style: TextStyle(color: Colors.black87, fontSize: 15,
                  fontWeight: FontWeight.w300, height: 1.7)),
          const SizedBox(height: 24),
          if (_enviado)
            _respuestaEnviada(_miRespuesta ?? '')
          else ...[
            _campoTexto('cuéntalo…', maxLength: 160),
            const SizedBox(height: 16),
            _botonEnviar('Enviar como carta', onTap: () => _enviar()),
          ],
        ],
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────────

  String get _placeholder => widget.parejaName.split(' ').first;

  Widget _campoTexto(String hint, {required int maxLength}) {
    return TextField(
      controller: _ctrl,
      maxLength: maxLength,
      maxLines: 3,
      style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.6),
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        counterStyle: const TextStyle(color: Colors.black26, fontSize: 11),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black45),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _botonEnviar(String label, {required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _enviando ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: const Color(0xFFF3EBD6),
          disabledBackgroundColor: Colors.black26,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          elevation: 0,
        ),
        child: _enviando
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 1.5))
            : Text(label, style: const TextStyle(letterSpacing: 2, fontSize: 12)),
      ),
    );
  }

  Widget _respuestaEnviada(String texto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TU RESPUESTA',
            style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 12),
        Text(texto,
            style: const TextStyle(color: Colors.black87, fontSize: 14,
                fontWeight: FontWeight.w300, height: 1.6)),
        const SizedBox(height: 8),
        const Text('✓ enviado',
            style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 2)),
      ],
    );
  }

  Widget _burbujaPlan(String nombre, String plan, {required bool esMio}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esMio ? Colors.black.withValues(alpha: 0.04) : Colors.transparent,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nombre,
              style: const TextStyle(color: Colors.black45, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(plan,
              style: const TextStyle(color: Colors.black87, fontSize: 14,
                  fontWeight: FontWeight.w300, height: 1.6)),
        ],
      ),
    );
  }
}

// ─── Tarjeta contenedora ──────────────────────────────────────────────────────

class _TarjetaActividad extends StatelessWidget {
  final String etiqueta;
  final Widget contenido;
  const _TarjetaActividad({required this.etiqueta, required this.contenido});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta,
            style: const TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 20),
        contenido,
      ],
    );
  }
}
