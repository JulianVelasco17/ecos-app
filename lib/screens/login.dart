import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'home.dart';
import 'registro.dart';
import '../services/notification_service.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final pass = _passController.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'completa todos los campos');
      return;
    }

    setState(() { _cargando = true; _error = null; });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final uid = cred.user?.uid;
      if (uid == null || !mounted) return;

      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!mounted) return;

      NotificationService.guardarTokenFCM();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaHome(nombre: doc.data()?['nombre'] ?? 'viajero'),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'user-not-found'  => 'no encontramos esa cuenta',
          'wrong-password'  => 'contraseña incorrecta',
          'invalid-email'   => 'email no válido',
          'invalid-credential' => 'email o contraseña incorrectos',
          _                 => 'algo salió mal, intenta de nuevo',
        };
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: Colors.black45, size: 18),
              ),

              const SizedBox(height: 48),

              const Text(
                'bienvenido\nde vuelta',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 48),

              // Email
              _Campo(
                controller: _emailController,
                hint: 'correo electrónico',
                teclado: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // Contraseña
              _Campo(
                controller: _passController,
                hint: 'contraseña',
                oculto: true,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, letterSpacing: 0.5),
                ),
              ],

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    final email = _emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() => _error = 'ingresa tu correo primero');
                      return;
                    }
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      if (mounted) setState(() => _error = 'te enviamos un correo para restablecer tu contraseña');
                    } catch (_) {
                      if (mounted) setState(() => _error = 'no encontramos esa cuenta');
                    }
                  },
                  child: const Text(
                    'olvidé mi contraseña',
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFFF3EBD6),
                    disabledBackgroundColor: Colors.black26,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    elevation: 0,
                  ),
                  child: _cargando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 1.5))
                      : const Text('ENTRAR', style: TextStyle(letterSpacing: 3, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool oculto;
  final TextInputType teclado;

  const _Campo({
    required this.controller,
    required this.hint,
    this.oculto = false,
    this.teclado = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: oculto,
      keyboardType: teclado,
      style: const TextStyle(color: Colors.black, fontSize: 14, letterSpacing: 0.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black45)),
      ),
    );
  }
}
