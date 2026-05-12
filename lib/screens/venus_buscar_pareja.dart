import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaVenusBuscarPareja extends StatefulWidget {
  const PantallaVenusBuscarPareja({super.key});

  @override
  State<PantallaVenusBuscarPareja> createState() => _PantallaVenusBuscarParejaState();
}

class _PantallaVenusBuscarParejaState extends State<PantallaVenusBuscarPareja> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  List<Map<String, dynamic>> _amigos = [];
  bool _buscando = false;
  bool _cargandoAmigos = true;
  String? _enviandoA;

  @override
  void initState() {
    super.initState();
    _cargarAmigos();
  }

  Future<void> _cargarAmigos() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(miUid)
        .collection('amigos')
        .get();

    final amigos = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final uid = doc['uid'] as String;
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!userDoc.exists) continue;
      final d = userDoc.data()!;
      amigos.add({'uid': uid, 'nombre': d['nombre'], 'usuario': d['usuario'], 'fotoUrl': d['fotoUrl']});
    }

    if (mounted) setState(() { _amigos = amigos; _cargandoAmigos = false; });
  }

  Future<void> _buscar(String query) async {
    final texto = query.toLowerCase().replaceAll('@', '').trim();
    if (texto.isEmpty) {
      setState(() => _resultados = []);
      return;
    }

    setState(() => _buscando = true);
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .orderBy('usuario')
        .startAt([texto])
        .endAt(['$texto\uf8ff'])
        .limit(10)
        .get();

    setState(() {
      _resultados = snap.docs
          .where((d) => d.id != miUid)
          .map((d) => {'uid': d.id, ...d.data()})
          .toList();
      _buscando = false;
    });
  }

  Future<void> _enviarInvitacion(Map<String, dynamic> pareja) async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    setState(() => _enviandoA = pareja['uid']);

    final miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(miUid).get();
    final miNombre = miDoc.data()?['nombre'] ?? '';

    final parejaUid = pareja['uid'] as String;
    final parejaDoc = await FirebaseFirestore.instance.collection('usuarios').doc(parejaUid).get();
    final parejaEnlace = parejaDoc.data()?['venusEnlace'];

    if (parejaEnlace != null && parejaEnlace['estado'] != null) {
      if (!mounted) return;
      setState(() => _enviandoA = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('esta persona ya tiene una conexión activa'),
          backgroundColor: Colors.black12,
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('usuarios').doc(miUid).update({
      'venusEnlace': {
        'uid': parejaUid,
        'nombre': pareja['nombre'] ?? '',
        'usuario': pareja['usuario'] ?? '',
        'fotoUrl': pareja['fotoUrl'],
        'estado': 'pendiente_enviada',
      },
    });

    await FirebaseFirestore.instance.collection('usuarios').doc(parejaUid).update({
      'venusEnlace': {
        'uid': miUid,
        'nombre': miNombre,
        'usuario': miDoc.data()?['usuario'] ?? '',
        'fotoUrl': miDoc.data()?['fotoUrl'],
        'estado': 'pendiente_recibida',
      },
    });

    if (!mounted) return;
    setState(() => _enviandoA = null);
    Navigator.pop(context);
  }

  Widget _buildUsuarioTile(Map<String, dynamic> u) {
    final enviando = _enviandoA == u['uid'];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.black12,
        backgroundImage: u['fotoUrl'] != null ? NetworkImage(u['fotoUrl']) : null,
        child: u['fotoUrl'] == null ? const Icon(Icons.person, color: Colors.black45) : null,
      ),
      title: Text(u['nombre'] ?? '', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 1)),
      subtitle: Text('@${u['usuario'] ?? ''}', style: const TextStyle(color: Colors.black45, fontSize: 12, letterSpacing: 1)),
      trailing: enviando
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 1.5))
          : GestureDetector(
              onTap: () => _enviarInvitacion(u),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('conectar', style: TextStyle(color: Colors.black45, fontSize: 12, letterSpacing: 2)),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buscandoActivo = _controller.text.replaceAll('@', '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EBD6),
        iconTheme: const IconThemeData(color: Colors.black45),
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black, letterSpacing: 1),
          decoration: const InputDecoration(
            hintText: '@usuario',
            hintStyle: TextStyle(color: Colors.black26),
            border: InputBorder.none,
          ),
          onChanged: _buscar,
        ),
      ),
      body: _buscando
          ? const Center(child: CircularProgressIndicator(color: Colors.black12))
          : buscandoActivo
              // — resultados de búsqueda —
              ? _resultados.isEmpty
                  ? const Center(
                      child: Text('sin resultados', style: TextStyle(color: Colors.black26, letterSpacing: 1, fontSize: 13)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _resultados.length,
                      itemBuilder: (_, i) => _buildUsuarioTile(_resultados[i]),
                    )
              // — lista de amigos —
              : _cargandoAmigos
                  ? const Center(child: CircularProgressIndicator(color: Colors.black12))
                  : _amigos.isEmpty
                      ? const Center(
                          child: Text(
                            'busca a tu pareja por su @usuario',
                            style: TextStyle(color: Colors.black26, letterSpacing: 1, fontSize: 13),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                'TUS AMIGOS',
                                style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3),
                              ),
                            ),
                            ..._amigos.map(_buildUsuarioTile),
                          ],
                        ),
    );
  }
}
