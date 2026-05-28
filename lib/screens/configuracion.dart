import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'ajustes_notificaciones.dart';

class PantallaConfiguracion extends StatefulWidget {
  const PantallaConfiguracion({super.key});

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  bool _vinculando = false;

  Future<void> _eliminarCuenta(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF3EBD6),
        title: const Text('eliminar cuenta', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 1)),
        content: const Text('Se borrarán tu perfil y todos tus datos. Esta acción no se puede deshacer.', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancelar', style: TextStyle(color: Colors.black45)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _reautenticar(user);
      if (!context.mounted) return;
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).delete();
      await user.delete();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PantallaBienvenida()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'vuelve a iniciar sesión e intenta de nuevo'
          : 'no se pudo eliminar la cuenta, intenta de nuevo';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.black87,
        content: Text(msg, style: const TextStyle(color: Color(0xFFF3EBD6), fontSize: 12)),
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.black87,
        content: Text('no se pudo eliminar la cuenta, intenta de nuevo',
            style: TextStyle(color: Color(0xFFF3EBD6), fontSize: 12)),
      ));
    }
  }

  Future<void> _reautenticar(User user) async {
    final proveedores = user.providerData.map((p) => p.providerId).toSet();
    if (proveedores.contains('apple.com')) {
      final rawNonce = AuthService.generarNonce();
      final credencial = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: AuthService.sha256Nonce(rawNonce),
      );
      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: credencial.identityToken,
        accessToken: credencial.authorizationCode,
        rawNonce: rawNonce,
      );
      await user.reauthenticateWithCredential(oauthCred);
    } else if (proveedores.contains('google.com')) {
      await GoogleSignIn.instance.initialize(
        clientId: AuthService.iosClientId,
        serverClientId: AuthService.serverClientId,
      );
      final cuenta = await GoogleSignIn.instance.authenticate();
      final auth = cuenta.authentication;
      final credencial = GoogleAuthProvider.credential(idToken: auth.idToken);
      await user.reauthenticateWithCredential(credencial);
    }
    // usuarios anónimos o email/password no requieren reautenticación para delete
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF3EBD6),
        title: const Text('cerrar sesión', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 1)),
        content: const Text('¿seguro que quieres salir?', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancelar', style: TextStyle(color: Colors.black45)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('salir', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await AuthService.cerrarSesion();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaBienvenida()),
      (_) => false,
    );
  }

  Future<void> _vincular(bool esGoogle) async {
    setState(() => _vinculando = true);
    final ok = esGoogle
        ? await AuthService.vincularConGoogle()
        : await AuthService.vincularConApple();
    if (!mounted) return;
    setState(() => _vinculando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? Colors.black87 : Colors.black45,
      content: Text(
        ok
            ? 'cuenta vinculada correctamente'
            : 'no se pudo vincular, intenta de nuevo',
        style: const TextStyle(color: Color(0xFFF3EBD6), fontSize: 12, letterSpacing: 0.5),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? user?.displayName ?? 'invitado';

    final proveedores = user?.providerData.map((p) => p.providerId).toSet() ?? {};
    final esEmailPassword = proveedores.contains('password');
    final tieneGoogle = proveedores.contains('google.com');
    final tieneApple = proveedores.contains('apple.com');
    final mostrarVinculacion = esEmailPassword && (!tieneGoogle || !tieneApple);

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ajustes',
                    style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 3),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.close, color: Colors.black45, size: 20),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                email,
                style: const TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 1),
              ),

              const SizedBox(height: 48),

              const Divider(color: Colors.black12),

              _Opcion(
                icono: Icons.notifications_none,
                titulo: 'notificaciones',
                subtitulo: 'gestiona tus alertas diarias',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaAjustesNotificaciones())),
              ),

              const Divider(color: Colors.black12),

              _Opcion(
                icono: Icons.lock_outline,
                titulo: 'privacidad',
                subtitulo: 'política de privacidad',
                onTap: () => launchUrl(
                  Uri.parse('https://www.termsfeed.com/live/e160706a-c79b-4db6-839a-f69fe29be91a'),
                  mode: LaunchMode.externalApplication,
                ),
              ),

              const Divider(color: Colors.black12),

              _Opcion(
                icono: Icons.info_outline,
                titulo: 'acerca de astro',
                subtitulo: 'versión 1.0.0',
                onTap: () {},
              ),

              const Divider(color: Colors.black12),

              if (mostrarVinculacion) ...[
                const SizedBox(height: 32),
                const Text(
                  'VINCULAR CUENTA',
                  style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3),
                ),
                const SizedBox(height: 16),
                if (!tieneGoogle)
                  _BotonVincular(
                    icono: Icons.g_mobiledata,
                    label: 'vincular con Google',
                    cargando: _vinculando,
                    onTap: () => _vincular(true),
                  ),
                if (!tieneGoogle && !tieneApple) const SizedBox(height: 12),
                if (!tieneApple)
                  _BotonVincular(
                    icono: Icons.apple,
                    label: 'vincular con Apple',
                    cargando: _vinculando,
                    onTap: () => _vincular(false),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'inicia sesión más rápido en cualquier dispositivo',
                  style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 0.3),
                ),
              ],

              const SizedBox(height: 48),

              GestureDetector(
                onTap: () => _cerrarSesion(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.black45, size: 16),
                      SizedBox(width: 12),
                      Text(
                        'cerrar sesión',
                        style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              GestureDetector(
                onTap: () => _eliminarCuenta(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 16),
                      SizedBox(width: 12),
                      Text(
                        'eliminar cuenta',
                        style: TextStyle(color: Colors.red, fontSize: 13, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonVincular extends StatelessWidget {
  final IconData icono;
  final String label;
  final bool cargando;
  final VoidCallback onTap;

  const _BotonVincular({required this.icono, required this.label, required this.cargando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cargando ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icono, color: Colors.black54, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.black54, fontSize: 13,
                      fontWeight: FontWeight.w300, letterSpacing: 0.5)),
            ),
            if (cargando)
              const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _Opcion({required this.icono, required this.titulo, required this.subtitulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icono, color: Colors.black45, size: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.black87, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: const TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 0.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black12, size: 16),
          ],
        ),
      ),
    );
  }
}
