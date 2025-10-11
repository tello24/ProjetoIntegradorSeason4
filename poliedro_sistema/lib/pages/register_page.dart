import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final name = TextEditingController();
  final emailUsr = TextEditingController(); // apenas a parte antes do @
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  final ra = TextEditingController();

  // Focus (erros só após blur/submit)
  final _nameF = FocusNode();
  final _emailF = FocusNode();
  final _passF = FocusNode();
  final _pass2F = FocusNode();
  final _raF = FocusNode();

  bool loading = false;
  String? erro;
  bool showPass = false;
  bool showPass2 = false;

  // Flags de erro
  bool _tName = false,
      _tEmail = false,
      _tPass = false,
      _tPass2 = false,
      _tRa = false,
      _submitted = false;

  // Papel selecionado (UI + validação)
  String role = 'aluno'; // 'aluno' | 'professor'

  // Domínios
  static const alunoDomain = '@p4ed.com';
  static const profDomainMain = '@sistemapoliedro.com';
  static const profDomainsAll = [
    '@sistemapoliedro.com',
    '@sistemapoliedro.com',
  ]; // mantido se quiser usar depois

  bool raEmUso = false;

  String get _domainForRole => role == 'aluno' ? alunoDomain : profDomainMain;

  // e-mail completo a partir do user + domínio fixo
  String get emailFull {
    final user = emailUsr.text.trim().toLowerCase();
    if (user.isEmpty) return '';
    return '$user$_domainForRole';
  }

  bool get _emailUserOk => RegExp(r'^[^\s@]+$').hasMatch(emailUsr.text.trim());
  bool get isAluno => role == 'aluno';
  bool get isProf => role == 'professor';

  // ---------- Validações ----------
  bool get nameValido => name.text.trim().length >= 2;
  bool get passValida => pass.text.trim().length >= 6;
  bool get passConfere => pass.text == pass2.text;
  bool get raValido => !isAluno || RegExp(r'^\d{7}$').hasMatch(ra.text.trim());

  String? get nameError {
    final show = ((_tName && !_nameF.hasFocus) || _submitted);
    if (!show) return null;
    if (!nameValido) return 'Informe seu nome completo';
    return null;
  }

  String? get emailError {
    final show = ((_tEmail && !_emailF.hasFocus) || _submitted);
    if (!show) return null;
    if (emailUsr.text.trim().isEmpty)
      return 'Informe o nome do e-mail institucional';
    if (!_emailUserOk) return 'Caracteres inválidos no e-mail';
    return null;
  }

  String? get passError {
    final show = ((_tPass && !_passF.hasFocus) || _submitted);
    if (!show) return null;
    if (!passValida) return 'Senha muito curta (mín. 6)';
    return null;
  }

  String? get pass2Error {
    final show = ((_tPass2 && !_pass2F.hasFocus) || _submitted);
    if (!show) return null;
    if (!passConfere) return 'As senhas não conferem';
    return null;
  }

  String? get raError {
    if (!isAluno) return null;
    final show = ((_tRa && !_raF.hasFocus) || _submitted);
    if (!show) return null;
    if (!RegExp(r'^\d{7}$').hasMatch(ra.text.trim()))
      return 'RA deve ter 7 dígitos';
    if (raEmUso) return 'Este RA já está cadastrado para outro aluno.';
    return null;
  }

  // CTA habilita sem depender das flags visuais
  bool get ctaEnabled {
    final base =
        nameValido && _emailUserOk && passValida && passConfere && !loading;
    if (isAluno) {
      return base && RegExp(r'^\d{7}$').hasMatch(ra.text.trim()) && !raEmUso;
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    _nameF.addListener(() {
      if (!_nameF.hasFocus) setState(() => _tName = true);
    });
    _emailF.addListener(() {
      if (!_emailF.hasFocus) setState(() => _tEmail = true);
    });
    _passF.addListener(() {
      if (!_passF.hasFocus) setState(() => _tPass = true);
    });
    _pass2F.addListener(() {
      if (!_pass2F.hasFocus) setState(() => _tPass2 = true);
    });
    _raF.addListener(() {
      if (!_raF.hasFocus) setState(() => _tRa = true);
    });
  }

  @override
  void dispose() {
    _nameF.dispose();
    _emailF.dispose();
    _passF.dispose();
    _pass2F.dispose();
    _raF.dispose();
    name.dispose();
    emailUsr.dispose();
    pass.dispose();
    pass2.dispose();
    ra.dispose();
    super.dispose();
  }

  String _authErrorPt(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'Senha fraca (mínimo 6 caracteres).';
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão.';
      default:
        return e.message ?? 'Falha ao cadastrar.';
    }
  }

  // UI: quadradinho de papel (Sou aluno / Sou professor)
  Widget _roleButton(String r, IconData ic, String label) {
    final selected = role == r;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            role = r;
            // limpa TUDO e reseta erros quando alterna
            name.clear();
            emailUsr.clear();
            pass.clear();
            pass2.clear();
            ra.clear();
            _tName = _tEmail = _tPass = _tPass2 = _tRa = _submitted = false;
            raEmUso = false;
            erro = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(.14)
                : Colors.white.withOpacity(.06),
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
                label,
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

  Future<void> _registrar() async {
    setState(() {
      _submitted = true;
      _tName = _tEmail = _tPass = _tPass2 = _tRa = true;
      erro = null;
    });
    if (!ctaEnabled) return;

    setState(() => loading = true);
    FocusScope.of(context).unfocus();

    String? createdUid;
    try {
      // e-mail final (auto sufixo @)
      final emailFinal = emailFull;

      // 1) Cria no Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailFinal,
        password: pass.text.trim(),
      );
      createdUid = cred.user?.uid;

      // 2) Grava perfil em users/{uid}
      final data = <String, dynamic>{
        'name': name.text.trim(),
        'email': emailFinal,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (role == 'aluno') data['ra'] = ra.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(createdUid)
          .set(data, SetOptions(merge: true));

      // 3) Redireciona
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        role == 'professor' ? '/prof' : '/aluno',
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => erro = _authErrorPt(e));
    } catch (e) {
      setState(() => erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
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
      suffixStyle: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
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

  @override
  Widget build(BuildContext context) {
    final bool ctaOn = ctaEnabled;

    return Scaffold(
      // sem AppBar (para não criar espaço acima). Usamos SafeArea no conteúdo.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo
          Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/poliedro.png'),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B091B).withOpacity(.92),
                  const Color(0xFF0B091B).withOpacity(.92),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Card central com SafeArea para colar o "Voltar" no topo
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: 480,
                      padding: const EdgeInsets.fromLTRB(
                        22,
                        12,
                        22,
                        16,
                      ), // topo bem justo
                      decoration: BoxDecoration(
                        color: const Color(0xFF121022).withOpacity(.60),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 30,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          // Topo: botão Voltar sem espaço sobrando
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Voltar',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Título
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.person_add_alt_1,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Criar conta',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Preencha seus dados institucionais para criar a conta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Papel: Sou aluno / Sou professor
                          Row(
                            children: [
                              _roleButton(
                                'aluno',
                                Icons.school_outlined,
                                'Sou aluno',
                              ),
                              const SizedBox(width: 10),
                              _roleButton(
                                'professor',
                                Icons.work_outline,
                                'Sou professor',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _label('Nome completo'),
                          TextField(
                            controller: name,
                            focusNode: _nameF,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.next,
                            decoration: _dec(
                              hint: 'Nome completo',
                              errorText: nameError,
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: Colors.white70,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          _label('E-mail institucional'),
                          TextField(
                            controller: emailUsr, // só o nome antes do @
                            focusNode: _emailF,
                            style: const TextStyle(color: Colors.white),
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _dec(
                              hint: 'seu nome',
                              errorText: emailError,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Colors.white70,
                              ),
                              suffixText: _domainForRole, // mostra o @ fixo
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          _label('Senha (mín. 6)'),
                          TextField(
                            controller: pass,
                            focusNode: _passF,
                            style: const TextStyle(color: Colors.white),
                            autocorrect: false,
                            enableSuggestions: false,
                            obscureText: !showPass,
                            textInputAction: TextInputAction.next,
                            decoration: _dec(
                              hint: 'Crie uma senha',
                              errorText: passError,
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white70,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => showPass = !showPass),
                                icon: Icon(
                                  showPass
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                tooltip: showPass
                                    ? 'Ocultar senha'
                                    : 'Mostrar senha',
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          _label('Confirmar senha'),
                          TextField(
                            controller: pass2,
                            focusNode: _pass2F,
                            style: const TextStyle(color: Colors.white),
                            autocorrect: false,
                            enableSuggestions: false,
                            obscureText: !showPass2,
                            textInputAction: isAluno
                                ? TextInputAction.next
                                : TextInputAction.done,
                            decoration: _dec(
                              hint: 'Repita a senha',
                              errorText: pass2Error,
                              prefixIcon: const Icon(
                                Icons.lock_person_outlined,
                                color: Colors.white70,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => showPass2 = !showPass2),
                                icon: Icon(
                                  showPass2
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                tooltip: showPass2
                                    ? 'Ocultar senha'
                                    : 'Mostrar senha',
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),

                          if (isAluno) ...[
                            const SizedBox(height: 16),
                            _label('RA (7 dígitos)'),
                            TextField(
                              controller: ra,
                              focusNode: _raF,
                              style: const TextStyle(
                                color: Colors.white,
                                letterSpacing: 3,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 7,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _dec(
                                hint: '0000000',
                                errorText: raError,
                                prefixIcon: const Icon(
                                  Icons.confirmation_number_outlined,
                                  color: Colors.white70,
                                ),
                              ).copyWith(counterText: ''),
                              onChanged: (_) {
                                if (raEmUso) setState(() => raEmUso = false);
                                setState(() {});
                              },
                            ),
                          ],

                          const SizedBox(height: 12),
                          if (erro != null)
                            Text(
                              erro!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          const SizedBox(height: 12),

                          // ===== Botão CRIAR CONTA: apagado -> acende quando válido =====
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: ctaOn ? _registrar : null,
                              style:
                                  ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.black45,
                                    elevation: ctaOn ? 6 : 0,
                                  ).copyWith(
                                    foregroundColor: WidgetStateProperty.all(
                                      Colors.white,
                                    ),
                                  ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: ctaOn ? 1.0 : 0.42,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3E5FBF),
                                        Color(0xFF7A45C8),
                                      ], // azul -> roxo
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    constraints: const BoxConstraints(
                                      minHeight: 45,
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Criar conta',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
