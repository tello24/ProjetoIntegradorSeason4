# 📱 Projeto Integrador - Season 4
---

## 📌 Visão Geral
Este repositório contém o desenvolvimento do **Projeto Integrador Season 4**, criado com foco em aplicar conceitos de **desenvolvimento mobile com Flutter/Dart** e integração com **Firebase** para autenticação, banco de dados e armazenamento.

🔗 **Protótipo no Figma:** [Acessar Design](COLOCAR_LINK_AQUI)

---

## 👥 Equipe
| Nome Completo        | RA         |
| -------------------- | ---------- |
| Eike Barbosa         | 24.00652-0 |
| Nicolas Pessoa       | 24.01746-9 |
| Pedro Vasconcelos    | 24.00923-7 |
| Renan Schiavotello   | 24.00202-0 |
| Wolf Meijome         | 24.95008-4 |
| Leonardo Hideshima   | 24.00229-0 |

---

## 🚀 Começando

### ✅ Pré-requisitos
Antes de iniciar, você precisa ter instalado em sua máquina:

* [Flutter SDK](https://docs.flutter.dev/get-started/install)  [![Flutter SDK](https://img.shields.io/badge/Flutter-SDK-02569B?logo=flutter\&logoColor=white)](https://docs.flutter.dev/get-started/install)
* [Dart SDK](https://dart.dev/get-dart)  [![Dart SDK](https://img.shields.io/badge/Dart-SDK-0175C2?logo=dart\&logoColor=white)](https://dart.dev/get-dart)
* [Firebase CLI](https://firebase.google.com/docs/cli)  [![Firebase CLI](https://img.shields.io/badge/Firebase-CLI-FFCA28?logo=firebase\&logoColor=black)](https://firebase.google.com/docs/cli)
* [Git](https://git-scm.com/)  [![Git](https://img.shields.io/badge/Git-latest-F05032?logo=git\&logoColor=white)](https://git-scm.com/)
* [Android Studio](https://developer.android.com/studio)  [![Android Studio](https://img.shields.io/badge/Android%20Studio-latest-3DDC84?logo=android-studio\&logoColor=white)](https://developer.android.com/studio)
* [Java JDK 17](https://adoptium.net/)  [![Java JDK 17](https://img.shields.io/badge/Java-JDK%2017-007396?logo=openjdk\&logoColor=white)](https://adoptium.net/)
* [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)  [![FlutterFire CLI](https://img.shields.io/badge/FlutterFire-CLI-FFCA28?logo=firebase\&logoColor=black)](https://firebase.flutter.dev/docs/cli/)
* [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools)  [![Android SDK Platform-Tools](https://img.shields.io/badge/Android%20SDK-Platform--Tools-3DDC84?logo=android\&logoColor=white)](https://developer.android.com/tools/releases/platform-tools)



---

### 📦 Instalação

Clone o repositório:
```bash
git clone https://github.com/tello24/ProjetoIntegradorSeason4.git
cd ProjetoIntegradorSeason4
flutter pub get
```
### ▶️ Executando o projeto
flutter run

Para rodar o app em diferentes plataformas, utilize os comandos abaixo (certifique-se de listar os dispositivos disponíveis com `flutter devices` antes):

```bash
# Android
flutter run -d android

# iOS (simulador ou dispositivo físico)
flutter run -d ios

# Web (Chrome)
flutter run -d chrome

# Desktop
flutter run -d windows   # para Windows
flutter run -d macos     # para macOS
flutter run -d linux     # para Linux
```

### 🛠️ Solução de Problemas

Caso não encontre o dispositivo: use flutter devices para verificar.

Se o Firebase não conectar: confira se o arquivo google-services.json (Android) ou GoogleService-Info.plist (iOS) está adicionado corretamente.

Rode flutter clean e depois flutter pub get se ocorrerem erros de cache.

### 📁 Estrutura do Projeto
ProjetoIntegradorSeason4/sistema_poliedro
lib/
  main.dart
  firebase_options.dart
  pages/
    start_page.dart
    login_page.dart
    register_page.dart
    prof_home.dart
    aluno_home.dart
    materials_page.dart
    material_details.dart
    classes_page.dart
    select_student_page.dart
    activities_page.dart
    aluno_notas_page.dart
    chat_page.dart
  widgets/
    unread_badge.dart         
  utils/
    open_inline_web.dart      
    confirm_signout.dart


