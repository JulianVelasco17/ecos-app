import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// IDs fijos por tipo de notificación
const _idDiaria = 0;
const _idVenus  = 1;
const _idLuna   = 2;

class NotifPrefs {
  final bool diariaActiva;
  final int diariaHora;
  final int diariaMinutos;
  final bool venusActiva;
  final bool lunaActiva;

  const NotifPrefs({
    this.diariaActiva  = true,
    this.diariaHora    = 9,
    this.diariaMinutos = 0,
    this.venusActiva   = false,
    this.lunaActiva    = false,
  });

  NotifPrefs copyWith({
    bool? diariaActiva,
    int? diariaHora,
    int? diariaMinutos,
    bool? venusActiva,
    bool? lunaActiva,
  }) => NotifPrefs(
    diariaActiva:   diariaActiva   ?? this.diariaActiva,
    diariaHora:     diariaHora     ?? this.diariaHora,
    diariaMinutos:  diariaMinutos  ?? this.diariaMinutos,
    venusActiva:    venusActiva    ?? this.venusActiva,
    lunaActiva:     lunaActiva     ?? this.lunaActiva,
  );
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Pedir permisos FCM en iOS (necesario para obtener el token)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mostrar notificaciones push aunque la app esté en primer plano (iOS)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── Preferencias ──────────────────────────────────────────────────────────

  static Future<NotifPrefs> cargarPreferencias() async {
    final p = await SharedPreferences.getInstance();
    return NotifPrefs(
      diariaActiva:  p.getBool('notif_diaria_activa')  ?? true,
      diariaHora:    p.getInt('notif_diaria_hora')      ?? 9,
      diariaMinutos: p.getInt('notif_diaria_minutos')   ?? 0,
      venusActiva:   p.getBool('notif_venus_activa')    ?? false,
      lunaActiva:    p.getBool('notif_luna_activa')     ?? false,
    );
  }

  static Future<void> guardarPreferencias(NotifPrefs prefs) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_diaria_activa',  prefs.diariaActiva);
    await p.setInt( 'notif_diaria_hora',    prefs.diariaHora);
    await p.setInt( 'notif_diaria_minutos', prefs.diariaMinutos);
    await p.setBool('notif_venus_activa',   prefs.venusActiva);
    await p.setBool('notif_luna_activa',    prefs.lunaActiva);
  }

  // ── Programar / cancelar ──────────────────────────────────────────────────

  static Future<void> aplicarPreferencias(NotifPrefs prefs, {String fraseDiaria = 'tus astros te esperan'}) async {
    await _plugin.cancel(_idDiaria); // cancelar cualquier notificación diaria local previa

    if (prefs.venusActiva) {
      await _programarVenus();
    }
    if (prefs.lunaActiva) {
      await _programarLuna();
    }
  }

  // Notificación de Venus cada martes
  static Future<void> _programarVenus() async {
    final now = tz.TZDateTime.now(tz.local);
    // Próximo martes a las 10am
    var dias = (DateTime.tuesday - now.weekday + 7) % 7;
    if (dias == 0) dias = 7;
    final horario = tz.TZDateTime(tz.local, now.year, now.month, now.day + dias, 10, 0);

    await _plugin.zonedSchedule(
      _idVenus,
      'martes de venus ♀',
      'el amor y los vínculos están en el centro hoy',
      horario,
      _detalles('venus', 'Martes de Venus', 'Recordatorio semanal de Venus'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // Notificación de luna — cada 14 días (luna nueva / llena aprox.)
  static Future<void> _programarLuna() async {
    // Referencia de luna nueva: 29 dic 2024
    final referencia = DateTime(2024, 12, 29);
    final ahora = DateTime.now();
    final diasDesde = ahora.difference(referencia).inDays;
    final ciclo = 29.53;

    // Días hasta la próxima luna nueva o llena (la que venga antes)
    final faseActual = diasDesde % ciclo;
    double diasHastaProxima;
    String titulo;
    String cuerpo;

    if (faseActual < 14.77) {
      diasHastaProxima = 14.77 - faseActual;
      titulo = 'luna llena ○';
      cuerpo = 'la luna llena ilumina lo que estaba oculto';
    } else {
      diasHastaProxima = ciclo - faseActual;
      titulo = 'luna nueva ●';
      cuerpo = 'la luna nueva abre un nuevo ciclo para ti';
    }

    final horario = tz.TZDateTime.now(tz.local)
        .add(Duration(hours: (diasHastaProxima * 24).round()));

    await _plugin.zonedSchedule(
      _idLuna,
      titulo,
      cuerpo,
      horario,
      _detalles('luna', 'Fases lunares', 'Aviso de luna nueva y llena'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Solo para debug — dispara ahora mismo
  static Future<void> mostrarAhora(String frase) async {
    await _plugin.show(
      99,
      'tus astros de hoy ✦',
      frase,
      _detalles('astros_diarios', 'Lectura diaria', 'Tu lectura astrológica personal'),
    );
  }

  // Helper de detalles de notificación
  static NotificationDetails _detalles(String channelId, String channelName, String desc) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: desc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  // Cancelar notificación diaria local (ahora la manda el servidor)
  static Future<void> programarNotificacionDelDia(String frase) async {
    await _plugin.cancel(_idDiaria);
  }

  // ── FCM: guardar token del dispositivo en Firestore ───────────────────────

  static Future<void> guardarTokenFCM() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _agregarToken(uid, token);
    FirebaseMessaging.instance.onTokenRefresh.listen((nuevoToken) {
      _agregarToken(uid, nuevoToken);
    });
  }

  static Future<void> _agregarToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  // ── FCM: enviar push a la pareja via FCM HTTP v1 ──────────────────────────

  static Future<void> notificarPareja({
    required String parejaUid,
    required String titulo,
    required String cuerpo,
  }) async {
    final parejaDoc = await FirebaseFirestore.instance
        .collection('usuarios').doc(parejaUid).get();
    final token = parejaDoc.data()?['fcmToken'] as String?;
    if (token == null) return;

    final serverKey = dotenv.env['FCM_SERVER_KEY'] ?? '';
    if (serverKey.isEmpty) return;

    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode({
        'to': token,
        'notification': {'title': titulo, 'body': cuerpo},
        'data': {'tipo': 'venus'},
      }),
    );
  }
}
