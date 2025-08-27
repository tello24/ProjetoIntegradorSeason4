import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass  = TextEditingController();
  final pass2 = TextEditingController();
  final ra    = TextEditingController();

  bool loading = false;
  String? erro;
  bool showPass = false;
  bool showPass2 = false;

  // Domínios (ajuste aqui caso mude no futuro)
  static const alunoDomain = '@p4ed.com';
  static const profDomain  = '@sistemapoliedro.com';

  String get emailText => email.text.trim().toLowerCase();

  bool get isAlunoDomain => emailText.endsWith(alunoDomain);
  bool get isProfDomain  => emailText.endsWith(profDomain);

  String? get role {
    if (isAlunoDomain) return 'aluno';
    if (isProfDomain)  return 'professor';
    return null; // domínio inválido
  }

  bool get emailValido =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(emailText);

  bool get nameValido => name.text.trim().length >= 2;

  bool get passValida => pass.text.trim().length >= 6;

  bool get passConfere => pass.text == pass2.text;

  bool get raValido =>
      !isAlunoDomain || RegExp(r'^\d{7}$').hasMatch(ra.text.trim());

  bool get dominioValido => role != null;

  bool get formOk =>
      nameValido && emailValido && dominioValido && passValida && passConfere && raValido;

  Future<void> _registrar() async {
    if (!formOk) return;

    setState(() { loading = true; erro = null; });

    try {
      // 1) Cria no Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailText,
        password: pass.text.trim(),
      );
      final uid = cred.user!.uid;

      // 2) Monta payload Firestore
      final userData = <String, dynamic>{
        'name': name.text.trim(),
        'email': emailText,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (role == 'aluno') {
        userData['ra'] = ra.text.trim();
      }

      // 3) Grava em users/{uid}
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData, SetOptions(merge: true));

      // 4) Redireciona para área
      if (!mounted) return;
      if (role == 'professor') {
        Navigator.pushNamedAndRemoveUntil(context, '/prof', (_) => false);
      } else if (role == 'aluno') {
        Navigator.pushNamedAndRemoveUntil(context, '/aluno', (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Falha ao cadastrar.';
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este e-mail já está em uso.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        case 'weak-password':
          msg = 'Senha fraca (mínimo 6 caracteres).';
          break;
        default:
          msg = e.message ?? msg;
      }
      setState(() => erro = msg);
    } catch (e) {
      setState(() => erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    pass2.dispose();
    ra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dominioMsg = !email.text.isEmpty && !dominioValido
        ? 'Domínio inválido. Use $profDomain (professor) ou $alunoDomain (aluno).'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nome completo',
                errorText: name.text.isEmpty || nameValido ? null : 'Informe seu nome',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: email,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-mail institucional',
                helperText: 'Professor: $profDomain | Aluno: $alunoDomain',
                errorText: email.text.isEmpty
                    ? null
                    : (!emailValido
                        ? 'E-mail inválido'
                        : (dominioMsg != null ? dominioMsg : null)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pass,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: !showPass,
              decoration: InputDecoration(
                labelText: 'Senha (mín. 6)',
                errorText: pass.text.isEmpty || passValida ? null : 'Senha muito curta',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => showPass = !showPass),
                  icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                  tooltip: showPass ? 'Ocultar senha' : 'Mostrar senha',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pass2,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: !showPass2,
              decoration: InputDecoration(
                labelText: 'Confirmar senha',
                errorText: pass2.text.isEmpty || passConfere ? null : 'As senhas não conferem',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => showPass2 = !showPass2),
                  icon: Icon(showPass2 ? Icons.visibility_off : Icons.visibility),
                  tooltip: showPass2 ? 'Ocultar senha' : 'Mostrar senha',
                ),
              ),
              onChanged: (_) => setState(() {}),
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
              ),
            ],
            const SizedBox(height: 8),
            if (erro != null)
              Text(erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (!formOk || loading) ? null : _registrar,
              child: loading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Criar conta'),
            ),
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text('Já tenho conta'),
            ),
          ],
        ),
      ),
    );
  }
}
