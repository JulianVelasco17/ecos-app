import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'perfil_usuario.dart';

class PantallaBuscarAmigos extends StatefulWidget {
  const PantallaBuscarAmigos({super.key});

  @override
  State<PantallaBuscarAmigos> createState() => _PantallaBuscarAmigosState();
}

class _PantallaBuscarAmigosState extends State<PantallaBuscarAmigos> {
  final TextEditingController _buscarController = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;

  Future<void> _buscar(String query) async {
    if (query.isEmpty) {
      setState(() => _resultados = []);
      return;
    }

    setState(() => _buscando = true);

    final texto = query.toLowerCase().replaceAll('@', '');
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    // Buscamos usuarios que contengan el texto en su campo 'usuario'
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('usuario', isEqualTo: texto)
        .limit(10)
        .get();

    // Si no hay exacto, buscamos por prefijo
    if (snapshot.docs.isEmpty) {
      final snapshotPrefijo = await FirebaseFirestore.instance
          .collection('usuarios')
          .orderBy('usuario')
          .startAt([texto])
          .endAt(['$texto\uf8ff'])
          .limit(10)
          .get();

      setState(() {
        _resultados = snapshotPrefijo.docs
            .where((doc) => doc.id != miUid)
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList();
        _buscando = false;
      });
      return;
    }

    setState(() {
      _resultados = snapshot.docs
          .where((doc) => doc.id != miUid) // excluimos al usuario actual
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EBD6),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        title: TextField(
          controller: _buscarController,
          autofocus: true,
          style: const TextStyle(color: Colors.black, letterSpacing: 1),
          decoration: const InputDecoration(
            hintText: '@usuario',
            hintStyle: TextStyle(color: Colors.black45),
            border: InputBorder.none,
            prefixText: '',
          ),
          onChanged: _buscar,
        ),
      ),
      body: _buscando
          ? const Center(child: CircularProgressIndicator(color: Colors.black26))
          : _resultados.isEmpty
              ? const Center(
                  child: Text(
                    'busca a alguien por su @usuario',
                    style: TextStyle(color: Colors.black26, letterSpacing: 1),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _resultados.length,
                  itemBuilder: (context, i) {
                    final usuario = _resultados[i];
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaPerfilUsuario(
                              uid: usuario['uid'],
                              nombre: usuario['nombre'] ?? '',
                              nombreUsuario: usuario['usuario'] ?? '',
                              fotoUrl: usuario['fotoUrl'],
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.black12,
                        backgroundImage: usuario['fotoUrl'] != null
                            ? NetworkImage(usuario['fotoUrl'])
                            : null,
                        child: usuario['fotoUrl'] == null
                            ? const Icon(Icons.person, color: Colors.black45)
                            : null,
                      ),
                      title: Text(
                        usuario['nombre'] ?? '',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                        ),
                      ),
                      subtitle: Text(
                        '@${usuario['usuario'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
