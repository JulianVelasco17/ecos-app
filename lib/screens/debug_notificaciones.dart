import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';

class PantallaDebugNotificaciones extends StatefulWidget {
  const PantallaDebugNotificaciones({super.key});

  @override
  State<PantallaDebugNotificaciones> createState() => _PantallaDebugNotificacionesState();
}

class _PantallaDebugNotificacionesState extends State<PantallaDebugNotificaciones> {
  String? _token;
  String? _tokenEnFirestore;
  String _log = '';
  bool _cargando = false;

  static const _beige = Color(0xFFF3EBD6);

  @override
  void initState() {
    super.initState();
    _cargarInfo();
  }

  Future<void> _cargarInfo() async {
    final token = await FirebaseMessaging.instance.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? guardado;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final tokens = List<String>.from(doc.data()?['fcmTokens'] as List? ?? []);
      guardado = tokens.isNotEmpty ? tokens.last : null;
    }
    if (mounted) setState(() { _token = token; _tokenEnFirestore = guardado; });
  }

  Future<void> _probarPush(String tipo) async {
    setState(() { _cargando = true; _log = 'enviando $tipo...'; });
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1');
      final result = await fn.httpsCallable('enviarNotifDebug').call({'tipo': tipo});
      final data = result.data as Map;
      setState(() => _log = '✓ $tipo\ntokens: ${data['tokens']}  exitosos: ${data['exitosos']}  fallidos: ${data['fallidos']}');
    } catch (e) {
      setState(() => _log = '✗ error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _probarLocal() async {
    setState(() { _cargando = true; _log = 'disparando notificación local...'; });
    try {
      await NotificationService.mostrarAhora();
      setState(() => _log = '✓ notificación local enviada');
    } catch (e) {
      setState(() => _log = '✗ error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _probarVenusLocal() async {
    setState(() { _cargando = true; _log = 'programando notif local venus...'; });
    try {
      final prefs = await NotificationService.cargarPreferencias();
      await NotificationService.aplicarPreferencias(prefs.copyWith(venusActiva: true));
      setState(() => _log = '✓ Venus local programado para el próximo martes');
    } catch (e) {
      setState(() => _log = '✗ error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reregistrarToken() async {
    setState(() { _cargando = true; _log = 'registrando token...'; });
    try {
      await NotificationService.guardarTokenFCM();
      await _cargarInfo();
      setState(() => _log = '✓ token guardado en Firestore');
    } catch (e) {
      setState(() => _log = '✗ error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenCoincide = _token != null && _token == _tokenEnFirestore;
    final tokenGuardado = _tokenEnFirestore != null;

    return Scaffold(
      backgroundColor: _beige,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12, top: 2),
                      child: Icon(Icons.arrow_back_ios, size: 16, color: Colors.black45),
                    ),
                  ),
                  const Text('debug · notificaciones',
                      style: TextStyle(color: Colors.black54, fontSize: 13, letterSpacing: 2)),
                ],
              ),

              const SizedBox(height: 32),

              // ── Estado del token ──────────────────────────────────────────
              const Text('TOKEN FCM', style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
              const SizedBox(height: 12),

              _FilaEstado(
                label: 'token en dispositivo',
                ok: _token != null,
                valor: _token != null ? '${_token!.substring(0, 20)}...' : 'null',
              ),
              const SizedBox(height: 8),
              _FilaEstado(
                label: 'token en Firestore',
                ok: tokenGuardado,
                valor: tokenGuardado ? '${_tokenEnFirestore!.substring(0, 20)}...' : 'no guardado',
              ),
              const SizedBox(height: 8),
              _FilaEstado(
                label: 'tokens coinciden',
                ok: tokenCoincide,
                valor: tokenCoincide ? 'sí' : 'no — puede fallar',
              ),

              const SizedBox(height: 8),
              GestureDetector(
                onTap: _cargando ? null : _reregistrarToken,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('volver a registrar token →',
                      style: TextStyle(color: Colors.black38, fontSize: 11, letterSpacing: 1)),
                ),
              ),

              const SizedBox(height: 32),
              const Divider(color: Colors.black12),
              const SizedBox(height: 24),

              // ── Pruebas push ──────────────────────────────────────────────
              const Text('PUSH VÍA CLOUD FUNCTIONS', style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
              const SizedBox(height: 16),

              _BotonDebug(label: 'lectura diaria', onTap: _cargando ? null : () => _probarPush('diaria')),
              const SizedBox(height: 10),
              _BotonDebug(label: 'solicitud venus', onTap: _cargando ? null : () => _probarPush('venus')),
              const SizedBox(height: 10),
              _BotonDebug(label: 'carta de amor', onTap: _cargando ? null : () => _probarPush('carta')),

              const SizedBox(height: 24),
              const Divider(color: Colors.black12),
              const SizedBox(height: 24),

              // ── Pruebas locales ───────────────────────────────────────────
              const Text('LOCAL (funciona en emulador)', style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
              const SizedBox(height: 4),
              const Text('las push de arriba requieren dispositivo real',
                  style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 0.3)),
              const SizedBox(height: 16),
              _BotonDebug(label: 'notificación local ahora', onTap: _cargando ? null : _probarLocal),
              const SizedBox(height: 10),
              _BotonDebug(label: 'programar venus local', onTap: _cargando ? null : _probarVenusLocal),

              const Spacer(),

              // ── Log ───────────────────────────────────────────────────────
              if (_log.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  color: Colors.black87,
                  child: Text(_log,
                      style: const TextStyle(
                          color: Color(0xFFB8973A), fontSize: 11,
                          fontFamily: 'monospace', height: 1.6)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaEstado extends StatelessWidget {
  final String label;
  final bool ok;
  final String valor;
  const _FilaEstado({required this.label, required this.ok, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 14, color: ok ? Colors.black38 : Colors.red.shade300),
        const SizedBox(width: 8),
        Text('$label  ', style: const TextStyle(color: Colors.black45, fontSize: 11, letterSpacing: 0.5)),
        Expanded(
          child: Text(valor,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: ok ? Colors.black54 : Colors.red.shade400,
                  fontSize: 11, letterSpacing: 0.3)),
        ),
      ],
    );
  }
}

class _BotonDebug extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _BotonDebug({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: onTap != null ? Colors.black54 : Colors.black26,
                    fontSize: 12, letterSpacing: 1)),
            const Spacer(),
            Icon(Icons.send_outlined,
                size: 14, color: onTap != null ? Colors.black38 : Colors.black12),
          ],
        ),
      ),
    );
  }
}
