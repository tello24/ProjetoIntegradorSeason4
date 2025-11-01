// lib/pages/aluno_detalhes_turma_page.dart
// CÓDIGO CORRIGIDO (onTap de Notas) E ESTILIZADO (Botões Maiores)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'materiais_da_turma_page.dart';
import 'aluno_notas_da_turma_page.dart'; 

class AlunoDetalhesTurmaPage extends StatelessWidget {
  final String turmaId;
  final String nomeTurma;

  const AlunoDetalhesTurmaPage({
    super.key,
    required this.turmaId,
    required this.nomeTurma,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          nomeTurma,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Bg(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight),
                  _ActionCard(
                    icon: Icons.folder_copy_outlined,
                    title: 'Ver Materiais',
                    subtitle: 'Acessar arquivos e links da turma',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MateriaisDaTurmaPage(
                            turmaId: turmaId,
                            nomeTurma: nomeTurma,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.calculate_outlined,
                    title: 'Ver Atividades e Notas',
                    subtitle: 'Acompanhar avaliações da matéria',
                    
                    // --- CORREÇÃO APLICADA AQUI ---
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlunoNotasDaTurmaPage(
                            turmaId: turmaId,
                            nomeTurma: nomeTurma,
                          ),
                        ),
                      );
                    },
                    // --- FIM DA CORREÇÃO ---

                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const _Glass({required this.child, this.padding, this.radius = 20});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121022).withOpacity(.18),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.10)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// --- ESTILIZAÇÃO APLICADA AQUI ---
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Padding vertical aumentado
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 50,  // Aumentado de 46 para 50
              height: 50, // Aumentado de 46 para 50
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 26), // Ícone levemente maior
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17, // Aumentado de 16 para 17
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13, // Aumentado de 12.5 para 13
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- FIM DA ESTILIZAÇÃO ---


class _Bg extends StatelessWidget {
  const _Bg();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/poliedro.png'),
          fit: BoxFit.cover,
        ),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B091B).withOpacity(.88),
            const Color(0xFF0B091B).withOpacity(.88),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}