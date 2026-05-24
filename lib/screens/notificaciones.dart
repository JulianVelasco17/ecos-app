import 'package:flutter/material.dart';
import '../widgets/fade_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaNotificaciones extends StatelessWidget {
  const PantallaNotificaciones({super.key});

  Future<void> _aceptar(String solicitudId, String deUid) async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    final batch = FirebaseFirestore.instance.batch();

    // Actualizamos el estado de la solicitud
    batch.update(
      FirebaseFirestore.instance.collection('solicitudes').doc(solicitudId),
      {'estado': 'aceptada'},
    );

    // Agregamos al otro usuario en mi lista de amigos
    batch.set(
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(miUid)
          .collection('amigos')
          .doc(deUid),
      {'uid': deUid, 'desde': FieldValue.serverTimestamp()},
    );

    // Me agrego en la lista de amigos del otro
    batch.set(
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(deUid)
          .collection('amigos')
          .doc(miUid),
      {'uid': miUid, 'desde': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  Future<void> _rechazar(String solicitudId) async {
    await FirebaseFirestore.instance
        .collection('solicitudes')
        .doc(solicitudId)
        .update({'estado': 'rechazada'});
  }

  @override
  Widget build(BuildContext context) {
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EBD6),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        title: const Text(
          'NOTIFICACIONES',
          style: TextStyle(
            color: Colors.black45,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
      ),
      body: miUid == null
          ? const Center(
              child: Text('sin sesión',
                  style: TextStyle(color: Colors.black26)))
          : StreamBuilder<QuerySnapshot>(
              // Escuchamos en tiempo real las solicitudes pendientes para este usuario
              stream: FirebaseFirestore.instance
                  .collection('solicitudes')
                  .where('para', isEqualTo: miUid)
                  .where('estado', isEqualTo: 'pendiente')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.black26));
                }

                final solicitudes = snapshot.data!.docs;

                if (solicitudes.isEmpty) {
                  return const Center(
                    child: Text(
                      'sin notificaciones',
                      style: TextStyle(color: Colors.black26, letterSpacing: 1),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: solicitudes.length,
                  itemBuilder: (context, i) {
                    final solicitud = solicitudes[i];
                    final deUid = solicitud['de'] as String;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(deUid)
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();

                        final datos =
                            userSnap.data!.data() as Map<String, dynamic>?;
                        final nombre = datos?['nombre'] ?? 'alguien';
                        final usuario = datos?['usuario'] ?? '';
                        final fotoUrl = datos?['fotoUrl'];

                        return ListTile(
                          leading: FadeAvatar(
                            radius: 20,
                            backgroundColor: Colors.black12,
                            fotoUrl: fotoUrl,
                            fallbackChild: const Icon(Icons.person, color: Colors.black45),
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
                            '@$usuario quiere conectar contigo',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botón aceptar
                              GestureDetector(
                                onTap: () => _aceptar(solicitud.id, deUid),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Aceptar',
                                    style: TextStyle(
                                      color: const Color(0xFFF3EBD6),
                                      fontSize: 12,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botón rechazar
                              GestureDetector(
                                onTap: () => _rechazar(solicitud.id),
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.close,
                                      color: Colors.black45, size: 20),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
