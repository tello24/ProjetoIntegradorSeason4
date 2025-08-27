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
    FocusScope.of(context).unfocus();

    try {
      // 1) Autentica
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: senha.text.trim(),
      );
      final uid = cred.user!.uid;

      // 2) Busca perfil no Firestore
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Perfil não encontrado no Firestore.');
      }

      final role = (data['role'] ?? '').toString();
      if (role != 'aluno' && role != 'professor') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Papel inválido no perfil. Contate o administrador.');
      }

      // 3) Se for aluno, valida RA digitado
      if (role == 'aluno') {
        final raBanco = (data['ra'] ?? '').toString();
        final raInput = ra.text.trim();

        if (!RegExp(r'^\d{7}$').hasMatch(raInput)) {
          await FirebaseAuth.instance.signOut();
          throw Exception('Informe o RA de 7 dígitos para alunos.');
        }
        if (raInput != raBanco) {
          await FirebaseAuth.instance.signOut();
          throw Exception('RA não confere para este usuário.');
        }
      }

      // 4) Navegação direta para a área correta e limpa a pilha
      if (!mounted) return;
      if (role == 'professor') {
        Navigator.pushNamedAndRemoveUntil(context, '/prof', (_) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/aluno', (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => erro = e.message ?? 'Falha no login');
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      setState(() => erro = e.toString().replaceFirst('Exception: ', ''));
      await FirebaseAuth.instance.signOut();
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'E-mail',
                errorText: email.text.isEmpty || emailValido ? null : 'E-mail inválido',
              ),
              onChanged: (_) => setState(() {}), // atualiza isAlunoDomain/formOk
            ),
            const SizedBox(height: 8),
            TextField(
              controller: senha,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: isAlunoDomain ? TextInputAction.next : TextInputAction.done,
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
              onChanged: (_) => setState(() {}), // reavalia formOk
              onSubmitted: (_) {
                if (!isAlunoDomain && formOk && !loading) _login();
              },
            ),
            if (isAlunoDomain) ...[
              const SizedBox(height: 8),
              TextField(
                controller: ra,
                decoration: InputDecoration(
                  labelText: 'RA (7 dígitos)',
                  errorText: ra.text.isEmpty || raValido ? null : 'RA deve ter 7 dígitos',
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 7,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (formOk && !loading) _login();
                },
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
