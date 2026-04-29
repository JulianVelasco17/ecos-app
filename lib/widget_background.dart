import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/claude_service.dart';
import 'services/banco_frases.dart';

@pragma('vm:entry-point')
Future<void> widgetBackground(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final uid    = await HomeWidget.getWidgetData<String>('widget_uid');
  final nombre = await HomeWidget.getWidgetData<String>('widget_nombre') ?? 'viajero';
  final solar  = await HomeWidget.getWidgetData<String>('widget_solar')  ?? '';
  final lunar  = await HomeWidget.getWidgetData<String>('widget_lunar')  ?? '';
  final asc    = await HomeWidget.getWidgetData<String>('widget_asc')    ?? '';

  if (uid == null || solar.isEmpty) return;

  final hoy      = DateTime.now();
  final fechaHoy = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

  final lecturaDoc = await FirebaseFirestore.instance
      .collection('usuarios').doc(uid)
      .collection('lecturas').doc(fechaHoy)
      .get();

  String frase;
  if (lecturaDoc.exists) {
    frase = _parseFrase(lecturaDoc.data()!['texto'] as String);
  } else {
    final usuarioSnap   = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final usuarioDatos  = usuarioSnap.data() ?? {};
    List<int> cola      = List<int>.from(usuarioDatos['frasesQueue'] ?? []);
    if (cola.isEmpty) cola = BancoFrases.generarColaMezclada();
    final id = cola.removeAt(0);
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({'frasesQueue': cola});

    final fraseData  = BancoFrases.porId(id);
    final fraseBase  = fraseData['frase'] as String;
    final areaFrase  = fraseData['area']  as String? ?? 'identidad';
    final lectura    = await ClaudeService.generarAstrosDelDia(
      nombre:     nombre,
      signoSolar: solar,
      signoLunar: lunar,
      ascendente: asc,
      fraseBase:  fraseBase,
      areaFrase:  areaFrase,
    );

    await FirebaseFirestore.instance
        .collection('usuarios').doc(uid)
        .collection('lecturas').doc(fechaHoy)
        .set({'texto': lectura});

    frase = _parseFrase(lectura);
  }

  await HomeWidget.saveWidgetData<String>('widget_frase', frase);
  await HomeWidget.updateWidget(androidName: 'AstrosWidget');
}

String _parseFrase(String texto) {
  try {
    final limpio = texto.replaceAll(RegExp(r'```json|```'), '').trim();
    final json   = jsonDecode(limpio);
    return (json['frase'] as String?) ?? texto;
  } catch (_) {
    return texto;
  }
}
