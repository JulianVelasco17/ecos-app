# Ecos — Brújula personal




Aplicación de autoconocimiento y astrología para iOS y Android, construida en Flutter.  
Genera lecturas diarias personalizadas con IA, carta natal y compatibilidad entre signos.

> Dirigida a usuarios hispanohablantes Gen Z con un tono de autoayuda con perspectiva crítica.

---

## Capturas de pantalla

| Inicio | Lectura diaria | Carta natal |
|--------|---------------|-------------|
| <img width="300" src="https://github.com/user-attachments/assets/54b37dd7-159b-49cf-a08c-a70bfeec23df" /> | <img width="300" src="https://github.com/user-attachments/assets/312671df-5a97-4c9f-873a-59181573064a" /> | <img width="300" src="https://github.com/user-attachments/assets/63a03331-3053-49ae-abf3-d949d3cc0a4c" /> |

| Extras | | |
|--------|--|--|
| <img width="300" src="https://github.com/user-attachments/assets/0570c049-97a9-493f-9afe-2ae49ea4042b" /> | <img width="300" src="https://github.com/user-attachments/assets/cedfacfd-2146-4378-94cb-791edae36e5b" /> | <img width="300" src="https://github.com/user-attachments/assets/98f16a05-279d-441b-9c1c-c4c38fa7f150" /> |
## Stack técnico

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter (Dart) — iOS / Android |
| Backend | Firebase Cloud Functions (Node.js) |
| Base de datos | Cloud Firestore |
| Autenticación | Firebase Auth — Google Sign In + Apple Sign In |
| IA generativa | Anthropic API (Claude Haiku) vía Cloud Functions |
| Monetización | RevenueCat (modelo freemium) |
| Notificaciones | Firebase Cloud Messaging + flutter_local_notifications |
| Almacenamiento | Firebase Storage |
| UI / Tipografía | Google Fonts (Playfair Display) + shaders GLSL personalizados |
| Gestión de config | flutter_dotenv (.env variables) |

---

## Arquitectura

```
ecos-app/
├── lib/
│   ├── main.dart
│   ├── screens/        # Pantallas principales
│   ├── widgets/        # Componentes reutilizables
│   ├── services/       # Firebase, API, notificaciones
│   └── models/         # Modelos de datos
├── functions/          # Cloud Functions (Node.js) — integración con Claude API
├── assets/             # Fuentes, imágenes, shaders
└── shaders/            # marble.frag — efectos visuales GLSL
```
---

## Funcionalidades principales

- **Lectura diaria con IA** — Contenido personalizado generado por Claude Haiku según signo solar, ascendente y área de vida
- **Carta natal** — Cálculo e interpretación de posiciones planetarias
- **Compatibilidad** — Análisis de sinastría entre signos
- **Autenticación** — Google Sign In y Apple Sign In
- **Freemium** — Contenido gratuito + suscripción premium gestionada con RevenueCat
- **Notificaciones push** — Recordatorios y lecturas diarias programadas
- **Widget de pantalla de inicio** — Lectura del día sin abrir la app

---

## Configuración local

### Requisitos

- Flutter SDK `^3.11.4`
- Dart `^3.x`
- Cuenta de Firebase con proyecto configurado
- API key de Anthropic


### Instalación

```bash
git clone https://github.com/JulianVelasco17/ecos-app.git
cd ecos-app
flutter pub get
flutter run
```

### Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Estado del proyecto

- [x] Autenticación (Google + Apple)
- [x] Lecturas diarias con Claude API
- [x] Modelo freemium con RevenueCat
- [x] Notificaciones push
- [x] Publicación en App Store / Play Store
- [ ] Versión web (en desarrollo)
- [ ] Modo offline

---

## Privacidad

Política de privacidad disponible en: [eccos.online/privacy](https://sites.google.com/view/eccos-privacy)

---

## Contacto

**Julián Velasco** — [julian.velasco@eccos.online](mailto:julian.velasco@eccos.online)  
GitHub: [@JulianVelasco17](https://github.com/JulianVelasco17)
