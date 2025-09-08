import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // controllers (emailUsr = apenas a parte antes do @)
  final emailUsr = TextEditingController();
  final senha    = TextEditingController();
  final ra       = TextEditingController();

  // focus (mostrar erros só após blur/submit)
  final _emailF = FocusNode();
  final _senhaF = FocusNode();
  final _raF    = FocusNode();

  bool loading = false;
  String? erro;
  bool showPass = false;

  // papel selecionado (UI/validação)
  String role = 'aluno'; // 'aluno' | 'professor'

  // domínios fixos
  static const alunoDomain = '@p4ed.com';
  static const profDomain  = '@sistemapoliedro.com';

  // flags p/ erros
  bool _tEmail = false, _tSenha = false, _tRa = false, _submitted = false;

  String get _domainForRole => role == 'aluno' ? alunoDomain : profDomain;

  /// e-mail completo montado (user + sufixo fixo)
  String get emailFull {
    final user = emailUsr.text.trim().toLowerCase();
    if (user.isEmpty) return '';
    return '$user$_domainForRole';
  }

  // ---------- validações (iguais ao padrão da Register) ----------
  // agora checamos apenas o "user" (sem @)
  bool get _emailUserOk =>
      RegExp(r'^[^\s@]+$').hasMatch(emailUsr.text.trim());

  bool get emailValido => _emailUserOk;
  bool get senhaValida => senha.text.trim().length >= 6;
  bool get raValido    => role == 'professor' || RegExp(r'^\d{7}$').hasMatch(ra.text.trim());

  // mensagens de erro (só após blur ou submit)
  String? get emailError {
    final show = ((_tEmail && !_emailF.hasFocus) || _submitted);
    if (!show) return null;
    if (emailUsr.text.trim().isEmpty) return 'Informe o nome do e-mail institucional';
    if (!_emailUserOk) return 'Caracteres inválidos no e-mail';
    return null;
  }

  String? get senhaError {
    final show = ((_tSenha && !_senhaF.hasFocus) || _submitted);
    if (!show) return null;
    if (!senhaValida) return 'Senha muito curta';
    return null;
  }

  String? get raError {
    if (role == 'professor') return null;
    final show = ((_tRa && !_raF.hasFocus) || _submitted);
    if (!show) return null;
    if (!raValido) return 'RA deve ter 7 dígitos';
    return null;
  }

  // CTA habilita sem depender das flags de erro
  bool get ctaEnabled => emailValido && senhaValida && raValido && !loading;

  @override
  void initState() {
    super.initState();
    _emailF.addListener(() { if (!_emailF.hasFocus) setState(() => _tEmail = true); });
    _senhaF.addListener(() { if (!_senhaF.hasFocus) setState(() => _tSenha = true); });
    _raF.addListener(()    { if (!_raF.hasFocus)    setState(() => _tRa    = true); });
  }

  @override
  void dispose() {
    _emailF.dispose(); _senhaF.dispose(); _raF.dispose();
    emailUsr.dispose(); senha.dispose(); ra.dispose();
    super.dispose();
  }

  // traduz códigos do Firebase para PT-BR
  String _authErrorPt(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Senha ou email incorreta.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'user-disabled':
        return 'Usuário desativado.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão.';
      case 'invalid-email':
        return 'E-mail inválido.';
      default:
        return e.message ?? 'Falha no login.';
    }
  }

  // ---------- login (monta emailFinal igual ao Register) ----------
  Future<void> _login() async {
    setState(() {
      _submitted = true;
      _tEmail = _tSenha = _tRa = true;
    });
    if (!ctaEnabled) return;

    setState(() { loading = true; erro = null; });
    FocusScope.of(context).unfocus();

    try {
      final emailFinal = emailFull;

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailFinal,
        password: senha.text.trim(),
      );
      final uid = cred.user!.uid;

      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Perfil não encontrado no Firestore.');
      }

      final roleDb = (data['role'] ?? '').toString();
      if (roleDb != 'aluno' && roleDb != 'professor') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Papel inválido no perfil. Contate o administrador.');
      }
      if (roleDb != role) {
        await FirebaseAuth.instance.signOut();
        throw Exception(
          role == 'aluno'
              ? 'Você selecionou Aluno, mas sua conta é de Professor.'
              : 'Você selecionou Professor, mas sua conta é de Aluno.',
        );
      }

      if (roleDb == 'aluno') {
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

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context, roleDb == 'professor' ? '/prof' : '/aluno', (_) => false);
    } on FirebaseAuthException catch (e) {
      setState(() => erro = _authErrorPt(e));
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      setState(() => erro = e.toString().replaceFirst('Exception: ', ''));
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    // usa o email montado (se o user preencheu algo válido)
    if (!_emailUserOk) {
      setState(() => erro = 'Informe o e-mail institucional (nome antes do @) para recuperar a senha.');
      return;
    }
    final mail = emailFull;
    setState(() => erro = null);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('E-mail de recuperação enviado.')));
    } on FirebaseAuthException catch (e) {
      setState(() => erro = _authErrorPt(e));
    }
  }

  // ---------- UI helpers ----------
  InputDecoration _dec({
    String? hint,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(.10),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(.35)),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 13)),
  );

  // “quadradinhos” (como antes) para Aluno/Professor
  Widget _roleButton(String r, IconData ic) {
    final selected = role == r;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            role = r;
            // ao alternar: limpa campos e reseta erros
            emailUsr.clear(); senha.clear(); ra.clear();
            _tEmail = _tSenha = _tRa = _submitted = false;
            erro = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(.14) : Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.white60 : Colors.white10,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ic, size: 18, color: Colors.white.withOpacity(.9)),
              const SizedBox(width: 8),
              Text(
                r == 'aluno' ? 'Aluno' : 'Professor',
                style: TextStyle(
                  color: Colors.white.withOpacity(.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ctaOn = ctaEnabled;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // fundo
          Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/poliedro.png'),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                colors: [const Color(0xFF0B091B).withOpacity(.92), const Color(0xFF0B091B).withOpacity(.92)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // card com blur
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 460,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121022).withOpacity(.60),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0,16))],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // Título com ícone
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.school_outlined, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Acesso ao Portal',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Use seu e-mail institucional e senha para entrar.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 16),

                        // quadradinhos Aluno/Professor
                        Row(
                          children: [
                            _roleButton('aluno', Icons.badge),
                            const SizedBox(width: 10),
                            _roleButton('professor', Icons.work_outline),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _label('E-mail institucional'),
                        TextField(
                          controller: emailUsr, // só a parte antes do @
                          focusNode: _emailF,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            hint: 'seu nome',
                            errorText: emailError,
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                            suffixText: _domainForRole, // mostra o @ fixo
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        _label('Senha (mín. 6)'),
                        TextField(
                          controller: senha,
                          focusNode: _senhaF,
                          style: const TextStyle(color: Colors.white),
                          obscureText: !showPass,
                          textInputAction: role=='aluno' ? TextInputAction.next : TextInputAction.done,
                          decoration: _dec(
                            hint: 'Sua senha',
                            errorText: senhaError,
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => showPass = !showPass),
                              icon: Icon(
                                showPass ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                                size: 18,
                              ),
                              tooltip: showPass ? 'Ocultar senha' : 'Mostrar senha',
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) { if (role=='professor' && ctaEnabled && !loading) _login(); },
                        ),

                        if (role=='aluno') ...[
                          const SizedBox(height: 16),
                          _label('RA (7 dígitos)'),
                          TextField(
                            controller: ra,
                            focusNode: _raF,
                            style: const TextStyle(color: Colors.white, letterSpacing: 3),
                            keyboardType: TextInputType.number,
                            maxLength: 7,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _dec(
                              hint: '0000000',
                              errorText: raError,
                              prefixIcon: const Icon(Icons.confirmation_number_outlined, color: Colors.white70),
                            ).copyWith(counterText: ''),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) { if (ctaEnabled && !loading) _login(); },
                          ),
                        ],

                        const SizedBox(height: 12),
                        if (erro != null)
                          Text(erro!, style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),

                        // ===== Botão ENTRAR: apagado -> acende quando válido =====
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: ctaOn ? _login : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: Colors.transparent, // para o gradiente
                              shadowColor: Colors.black45,
                              elevation: ctaOn ? 6 : 0,
                            ).copyWith(
                              foregroundColor: WidgetStateProperty.all(Colors.white),
                            ),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: ctaOn ? 1.0 : 0.42, // apagado até ficar válido
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)], // azul -> roxo
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  constraints: const BoxConstraints(minHeight: 45),
                                  child: loading
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text(
                                          'Entrar',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Links brancos e legíveis
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: loading ? null : _resetPassword,
                              child: const Text('Esqueci minha senha',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/register'),
                              child: const Text('Criar conta',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
