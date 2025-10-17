# 📱 Projeto Integrador - Season 4

![Dart](https://img.shields.io/badge/Dart-3.x-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B)
![Firebase](https://img.shields.io/badge/Firebase-backend-orange)

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

* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* [Dart SDK](https://dart.dev/get-dart)
* [Firebase CLI](https://firebase.google.com/docs/cli)
* [Git](https://git-scm.com/)
* [Android Studio](https://developer.android.com/studio)
* [Java JDK 17](https://adoptium.net/)
* [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)


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


