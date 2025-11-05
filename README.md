# 📱 Projeto Integrador — Season 4 (Flutter + Firebase)

Repositório do **Projeto Integrador Season 4**, focado em **desenvolvimento mobile com Flutter/Dart** e integração com **Firebase** (Auth, Firestore e Storage).

🔗 **Protótipo no Figma:** [Acessar Design](https://www.figma.com/proto/9247khau6R3LWDOmIrKxCG/Untitled?node-id=0-1&t=tys8IDuD5y6GX0V6-1)

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

## 🧰 Stack & Principais Dependências

- **Flutter** (3.x) + **Dart** (SDK `>= 3.9.0`)
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`
- Utilitários: `file_picker`, `open_filex`, `path_provider`, `url_launcher`, `mime`

> **Versões (lockfile atual):**  
> `firebase_core 4.0.0` · `firebase_auth 6.0.1` · `cloud_firestore 6.0.0` · `firebase_storage 13.0.0`  
> `file_picker 10.3.2` · `open_filex 4.7.0` · `path_provider 2.1.5` · `url_launcher 6.3.2` · `cupertino_icons 1.0.8`

---

## 🚀 Começando

### ✅ Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-dart)
- [Java JDK 17](https://adoptium.net/)
- [Android Studio](https://developer.android.com/studio) (SDK/Platform-Tools instalados)
- [Git](https://git-scm.com/)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)

### 📦 Instalação
```bash
git clone https://github.com/tello24/ProjetoIntegradorSeason4.git
cd ProjetoIntegradorSeason4/poliedro_sistema
flutter pub get

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
---

### 🛠️ Solução de Problemas

Caso não encontre o dispositivo: use flutter devices para verificar.

Se o Firebase não conectar: confira se o arquivo google-services.json (Android) ou GoogleService-Info.plist (iOS) está adicionado corretamente.

Rode flutter clean e depois flutter pub get se ocorrerem erros de cache.
---

### 🗄️ Estrutura de Dados (Cloud Firestore)
users, classes, students, students_index, materials,
messages, grades, grade_entries, class_stats, activities

---

### 📁 Estrutura do Projeto
```
poliedro_sistema/
├─ lib/
│  ├─ main.dart
│  ├─ firebase_options.dart
│  ├─ pages/
│  │  ├─ start_page.dart
│  │  ├─ login_page.dart
│  │  ├─ register_page.dart
│  │  ├─ prof_home.dart
│  │  ├─ aluno_home.dart
│  │  ├─ classes_page.dart
│  │  ├─ materials_page.dart
│  │  ├─ material_details.dart
│  │  ├─ materiais_da_turma_page.dart
│  │  ├─ chat_page.dart
│  │  ├─ grades_page.dart
│  │  ├─ aluno_turmas_page.dart
│  │  ├─ aluno_notas_page.dart
│  │  ├─ aluno_notas_materia_page.dart
│  │  ├─ aluno_notas_da_turma_page.dart
│  │  ├─ alunos_da_turma_page.dart
│  │  ├─ aluno_detalhes_turma_page.dart
│  │  ├─ colegas_da_turma_page.dart
│  │  ├─ gerenciamento_turma_page.dart
│  │  ├─ select_student_page.dart
│  │  ├─ select_professor_page.dart
│  │  └─ select_class_for_grades_page.dart
│  ├─ utils/
│  │  ├─ confirm_signout.dart
│  │  ├─ open_inline_io.dart
│  │  └─ open_inline_web.dart
│  └─ widgets/
│     └─ unread_badge.dart
├─ assets/
│  └─ images/
│     ├─ poliedro.png
│     ├─ iconePoliedro.png
│     └─ fundoPoliedro.png
├─ android/
├─ ios/
├─ web/
├─ windows/
├─ macos/
├─ linux/
├─ pubspec.yaml
├─ pubspec.lock
└─ analysis_options.yaml
```
