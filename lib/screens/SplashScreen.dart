import 'package:flutter/material.dart';
import 'dart:math';
import 'HomeScreen.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/theme_services.dart';

class Particle {
  late Offset position;
  late double size;
  late double scale;
  late double opacity;
  late double speed;
  late double angle;
  late double rotationSpeed;  // Add rotation
  late double angle2;        // Add second angle for rotation

  Particle() {
    reset();
  }

  void reset() {
    final random = Random();
    position = Offset(
      random.nextDouble() * MediaQueryData.fromView(WidgetsBinding.instance.window).size.width,
      random.nextDouble() * MediaQueryData.fromView(WidgetsBinding.instance.window).size.height,
    );
    size = random.nextDouble() * 8 + 4;  // Larger particles
    scale = random.nextDouble() * 0.8 + 0.2;
    opacity = random.nextDouble() * 0.6 + 0.2;  // More varied opacity
    speed = random.nextDouble() * 1.5 + 0.5;
    angle = random.nextDouble() * 2 * pi;
    rotationSpeed = (random.nextDouble() - 0.5) * 2;  // Random rotation
    angle2 = random.nextDouble() * 2 * pi;
  }

  void update(double delta) {
    position += Offset(
      cos(angle) * speed * delta,
      sin(angle) * speed * delta,
    );
    angle2 += rotationSpeed * delta;  // Update rotation
    
    // Improved screen wrapping
    final screenWidth = MediaQueryData.fromView(WidgetsBinding.instance.window).size.width;
    final screenHeight = MediaQueryData.fromView(WidgetsBinding.instance.window).size.height;
    
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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _floatController;

  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;
  late Animation<double> _textOpacity;
  late Animation<double> _containerScale;
  late Animation<double> _backgroundOpacity;
  late Animation<double> _shimmerOffset;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _particleAnimation;

  final List<Particle> _particles = List.generate(30, (index) => Particle()); // More particles
  DateTime? _lastFrame;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50.0,
      ),
    ]).animate(_mainController);

    _iconRotation = Tween<double>(
      begin: -pi / 2,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    ));

    _containerScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40.0,
      ),
    ]).animate(_mainController);

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    _backgroundOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _shimmerOffset = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    ));

    // Make pulse animation continuous
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50.0,
      ),
    ]).animate(_pulseController);

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_pulseController);

    _particleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _mainController.forward();
    _particleController.forward();
    _pulseController.repeat(); // Only pulse animation repeats

    // Start particle movement
    _lastFrame = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback(_updateParticles);

    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                      ),
                    ),
                    child: this.build(context),
                  ),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(0.01 * (1 - curved.value) * pi)
                      ..scale(0.5 + (0.5 * curved.value)),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ],
              );
            },
            transitionDuration: const Duration(milliseconds: 1200),
          ),
        );
      }
    });
  }

  void _updateParticles(_) {
    if (!mounted || _mainController.isCompleted) return;

    final now = DateTime.now();
    final delta = _lastFrame == null ? 0.0 : (now.difference(_lastFrame!).inMilliseconds / 1000);
    _lastFrame = now;

    for (var particle in _particles) {
      particle.update(delta);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    late Animation<double> _floatAnimation;
      _floatAnimation = Tween<double>(
        begin: -4.0,
        end: 4.0,
      ).animate(CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
    ));
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          // Animated particles
          ...List.generate(_particles.length, (index) {
            final particle = _particles[index];
            return Positioned(
              left: particle.position.dx,
              top: particle.position.dy,
              child: AnimatedBuilder(
                 animation: Listenable.merge([
                  _containerScale, 
                  _pulseAnimation,
                ]),
                builder: (context, child) {
                  return Transform.rotate(
                    angle: particle.angle2,  // Add rotation
                    child: Transform.scale(
                      scale: particle.scale * _particleAnimation.value,
                      child: Opacity(
                        opacity: particle.opacity * _particleAnimation.value,
                        child: Container(
                          width: particle.size,
                          height: particle.size,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(  // Add gradient
                              colors: [
                                primaryColor.withOpacity(0.6),
                                primaryColor.withOpacity(0.3),
                                primaryColor.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
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

          // Animated gradient background
          AnimatedBuilder(
            animation: Listenable.merge([_containerScale, _pulseAnimation]),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryColor.withOpacity(0.12 * _backgroundOpacity.value),
                      Theme.of(context).colorScheme.background.withOpacity(0.95),
                      Theme.of(context).colorScheme.background,
                    ],
                    stops: [
                      sin(_waveAnimation.value) * 0.1 + 0.1,
                      0.6,
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Icon with Container
                AnimatedBuilder(
                  animation: Listenable.merge([_containerScale, _pulseAnimation]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                        child: Transform.scale(
                          scale: _containerScale.value * _pulseAnimation.value,
                          child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.2),
                                blurRadius: 20 * _containerScale.value,
                                spreadRadius: 5 * _containerScale.value,
                              ),
                            ],
                          ),
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.8),
                                  primaryColor,
                                ],
                                stops: [
                                  0.0,
                                  _shimmerOffset.value,
                                  1.0,
                                ],
                              ).createShader(bounds);
                            },
                            child: Transform.rotate(
                              angle: _iconRotation.value,
                              child: Transform.scale(
                                scale: _iconScale.value,
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  size: 64,
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
                const SizedBox(height: 32),
                // Animated Text
                AnimatedBuilder(
                  animation: _textOpacity,
                  builder: (context, child) {
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
                                  primaryColor,
                                  primaryColor.withOpacity(0.8),
                                  primaryColor,
                                ],
                                stops: [0.0, _shimmerOffset.value, 1.0],
                              ).createShader(bounds);
                            },
                            child: Text(
                              'DocLN',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Light Novel Reader',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                              letterSpacing: 0.5,
                            ),
                          ),
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