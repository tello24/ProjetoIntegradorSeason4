import 'dart:ui';
import 'package:flutter/material.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 640;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo engrenagens
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

          // Marca d’água central (logo grande ao fundo)
          Center(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/iconePoliedro.png',
                  width: _watermarkSize(context),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Vinheta radial levinha
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Colors.transparent, Colors.black54],
                stops: [.62, 1],
                radius: 1.04,
              ),
            ),
          ),

          // Painel único de vidro envolvendo TUDO
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 18 : 34,
                          vertical: isMobile ? 22 : 30,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121022).withOpacity(.22),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(.14)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 18)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // === Badge com a SUA logo (mini) + texto ===
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: .9,
                                  child: Image.asset(
                                    'assets/images/iconePoliedro.png',
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Colégio Poliedro',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.92),
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 13.5 : 14.5,
                                    letterSpacing: .2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // título
                            Text(
                              'Bem-vindo ao Portal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.98),
                                fontSize: isMobile ? 28 : 36,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // subtítulo
                            Text(
                              'Materiais, atividades, mensagens e notas em um só lugar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.90),
                                fontSize: isMobile ? 13.5 : 15,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 22),

                            // CTA Entrar
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.black45,
                                    elevation: 10,
                                  ).copyWith(foregroundColor: WidgetStateProperty.all(Colors.white)),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF3E5FBF), Color(0xFF7A45C8)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const SizedBox(
                                      height: 48,
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.login_rounded),
                                            SizedBox(width: 10),
                                            Text('Entrar',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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

  double _watermarkSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 640) return (w * 1.15).clamp(420.0, 760.0);
    if (w < 1000) return (w * 0.82).clamp(520.0, 820.0);
    return (w * 0.55).clamp(720.0, 980.0);
  }
}
