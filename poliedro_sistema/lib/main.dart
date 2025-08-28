import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:poliedro_sistema/pages/classes_page.dart';
import 'firebase_options.dart';

import 'pages/materials_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/prof_home.dart';
import 'pages/aluno_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter + Firebase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginPage(), // ✅ Login decide e navega para /prof ou /aluno
      routes: {
        '/register': (_) => const RegisterPage(),
        '/prof': (_) => ProfHome(),   // sem const para evitar erro se faltar construtor const
        '/aluno': (_) => AlunoHome(),
        '/materials': (_) => const MaterialsPage(),
        '/classes': (_) => const ClassesPage(), 
      },
    );
  }
}
