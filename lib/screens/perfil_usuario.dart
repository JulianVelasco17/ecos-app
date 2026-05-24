import 'package:flutter/material.dart';
import '../widgets/fade_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaPerfilUsuario extends StatefulWidget {
  final String uid;
  final String nombre;
  final String nombreUsuario;
  final String? fotoUrl;

  const PantallaPerfilUsuario({
    super.key,
    required this.uid,
    required this.nombre,
    required this.nombreUsuario,
    this.fotoUrl,
  });

  @override
  State<PantallaPerfilUsuario> createState() => _PantallaPerfilUsuarioState();
}

class _PantallaPerfilUsuarioState extends State<PantallaPerfilUsuario> {
  bool _solicitudEnviada = false;
  bool _esAmigo = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _verificarRelacion();
  }

  Future<void> _verificarRelacion() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(miUid)
          .collection('amigos')
          .doc(widget.uid)
          .get(),
      FirebaseFirestore.instance
          .collection('solicitudes')
          .doc('${miUid}_${widget.uid}')
          .get(),
    ]);

    setState(() {
      _esAmigo = results[0].exists;
      _solicitudEnviada = results[1].exists;
      _cargando = false;
    });
  }

  Future<void> _enviarSolicitud() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    await FirebaseFirestore.instance
        .collection('solicitudes')
        .doc('${miUid}_${widget.uid}')
        .set({
      'de': miUid,
      'para': widget.uid,
      'estado': 'pendiente',
      'creadoEn': FieldValue.serverTimestamp(),
    });

    setState(() => _solicitudEnviada = true);
  }

  Future<void> _eliminarAmigo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF3EBD6),
        title: Text(
          '¿eliminar a ${widget.nombre}?',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 1),
        ),
        content: const Text(
          'Dejarás de ver su horóscopo personalizado y desaparecerá de tu lista de amigos.',
          style: TextStyle(color: Colors.black54, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancelar', style: TextStyle(color: Colors.black38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('eliminar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance.collection('usuarios').doc(miUid).collection('amigos').doc(widget.uid));
    batch.delete(FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).collection('amigos').doc(miUid));
    await batch.commit();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EBD6),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeAvatar(
                radius: 48,
                backgroundColor: Colors.black12,
                fotoUrl: widget.fotoUrl,
                fallbackChild: const Icon(Icons.person, color: Colors.black45, size: 48),
              ),

              const SizedBox(height: 24),

              Text(
                widget.nombre,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '@${widget.nombreUsuario}',
                style: const TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 1),
              ),

              const SizedBox(height: 48),

              if (_cargando)
                const CircularProgressIndicator(color: Colors.black26)
              else if (_esAmigo)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _eliminarAmigo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black54,
                      side: const BorderSide(color: Colors.black26),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('ELIMINAR AMIGO', style: TextStyle(letterSpacing: 3, fontSize: 12)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _solicitudEnviada ? null : _enviarSolicitud,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _solicitudEnviada ? Colors.black12 : Colors.black,
                      foregroundColor: const Color(0xFFF3EBD6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.black12,
                    ),
                    child: Text(
                      _solicitudEnviada ? 'SOLICITUD ENVIADA' : 'AÑADIR',
                      style: TextStyle(
                        letterSpacing: 3,
                        color: _solicitudEnviada ? Colors.black45 : const Color(0xFFF3EBD6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
