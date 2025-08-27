import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final senha = TextEditingController();
  final ra    = TextEditingController();

  bool loading = false;
  String? erro;
  bool showPass = false;

  bool get isAlunoDomain =>
      email.text.trim().toLowerCase().endsWith('@p4ed.com');

  bool get emailValido =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());

  bool get senhaValida => senha.text.trim().length >= 6;

  bool get raValido =>
      !isAlunoDomain || RegExp(r'^\d{7}$').hasMatch(ra.text.trim());

  bool get formOk => emailValido && senhaValida && raValido;

  Future<void> _login() async {
    if (!formOk) return;
    setState(() { loading = true; erro = null; });
    try {
      // 1) Autentica
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: senha.text.trim(),
      );
      final uid = cred.user!.uid;

      // 2) Busca perfil
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      final role = data?['role'] as String?;
      if (role == null) throw Exception('Perfil não encontrado no Firestore.');

      // 3) Valida RA se for aluno
      if (role == 'aluno') {
        final raBanco = (data?['ra'] ?? '').toString();
        final raInput = ra.text.trim();
        if (!RegExp(r'^\d{7}$').hasMatch(raInput)) {
          throw Exception('RA deve ter 7 dígitos.');
        }
        if (raInput != raBanco) {
          throw Exception('RA não confere para este usuário.');
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/aluno');
        return;
      }

      // 4) Professor
      if (role == 'professor') {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/prof');
        return;
      }

      throw Exception('Papel inválido.');
    } on FirebaseAuthException catch (e) {
      setState(() => erro = e.message ?? 'Falha no login');
    } catch (e) {
      setState(() => erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final mail = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      setState(() => erro = 'Informe um e-mail válido para recuperar a senha.');
      return;
    }
    setState(() => erro = null);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de recuperação enviado.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => erro = e.message ?? 'Falha ao enviar e-mail de recuperação.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-renderiza quando e-mail muda (mostra/esconde RA)
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: email,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-mail',
                errorText: email.text.isEmpty || emailValido ? null : 'E-mail inválido',
              ),
              onChanged: (_) => setState(() {}), // atualiza isAlunoDomain
            ),
            const SizedBox(height: 8),
            TextField(
              controller: senha,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Senha (mín. 6)',
                errorText: senha.text.isEmpty || senhaValida ? null : 'Senha muito curta',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => showPass = !showPass),
                  icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                  tooltip: showPass ? 'Ocultar senha' : 'Mostrar senha',
                ),
              ),
              obscureText: !showPass,
            ),
            if (isAlunoDomain) ...[
              const SizedBox(height: 8),
              TextField(
                controller: ra,
                decoration: InputDecoration(
                  labelText: 'RA (7 dígitos)',
                  errorText: ra.text.isEmpty || raValido ? null : 'RA deve ter 7 dígitos',
                  counterText: '', // oculta contador
                ),
                keyboardType: TextInputType.number,
                maxLength: 7,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}), // 🔧 reavalia formOk ao digitar RA
              ),
            ],
            const SizedBox(height: 8),
            if (erro != null)
              Text(erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (!formOk || loading) ? null : _login,
              child: loading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
            TextButton(
              onPressed: loading ? null : _resetPassword,
              child: const Text('Esqueci minha senha'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}