import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

// Páginas do projeto
import 'pages/start_page.dart';      // nova tela de boas-vindas
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/prof_home.dart';
import 'pages/aluno_home.dart';
import 'pages/materials_page.dart';
import 'pages/classes_page.dart';
import 'pages/select_student_page.dart';
import 'pages/chat_page.dart';
import 'pages/material_details.dart';

// Sprint atual
import 'pages/activities_page.dart';
import 'pages/aluno_notas_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0066cc)),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Poliedro · Sistema',
      debugShowCheckedModeBanner: false,
      theme: theme,

      // ✅ StartPage como primeira tela SEM usar 'home'
      initialRoute: '/start',
      routes: {
        '/start':          (_) => const StartPage(),   // tela de boas-vindas
        '/':               (_) => const LoginPage(),   // sua rota de login continua sendo '/'
        '/register':       (_) => const RegisterPage(),
        '/prof':           (_) => const ProfHome(),
        '/aluno':          (_) => const AlunoHome(),

        '/materials':      (_) => const MaterialsPage(),
        '/classes':        (_) => const ClassesPage(),
        '/select-student': (_) => const SelectStudentPage(),

        '/activities':     (_) => const ActivitiesPage(),
        '/aluno-notas':    (_) => const AlunoNotasPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/chat' && settings.arguments is Map) {
          final args = settings.arguments as Map;
          return MaterialPageRoute(
            builder: (_) => ChatPage(
              peerUid:  args['peerUid']  as String,
              peerName: args['peerName'] as String?,
              peerEmail:args['peerEmail']as String?,
              peerRa:   args['peerRa']   as String? ?? '',
            ),
          );
        }

        if (settings.name == '/material-details' && settings.arguments is Map) {
          final args = settings.arguments as Map;
          return MaterialPageRoute(
            builder: (_) => MaterialDetailsPage(
              ref: args['ref'] as DocumentReference<Map<String, dynamic>>,
            ),
          );
        }

        return null;
      },
    );
  }
}
