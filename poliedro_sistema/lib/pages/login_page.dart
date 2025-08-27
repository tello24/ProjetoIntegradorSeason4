import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final senha = TextEditingController();
  bool loading = false;
  String? erro;

  Future<void> _login() async {
    setState(() { loading = true; erro = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: senha.text.trim(),
      );
      final uid = cred.user!.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = doc.data()?['role'] as String?;
      if (role == 'professor') {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/prof');
      } else if (role == 'aluno') {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/aluno');
      } else {
        setState(() => erro = 'Perfil não encontrado no Firestore.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => erro = e.message ?? 'Falha no login');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail')),
            TextField(controller: senha, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
            const SizedBox(height: 16),
            if (erro != null) Text(erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: loading ? null : _login,
              child: loading ? const CircularProgressIndicator() : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
