import 'package:flutter/material.dart';
import 'dart:math';
import 'package:docln/features/home/ui/HomeScreen.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:docln/core/services/theme_services.dart';
import 'package:docln/core/services/performance_service.dart';

class Particle {
  late Offset position;
  late double size;
  late double opacity;
  late double speed;
  late double angle;

  Particle() {
    reset();
  }

  void reset() {
    final random = Random();
    position = Offset(random.nextDouble() * 400, random.nextDouble() * 800);
    size = random.nextDouble() * 4 + 2; // Smaller particles
    opacity = random.nextDouble() * 0.4 + 0.2; // Lower opacity
    speed = random.nextDouble() * 1.0 + 0.3; // Slower movement
    angle = random.nextDouble() * 2 * pi;
  }

  void update(double delta) {
    position += Offset(cos(angle) * speed * delta, sin(angle) * speed * delta);

    // Simple screen wrapping
    if (position.dx < -20) position = Offset(420, position.dy);
    if (position.dx > 420) position = Offset(-20, position.dy);
    if (position.dy < -20) position = Offset(position.dx, 820);
    if (position.dy > 820) position = Offset(position.dx, -20);
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;

  late Animation<double> _iconScale;
  late Animation<double> _textOpacity;
  late Animation<double> _pulseAnimation;

  final List<Particle> _particles = List.generate(
    12, // Reduced particles
    (index) => Particle(),
  );
  DateTime? _lastFrame;
  bool _showLoadingText = false;

  @override
  void initState() {
    super.initState();
    _optimizeScreen();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();

    // Start simple particle movement
    _lastFrame = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback(_updateParticles);

    // Show loading text after animation
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showLoadingText = true;
        });
      }
    });

    // Navigate to home after 3 seconds
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  Future<void> _optimizeScreen() async {
    await PerformanceService.optimizeScreen('SplashScreen');
  }

  void _updateParticles(_) {
    if (!mounted) return;

    final now = DateTime.now();
    final delta = _lastFrame == null
        ? 0.0
        : (now.difference(_lastFrame!).inMilliseconds / 1000);
    _lastFrame = now;

    // Update particles less frequently
    if (delta > 0.1) {
      // Only update 10 times per second instead of 60
      for (var particle in _particles) {
        particle.update(delta);
      }
      if (mounted) setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback(_updateParticles);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          // Simple gradient background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  primaryColor.withOpacity(0.1),
                  Theme.of(context).colorScheme.background,
                ],
              ),
            ),
          ),

          // Simple particles
          ...List.generate(_particles.length, (index) {
            final particle = _particles[index];
            return Positioned(
              left: particle.position.dx,
              top: particle.position.dy,
              child: Opacity(
                opacity: particle.opacity,
                child: Container(
                  width: particle.size,
                  height: particle.size,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Icon
                AnimatedBuilder(
                  animation: Listenable.merge([_iconScale, _pulseAnimation]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _iconScale.value * _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 60,
                          color: primaryColor,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Animated Text
                AnimatedBuilder(
                  animation: _textOpacity,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          Text(
                            'DocLN',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: 2.0,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Light Novel Reader',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.7),
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          if (_showLoadingText) ...[
                            const SizedBox(height: 24),
                            // Simple loading dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < 3; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale:
                                              1.0 +
                                              sin(
                                                    (_pulseController.value *
                                                            2 *
                                                            pi) +
                                                        (i * pi / 3),
                                                  ) *
                                                  0.3,
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(
                                                0.7,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground.withOpacity(0.6),
                                fontSize: 14,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
