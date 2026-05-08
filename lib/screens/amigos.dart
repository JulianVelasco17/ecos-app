import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import 'afinidad.dart';
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
                            onTap: () async {
                              final miUid = FirebaseAuth.instance.currentUser?.uid;
                              if (miUid == null) return;
                              final miDoc = await FirebaseFirestore.instance
                                  .collection('usuarios').doc(miUid).get();
                              if (!miDoc.exists) return;
                              final mi = miDoc.data()!;

                              CartaAstral cartaDe(Map<String, dynamic> d) {
                                final ts = d['fechaNacimiento'];
                                final fecha = (ts).toDate() as DateTime;
                                final horaStr = d['horaNacimiento'] as String? ?? '12:00';
                                final p = horaStr.split(':');
                                return CalculosAstrales.calcular(
                                  fechaNacimiento: fecha,
                                  hora: int.tryParse(p[0]) ?? 12,
                                  minutos: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
                                  latitud: (d['latitud'] as num?)?.toDouble() ?? 0,
                                  longitud: (d['longitud'] as num?)?.toDouble() ?? 0,
                                );
                              }

                              final miCarta     = cartaDe(mi);
                              final amigoCarta  = cartaDe(data);

                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PantallaAfinidad(
                                    miUid:        miUid,
                                    miNombre:     mi['nombre'] ?? '',
                                    miFotoUrl:    (mi['fotoUrl'] as String?) ?? FirebaseAuth.instance.currentUser?.photoURL,
                                    miSolar:      miCarta.signoSolar,
                                    miLunar:      miCarta.signoLunar,
                                    miAsc:        miCarta.ascendente,
                                    miPlanetas:   miCarta.planetas,
                                    amigoUid:     amigoUid,
                                    amigoNombre:  nombre,
                                    amigoUsername: usuario,
                                    amigoFotoUrl: fotoUrl,
                                    amigoSolar:   amigoCarta.signoSolar,
                                    amigoLunar:   amigoCarta.signoLunar,
                                    amigoAsc:     amigoCarta.ascendente,
                                    amigoPlanetas: amigoCarta.planetas,
                                    captionHoy:   '',
                                  ),
                                ),
                              );
                            },
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
