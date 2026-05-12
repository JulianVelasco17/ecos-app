import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _idVenus = 1;

class NotifPrefs {
  final bool diariaActiva;
  final bool venusActiva;

  const NotifPrefs({
    this.diariaActiva = true,
    this.venusActiva  = false,
  });

  NotifPrefs copyWith({bool? diariaActiva, bool? venusActiva}) => NotifPrefs(
    diariaActiva: diariaActiva ?? this.diariaActiva,
    venusActiva:  venusActiva  ?? this.venusActiva,
  );
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

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
      diariaActiva: p.getBool('notif_diaria_activa') ?? true,
      venusActiva:  p.getBool('notif_venus_activa')  ?? false,
    );
  }

  static Future<void> guardarPreferencias(NotifPrefs prefs) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_diaria_activa', prefs.diariaActiva);
    await p.setBool('notif_venus_activa',  prefs.venusActiva);
  }

  // ── Programar / cancelar ──────────────────────────────────────────────────

  static Future<void> aplicarPreferencias(NotifPrefs prefs) async {
    if (!prefs.venusActiva) {
      await _plugin.cancel(_idVenus);
    } else {
      await _programarVenus();
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

  static Future<void> mostrarAhora({String titulo = 'prueba ✦', String cuerpo = 'notificación de prueba'}) async {
    await _plugin.show(99, titulo, cuerpo,
        _detalles('debug', 'Debug', 'Notificación de prueba'));
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

  // ── FCM: guardar token del dispositivo en Firestore ───────────────────────

  static Future<void> guardarTokenFCM() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // En iOS, el token APNs puede tardar unos segundos en estar disponible
    String? token;
    for (int i = 0; i < 5; i++) {
      token = await FirebaseMessaging.instance.getToken();
      if (token != null) break;
      await Future.delayed(const Duration(seconds: 2));
    }
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

}
