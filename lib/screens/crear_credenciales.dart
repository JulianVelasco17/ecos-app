import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';

class PantallaCrearCredenciales extends StatefulWidget {
  final String nombre;
  final String usuario;
  final DateTime fechaNacimiento;
  final TimeOfDay horaNacimiento;
  final String lugarNacimiento;
  final double latitud;
  final double longitud;

  const PantallaCrearCredenciales({
    super.key,
    required this.nombre,
    required this.usuario,
    required this.fechaNacimiento,
    required this.horaNacimiento,
    required this.lugarNacimiento,
    required this.latitud,
    required this.longitud,
  });

  @override
  State<PantallaCrearCredenciales> createState() => _PantallaCrearCredencialesState();
}

class _PantallaCrearCredencialesState extends State<PantallaCrearCredenciales> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _omitir(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF3EBD6),
        title: const Text('¿seguro?', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 1)),
        content: const Text(
          'Se te será más complejo recuperar tu cuenta en caso de perderla. ¿Deseas continuar sin crear credenciales?',
          style: TextStyle(color: Colors.black54, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancelar', style: TextStyle(color: Colors.black45)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('continuar sin cuenta', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    // Guardamos los datos sin credenciales
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'nombre': widget.nombre,
        'usuario': widget.usuario,
        'fechaNacimiento': Timestamp.fromDate(widget.fechaNacimiento),
        'horaNacimiento': '${widget.horaNacimiento.hour}:${widget.horaNacimiento.minute.toString().padLeft(2, '0')}',
        'lugarNacimiento': widget.lugarNacimiento,
        'latitud': widget.latitud,
        'longitud': widget.longitud,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => PantallaHome(nombre: widget.nombre)),
      (_) => false,
    );
  }

  Future<void> _continuar() async {
    final email = _emailController.text.trim();
    final pass = _passController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'completa todos los campos');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'las contraseñas no coinciden');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'la contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() { _cargando = true; _error = null; });

    try {
      String uid;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null && currentUser.isAnonymous) {
        // Vinculamos el usuario anónimo con email/contraseña
        final credential = EmailAuthProvider.credential(email: email, password: pass);
        await currentUser.linkWithCredential(credential);
        uid = currentUser.uid;
      } else {
        // Creamos una cuenta nueva directamente
        final result = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
        uid = result.user!.uid;
      }

      // Guardamos datos del perfil en Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': widget.nombre,
        'usuario': widget.usuario,
        'fechaNacimiento': Timestamp.fromDate(widget.fechaNacimiento),
        'horaNacimiento': '${widget.horaNacimiento.hour}:${widget.horaNacimiento.minute.toString().padLeft(2, '0')}',
        'lugarNacimiento': widget.lugarNacimiento,
        'latitud': widget.latitud,
        'longitud': widget.longitud,
        'email': email,
        'creadoEn': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PantallaHome(nombre: widget.nombre)),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'email-already-in-use'      => 'ese correo ya tiene una cuenta',
          'invalid-email'             => 'el correo no es válido',
          'weak-password'             => 'la contraseña es muy débil',
          'credential-already-in-use' => 'ese correo ya está asociado a otra cuenta',
          _                           => 'algo salió mal (${e.code})',
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EBD6),
        iconTheme: const IconThemeData(color: Colors.black45),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _omitir(context),
            child: const Text('omitir', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 1)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'crea tu\ncuenta',
              style: TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'con esto podrás iniciar sesión\nen cualquier dispositivo',
              style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 0.5, height: 1.6),
            ),

            const SizedBox(height: 48),

            _etiqueta('CORREO ELECTRÓNICO'),
            const SizedBox(height: 8),
            _Campo(
              controller: _emailController,
              hint: 'tu@correo.com',
              teclado: TextInputType.emailAddress,
            ),

            const SizedBox(height: 28),

            _etiqueta('CONTRASEÑA'),
            const SizedBox(height: 8),
            _Campo(
              controller: _passController,
              hint: 'mínimo 6 caracteres',
              oculto: true,
            ),

            const SizedBox(height: 28),

            _etiqueta('CONFIRMAR CONTRASEÑA'),
            const SizedBox(height: 8),
            _Campo(
              controller: _confirmController,
              hint: 'repite tu contraseña',
              oculto: true,
            ),

            if (_error != null) ...[
              const SizedBox(height: 20),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12, letterSpacing: 0.5),
              ),
            ],

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cargando ? null : _continuar,
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
                    : const Text('CONTINUAR', style: TextStyle(letterSpacing: 3, fontSize: 12)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto) => Text(
        texto,
        style: const TextStyle(color: Colors.black45, fontSize: 11, letterSpacing: 2),
      );
}

class _Campo extends StatefulWidget {
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
  State<_Campo> createState() => _CampoState();
}

class _CampoState extends State<_Campo> {
  late bool _oculto;

  @override
  void initState() {
    super.initState();
    _oculto = widget.oculto;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _oculto,
      keyboardType: widget.teclado,
      style: const TextStyle(color: Colors.black, fontSize: 14, letterSpacing: 0.5),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black45)),
        suffixIcon: widget.oculto
            ? IconButton(
                icon: Icon(
                  _oculto ? Icons.visibility_off : Icons.visibility,
                  color: Colors.black26,
                  size: 20,
                ),
                onPressed: () => setState(() => _oculto = !_oculto),
              )
            : null,
      ),
    );
  }
}
