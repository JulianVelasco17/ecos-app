import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'perfil_usuario.dart';
import 'buscar_amigos.dart';

class PantallaAmigos extends StatelessWidget {
  const PantallaAmigos({super.key});

  @override
  Widget build(BuildContext context) {
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'tus amigos',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PantallaBuscarAmigos()),
                    ),
                    child: const Icon(Icons.search,
                        color: Colors.black45, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(miUid)
                    .collection('amigos')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.black12),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'aún no tienes amigos\nbusca a alguien con la lupa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black26,
                          fontSize: 13,
                          letterSpacing: 1,
                          height: 2,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final amigoUid = docs[i]['uid'] as String;

                      return FutureBuilder(
                        future: FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(amigoUid)
                            .get(),
                        builder: (context, snap) {
                          if (!snap.hasData || !snap.data!.exists) {
                            return const SizedBox.shrink();
                          }

                          final data = snap.data!.data()!;
                          final nombre = data['nombre'] ?? '';
                          final usuario = data['usuario'] ?? '';
                          final fotoUrl = data['fotoUrl'] as String?;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PantallaPerfilUsuario(
                                  uid: amigoUid,
                                  nombre: nombre,
                                  nombreUsuario: usuario,
                                  fotoUrl: fotoUrl,
                                ),
                              ),
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.black12,
                              backgroundImage: fotoUrl != null
                                  ? NetworkImage(fotoUrl)
                                  : null,
                              child: fotoUrl == null
                                  ? const Icon(Icons.person,
                                      color: Colors.black45, size: 20)
                                  : null,
                            ),
                            title: Text(
                              nombre,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1,
                              ),
                            ),
                            subtitle: Text(
                              '@$usuario',
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
