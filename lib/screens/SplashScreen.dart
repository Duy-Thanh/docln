import 'package:flutter/material.dart';
import 'dart:math';
import 'HomeScreen.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/theme_services.dart';
import '../services/performance_service.dart';

class Particle {
  late Offset position;
  late double size;
  late double scale;
  late double opacity;
  late double speed;
  late double angle;
  late double rotationSpeed;
  late double angle2;
  late Color color;
  late double lifespan;
  late double maxLifespan;

  Particle() {
    reset();
  }

  void reset() {
    final random = Random();
    position = Offset(
      random.nextDouble() *
          MediaQueryData.fromView(WidgetsBinding.instance.window).size.width,
      random.nextDouble() *
          MediaQueryData.fromView(WidgetsBinding.instance.window).size.height,
    );
    size = random.nextDouble() * 10 + 3; // More varied particle sizes
    scale = random.nextDouble() * 0.8 + 0.2;
    opacity = random.nextDouble() * 0.7 + 0.3;
    speed = random.nextDouble() * 2.0 + 0.5;
    angle = random.nextDouble() * 2 * pi;
    rotationSpeed = (random.nextDouble() - 0.5) * 3; // Faster rotation
    angle2 = random.nextDouble() * 2 * pi;

    // Randomize particle lifespans
    maxLifespan = random.nextDouble() * 8 + 4; // 4-12 seconds lifespan
    lifespan = maxLifespan;

    // Initialize with a default color (will be updated in update method)
    color = Colors.blue.withOpacity(opacity);
  }

  void update(double delta, Color primaryColor) {
    position += Offset(cos(angle) * speed * delta, sin(angle) * speed * delta);
    angle2 += rotationSpeed * delta;

    // Decrease lifespan
    lifespan -= delta;
    if (lifespan <= 0) {
      reset();
    }

    // Fade out as particle ages
    opacity = (lifespan / maxLifespan) * 0.7 + 0.1;

    // Dynamic color based on lifespan
    final hslColor = HSLColor.fromColor(primaryColor);
    final hue = (hslColor.hue + (lifespan * 10) % 360) % 360;
    color =
        HSLColor.fromAHSL(
          opacity,
          hue,
          hslColor.saturation * 0.8,
          hslColor.lightness,
        ).toColor();

    // Wrap around screen edges with buffer
    final screenWidth =
        MediaQueryData.fromView(WidgetsBinding.instance.window).size.width;
    final screenHeight =
        MediaQueryData.fromView(WidgetsBinding.instance.window).size.height;

    if (position.dx < -50) position = Offset(screenWidth + 50, position.dy);
    if (position.dx > screenWidth + 50) position = Offset(-50, position.dy);
    if (position.dy < -50) position = Offset(position.dx, screenHeight + 50);
    if (position.dy > screenHeight + 50) position = Offset(position.dx, -50);
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
  late AnimationController _particleController;
  late AnimationController _floatController;
  late AnimationController _glowController;

  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;
  late Animation<double> _textOpacity;
  late Animation<double> _containerScale;
  late Animation<double> _backgroundOpacity;
  late Animation<double> _shimmerOffset;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _logoColorAnimation;

  final List<Particle> _particles = List.generate(
    45,
    (index) => Particle(),
  ); // More particles
  DateTime? _lastFrame;
  bool _showLoadingText = false;

  @override
  void initState() {
    super.initState();
    _optimizeScreen();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60.0,
      ),
    ]).animate(_mainController);

    _iconRotation = Tween<double>(begin: -pi, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _containerScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40.0,
      ),
    ]).animate(_mainController);

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _backgroundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _shimmerOffset = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Enhanced pulse animation
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50.0,
      ),
    ]).animate(_pulseController);

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_pulseController);

    _particleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _logoColorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _particleController.forward();
    _pulseController.repeat();

    // Start particle movement
    _lastFrame = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback(_updateParticles);

    // Show "Loading..." text after 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showLoadingText = true;
        });
      }
    });

    // Navigate to HomeScreen after 4.5 seconds with a beautiful transition
    Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => HomeScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              var curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              );

              return Stack(
                children: [
                  FadeTransition(
                    opacity: Tween<double>(begin: 1, end: 0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                      ),
                    ),
                    child: this.build(context),
                  ),
                  Transform(
                    alignment: Alignment.center,
                    transform:
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateX(0.01 * (1 - curved.value) * pi)
                          ..scale(0.5 + (0.5 * curved.value)),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: const Interval(
                            0.5,
                            1.0,
                            curve: Curves.easeOut,
                          ),
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ],
              );
            },
            transitionDuration: const Duration(milliseconds: 1300),
          ),
        );
      }
    });
  }

  Future<void> _optimizeScreen() async {
    await PerformanceService.optimizeScreen('SplashScreen');
  }

  void _updateParticles(_) {
    if (!mounted || _mainController.isCompleted) return;

    final now = DateTime.now();
    final delta =
        _lastFrame == null
            ? 0.0
            : (now.difference(_lastFrame!).inMilliseconds / 1000);
    _lastFrame = now;

    final primaryColor = Theme.of(context).colorScheme.primary;

    for (var particle in _particles) {
      particle.update(delta, primaryColor);
    }

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback(_updateParticles);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    final _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: Listenable.merge([_waveAnimation, _glowAnimation]),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryColor.withOpacity(
                        0.15 * _backgroundOpacity.value * _glowAnimation.value,
                      ),
                      Theme.of(
                        context,
                      ).colorScheme.background.withOpacity(0.95),
                      Theme.of(context).colorScheme.background,
                    ],
                    stops: [sin(_waveAnimation.value) * 0.15 + 0.15, 0.65, 1.0],
                  ),
                ),
              );
            },
          ),

          // Animated particles
          ...List.generate(_particles.length, (index) {
            final particle = _particles[index];
            return Positioned(
              left: particle.position.dx,
              top: particle.position.dy,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _particleAnimation,
                  _pulseAnimation,
                ]),
                builder: (context, child) {
                  return Transform.rotate(
                    angle: particle.angle2,
                    child: Transform.scale(
                      scale: particle.scale * _particleAnimation.value,
                      child: Opacity(
                        opacity: particle.opacity * _particleAnimation.value,
                        child: Container(
                          width: particle.size,
                          height: particle.size,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                particle.color.withOpacity(0.8),
                                particle.color.withOpacity(0.4),
                                particle.color.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: particle.color.withOpacity(0.5),
                                blurRadius: particle.size * 2,
                                spreadRadius: particle.size / 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          // Radial glow behind icon
          Center(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.2 * _glowAnimation.value),
                        primaryColor.withOpacity(0.1 * _glowAnimation.value),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Icon with Container
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _containerScale,
                    _pulseAnimation,
                    _floatAnimation,
                    _logoColorAnimation,
                  ]),
                  builder: (context, child) {
                    // Calculate color shift for the icon
                    final hslColor = HSLColor.fromColor(primaryColor);
                    final hue =
                        (hslColor.hue + _logoColorAnimation.value * 20) % 360;
                    final iconColor =
                        HSLColor.fromAHSL(
                          1.0,
                          hue,
                          hslColor.saturation,
                          hslColor.lightness +
                              (_logoColorAnimation.value * 0.15),
                        ).toColor();

                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: Transform.scale(
                        scale: _containerScale.value * _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withOpacity(
                                  0.3 * _glowAnimation.value,
                                ),
                                blurRadius: 30 * _containerScale.value,
                                spreadRadius: 8 * _containerScale.value,
                              ),
                            ],
                            border: Border.all(
                              color: primaryColor.withOpacity(
                                0.3 * _glowAnimation.value,
                              ),
                              width: 2,
                            ),
                          ),
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  iconColor.withOpacity(0.9),
                                  Colors.white.withOpacity(0.95),
                                  iconColor.withOpacity(0.9),
                                ],
                                stops: [0.0, _shimmerOffset.value, 1.0],
                              ).createShader(bounds);
                            },
                            child: Transform.rotate(
                              angle: _iconRotation.value,
                              child: Transform.scale(
                                scale: _iconScale.value,
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  size: 68,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                // Animated Text
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _textOpacity,
                    _shimmerOffset,
                    _logoColorAnimation,
                  ]),
                  builder: (context, child) {
                    // Calculate text color shift
                    final hslColor = HSLColor.fromColor(primaryColor);
                    final hue =
                        (hslColor.hue + _logoColorAnimation.value * 20) % 360;
                    final textColor =
                        HSLColor.fromAHSL(
                          1.0,
                          hue,
                          hslColor.saturation,
                          hslColor.lightness +
                              (_logoColorAnimation.value * 0.15),
                        ).toColor();

                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  textColor,
                                  Colors.white.withOpacity(0.9),
                                  textColor,
                                ],
                                stops: [0.0, _shimmerOffset.value, 1.0],
                              ).createShader(bounds);
                            },
                            child: Text(
                              'DocLN',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: textColor.withOpacity(0.7),
                                    blurRadius: 15,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Light Novel Reader',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.85),
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                            ),
                          ),
                          if (_showLoadingText) ...[
                            const SizedBox(height: 30),
                            // Animated loading indicator
                            SizedBox(
                              width: 120,
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (int i = 0; i < 3; i++)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                          ),
                                          child: Transform.scale(
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
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: primaryColor.withOpacity(
                                                  0.7,
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: primaryColor
                                                        .withOpacity(0.4),
                                                    blurRadius: 5,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground.withOpacity(0.6),
                                fontSize: 14,
                                letterSpacing: 2.0,
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
