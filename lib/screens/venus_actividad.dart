import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/claude_service.dart';
import '../services/calculos_astrales.dart';

// ─── Banco de preguntas (lunes) — 60 semanas ─────────────────────────────────
const _preguntas = [
  '¿Qué te hizo sentir más cerca de tu pareja últimamente?',
  '¿Qué snack sería tu pareja?',
  'Algo de tu pareja que te gustaría entender mejor',
  'Nombra una parte de la relación que te dé paz',
  'Si tu pareja fuera un personaje de serie, ¿quién sería?',
  'Un momento reciente donde sonreíste por tu pareja',
  'Algo que admiras de tu pareja y casi no dices',
  'Una cosa que te gustaría hacer más seguido juntos',
  'Si tu pareja fuera una bebida, descríbela',
  'Eso que te hace sentir seguro/a en esta relación',
  'Los emojis que describen a tu pareja hoy',
  'Algo que te cuesta expresar con tu pareja',
  'Algo que te sorprendió de tu pareja recientemente',
  'Ponle una canción a tu pareja hoy',
  'Define lo que tu pareja significa para ti en este momento',
  'Si tu pareja fuera una app, ¿qué haría?',
  'Convierte a tu pareja en una comida',
  'Un gesto pequeño que para ti vale mucho',
  'Si tu pareja fuera un lugar, ¿cuál sería?',
  'Describe cuándo te sientes escuchado/a por tu pareja',
  'Si tu pareja fuera una película, ¿cuál sería?',
  'Algo que fortalece tu confianza en tu pareja',
  'Si tu pareja fuera una marca, ¿cuál sería?',
  'Algo que te emociona construir juntos',
  'Eso que te da tranquilidad en la relación',
  'Un momento donde te sentiste elegido/a',
  'Describe un momento donde te sentiste amado/a',
  'Algo nuevo que te gustaría intentar juntos',
  'Si tu pareja tuviera un superpoder, ¿cuál sería?',
  'Un momento que te hizo sentir orgullo de tu pareja',
  'Algo que te gustaría decir más seguido',
  'Si tu pareja fuera un objeto, ¿cuál sería?',
  'Un momento donde te sentiste vulnerable con tu pareja',
  'Si tu pareja fuera un recuerdo de infancia, ¿cuál sería?',
  'Eso que más valoras de su conexión',
  'Género musical que representa a tu pareja',
  'Si tu pareja fuera un recuerdo de vacaciones, ¿cuál sería?',
  'Si tu pareja fuera una escena de alguna película, ¿cuál sería?',
  'Si tu pareja fuera una noche específica, ¿cómo sería?',
  '¿Qué es algo pequeño que hace tu pareja y te mejora el día?',
  '¿En qué momento reciente pensaste "qué suerte estar con esta persona"?',
  '¿Qué lado de tu pareja sale solo cuando está contigo?',
  '¿Qué hábito de tu pareja ya se te pegó sin darte cuenta?',
  '¿Qué es algo que tu pareja hace mejor que tú?',
  '¿Qué situación describe mejor cómo son juntos?',
  '¿Qué te gustaría que pasara más seguido entre ustedes?',
  '¿Qué cosa de tu pareja antes te sorprendía y ahora te encanta?',
  '¿Qué momento cotidiano se ha vuelto especial con tu pareja?',
  '¿Qué es algo que tu pareja hace que nadie más hace por ti?',
  '¿Qué dinámica entre ustedes crees que los define más?',
  '¿Qué te gustaría que tu pareja nunca dejara de hacer?',
  '¿Qué parte de tu relación sientes más única?',
  '¿Qué cosa pequeña de tu pareja se te hace muy atractiva?',
  '¿Qué es algo que tu pareja hace y sabes que es solo contigo?',
  '¿Qué es algo que tu pareja hace que te hace pensar "es muy él/ella"?',
  '¿Qué cosa de tu pareja te parecía rara al inicio y ahora amas?',
  '¿Qué hace tu pareja cuando está feliz que lo delata?',
  '¿Qué lado de tu pareja solo aparece cuando están solos?',
  '¿Qué tipo de energía trae tu pareja a cualquier lugar?',
  '¿Qué es algo que tu pareja hace que te haría reconocerlo/a en cualquier lado?',
];

// ─── Captions miércoles ───────────────────────────────────────────────────────
const _captionsVirales = [
  'Si tu pareja fuera un meme',
  'La foto más inesperada de tu pareja',
  'Tu pareja cuando nadie la está viendo',
  'POV: estás enamorado de esta persona',
  'Tu pareja en su modo más caótico',
  'La cara que pone tu pareja cuando se enoja',
  'Resume a tu pareja en una sola imagen',
  'Cómo se ve tu pareja cuando tiene hambre',
  'Tu pareja siendo dramática',
  'La foto que mejor define a tu pareja',
  'Tu pareja cuando dice "no estoy enojado/a"',
  'La versión más random de tu pareja',
  'Si tu pareja fuera una vibra',
  'Tu pareja a las 3am',
  'La energía real de tu pareja',
  'Tu pareja cuando le tomas fotos sin avisar',
  'La foto más aesthetic de tu pareja',
  'Tu pareja como protagonista de tu historia',
  'La peor foto de tu pareja (pero la amas)',
  'Tu pareja intentando ser seria',
  'Cómo se ve tu pareja cuando te extraña',
  'Tu pareja cuando pierde la paciencia',
  'La foto que subirías a close friends',
  'Tu pareja siendo demasiado tú',
  'La energía que tiene tu pareja contigo',
  'Tu pareja en su momento más icónico',
];

const _captionsProfundos = [
  'Si tu pareja fuera un paisaje',
  'Si tu pareja fuera un recuerdo',
  'La forma en que ves a tu pareja cuando todo está en calma',
  'Un momento que quisieras congelar con tu pareja',
  'Si tu pareja fuera una emoción',
  'Lo que sientes cuando miras a tu pareja',
  'Si tu pareja fuera un lugar seguro',
  'La versión de tu pareja que más amas',
  'Un instante donde todo hizo sentido con tu pareja',
  'Si tu pareja fuera una estación del año',
  'Lo que tu pareja te enseñó sin decir nada',
  'Un recuerdo que aún te acompaña de tu pareja',
  'Si tu pareja fuera una luz',
  'La tranquilidad que te da tu pareja',
  'Un momento silencioso con tu pareja',
  'Si tu pareja fuera una historia',
  'Lo que cambió en ti desde que conociste a tu pareja',
  'La forma en que tu pareja te mira',
  'Si tu pareja fuera un sueño',
  'Un momento que te hizo elegir a tu pareja otra vez',
  'Lo que más admiras de tu pareja en secreto',
  '¿Cómo sería un hogar que se sienta como tu pareja?',
  'La parte de tu pareja que pocos conocen',
  'Un instante imperfecto pero verdadero con tu pareja',
  'Lo que sientes cuando no está tu pareja',
  'Si tu pareja fuera el futuro',
];

String _captionMiercoles(String nombrePareja, {int semanaOverride = -1}) {
  final semana = semanaOverride >= 0 ? semanaOverride : _semanaIndex();
  final esViral = semana % 2 == 0;
  final base = esViral
      ? _captionsVirales[semana % _captionsVirales.length]
      : _captionsProfundos[semana % _captionsProfundos.length];
  return base.replaceAll('tu pareja', nombrePareja);
}

// ─── Planes del finde (jueves) ────────────────────────────────────────────────
const _planesJueves = [
  'Cocinar una receta nueva juntos','Ver una película que ninguno haya visto','Noche de juegos de mesa','Salir a caminar sin rumbo','Picnic en un parque','Hacer ejercicio juntos','Probar un café nuevo','Ir a un museo','Maratón de su serie favorita','Cocinar solo postres','Ir a ver el atardecer','Hacer una playlist juntos','Noche temática (italiana, mexicana, etc.)','Salir a andar en bici','Ir al cine','Hacer un rompecabezas','Jugar videojuegos juntos','Probar un restaurante nuevo','Ir a un mercado o bazar','Hacer un spa en casa','Pintar o dibujar juntos','Ver el amanecer','Ir a un mirador','Hacer una cena elegante en casa','Probar comida callejera','Leer juntos','Hacer una sesión de fotos','Escribir cartas entre ustedes','Hacer un picnic nocturno','Ver videos viejos juntos','Cocinar con ingredientes al azar','Ir a una librería','Hacer una lista de metas juntos','Salir a correr','Hacer karaoke en casa','Ir a una clase (baile, cocina, etc.)','Ver un documental','Hacer una fogata','Salir a desayunar temprano','Ir a una feria','Jugar preguntas profundas','Hacer un álbum de fotos','Salir de roadtrip corto','Hacer limpieza juntos con música','Armar un fuerte con cobijas','Ver estrellas','Cocinar desayuno para el otro','Ir a un concierto','Hacer un reto de TikTok','Probar un deporte nuevo','Ir a patinar','Hacer una noche sin celulares','Cocinar comida internacional','Ir a nadar','Hacer yoga juntos','Probar un brunch','Ir a un rooftop','Hacer un picnic en casa','Jugar verdad o reto','Hacer una lista de sueños','Ver fotos de infancia','Probar un helado nuevo','Ir a una galería de arte','Hacer una cita sorpresa','Cocinar algo que les recuerde a su infancia','Hacer una noche de preguntas incómodas','Ir a un parque de diversiones','Hacer manualidades','Ver una película mala a propósito','Ir a un escape room','Hacer un reto de cocina','Salir a tomar fotos por la ciudad','Ir a un evento local','Hacer un diario juntos','Cocinar solo con lo que haya en casa','Ir a ver un partido','Hacer una noche de recuerdos','Probar un bar nuevo','Hacer una caminata larga','Ver un show en vivo','Hacer una cápsula del tiempo','Cocinar algo saludable juntos','Ir a un acuario','Hacer un picnic en la playa','Ver el cielo en silencio','Hacer un reto de 24 horas','Ir a una clase de arte','Cocinar comida vegana','Hacer una noche de spa','Salir a explorar un barrio nuevo','Ir a una terraza','Hacer un juego de roles divertido','Cocinar su comida favorita','Hacer una lista de canciones importantes','Ir a ver una obra de teatro','Hacer una noche de trivia','Salir a buscar comida específica (tacos, pizza, etc.)','Hacer un reto fitness juntos','Ir a un parque natural','Hacer una noche de confesiones',
];

List<String> _tresPlanes(int semana) {
  final rng = Random(semana * 31);
  final lista = List<String>.from(_planesJueves)..shuffle(rng);
  return lista.take(3).toList();
}

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
  return ((hoy.difference(inicio).inDays) / 7).floor() % 60;
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

  int _debugDia = 0;
  int _debugSemanaOffset = 0;
  int get _diaSemana => _debugDia > 0 ? _debugDia : DateTime.now().weekday;
  int get _semanaDebug => (_semanaIndex() + _debugSemanaOffset) % 60;

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

    // ── Martes: caption astrológico de la pareja ──
    if (_diaSemana == 2) {
      // Key compartida: UIDs ordenados para que sea la misma desde cualquier lado
      final uids = [widget.miUid, widget.parejaUid]..sort();
      final parejaKey = '${sk}_martes_astral_${uids[0]}_${uids[1]}';
      final cacheDoc = await FirebaseFirestore.instance
          .collection('venus_actividades')
          .doc(parejaKey)
          .get();
      if (cacheDoc.exists) {
        _captionMartes = cacheDoc.data()!['caption'] as String?;
      } else {
        final miDoc     = await FirebaseFirestore.instance.collection('usuarios').doc(widget.miUid).get();
        final parejaDoc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.parejaUid).get();
        if (miDoc.exists && parejaDoc.exists) {
          CartaAstral cartaDe(Map<String, dynamic> d) {
            final fecha = (d['fechaNacimiento'] as dynamic).toDate() as DateTime;
            final parts = ((d['horaNacimiento'] as String?) ?? '12:00').split(':');
            return CalculosAstrales.calcular(
              fechaNacimiento: fecha,
              hora:    int.tryParse(parts[0]) ?? 12,
              minutos: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
              latitud:  (d['latitud']  as num?)?.toDouble() ?? 0.0,
              longitud: (d['longitud'] as num?)?.toDouble() ?? 0.0,
            );
          }
          final miCarta     = cartaDe(miDoc.data()!);
          final parejaCarta = cartaDe(parejaDoc.data()!);
          _captionMartes = await ClaudeService.generarCaptionAstralPareja(
            nombre1:      widget.miNombre,
            signoSolar1:  miCarta.signoSolar,
            signoLunar1:  miCarta.signoLunar,
            ascendente1:  miCarta.ascendente,
            nombre2:      widget.parejaName,
            signoSolar2:  parejaCarta.signoSolar,
            signoLunar2:  parejaCarta.signoLunar,
            ascendente2:  parejaCarta.ascendente,
          );
          await FirebaseFirestore.instance
              .collection('venus_actividades')
              .doc(parejaKey)
              .set({'caption': _captionMartes, 'fecha': FieldValue.serverTimestamp()});
        }
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

        // Debug semana
        Row(
          children: [
            const Text('semana', style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 1)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _debugSemanaOffset = (_debugSemanaOffset - 1) % 60;
                _enviado = false;
                _miRespuesta = null;
              }),
              child: const Text('‹', style: TextStyle(color: Colors.black38, fontSize: 18)),
            ),
            const SizedBox(width: 6),
            Text('$_semanaDebug', style: const TextStyle(color: Colors.black45, fontSize: 11)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() {
                _debugSemanaOffset = (_debugSemanaOffset + 1) % 60;
                _enviado = false;
                _miRespuesta = null;
              }),
              child: const Text('›', style: TextStyle(color: Colors.black38, fontSize: 18)),
            ),
          ],
        ),
        const SizedBox(height: 12),

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
    final pregunta = _preguntas[_semanaDebug];
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

  // ── Martes: dinámica astral de la pareja ─────────────────────────────────────
  Widget _buildMartes() {
    return _TarjetaActividad(
      etiqueta: 'SU DINÁMICA HOY',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lo que dice su combinación astral:',
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
                _captionMartes!,
                style: const TextStyle(color: Colors.black87, fontSize: 14,
                    fontWeight: FontWeight.w300, height: 1.7),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: Colors.black12, strokeWidth: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  // ── Miércoles: foto con caption semanal → carta visual ───────────────────────
  Widget _buildMiercoles() {
    final caption = _captionMiercoles(widget.parejaName.split(' ').first, semanaOverride: _semanaDebug);
    return _TarjetaActividad(
      etiqueta: 'EL MOMENTO',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption,
              style: const TextStyle(color: Colors.black87, fontSize: 15,
                  fontWeight: FontWeight.w300, height: 1.6)),
          const SizedBox(height: 20),
          if (_enviado)
            _respuestaEnviada(_miRespuesta ?? '')
          else ...[
            GestureDetector(
              onTap: _elegirImagen,
              child: Container(
                width: double.infinity,
                height: 200,
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
            _botonEnviar('Enviar como carta', onTap: () => _enviar()),
          ],
        ],
      ),
    );
  }

  // ── Jueves: planes del finde ──────────────────────────────────────────────────
  Widget _buildJueves() {
    final planes = _tresPlanes(_semanaDebug);
    return _TarjetaActividad(
      etiqueta: 'EL PLAN',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Qué hacen este fin de semana?',
              style: TextStyle(color: Colors.black45, fontSize: 13, height: 1.6)),
          const SizedBox(height: 20),
          if (_enviado)
            _respuestaEnviada(_miRespuesta ?? '')
          else ...[
            ...planes.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _enviar(textoExtra: plan),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(plan,
                      style: const TextStyle(color: Colors.black87, fontSize: 14,
                          fontWeight: FontWeight.w300)),
                ),
              ),
            )),
            const SizedBox(height: 4),
            const Text('El viernes verán el plan del otro.',
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
    final reto = _retos[_semanaDebug % _retos.length];
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
