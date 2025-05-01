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
  late List<Offset> trail;
  late double trailLength;
  late bool isConstellationStar;
  late List<int> connectedStars;

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

    // Initialize trail
    trailLength = random.nextInt(6) + 3; // 3-8 segments in trail
    trail = List.generate(trailLength.toInt(), (_) => position);

    // 15% chance to be a constellation star
    isConstellationStar = random.nextDouble() < 0.15;
    connectedStars = [];

    // If it's a constellation star, make it slightly bigger and brighter
    if (isConstellationStar) {
      size += 5;
      opacity += 0.2;
      scale += 0.3;
    }
  }

  void update(double delta, Color primaryColor) {
    final oldPosition = position;

    position += Offset(cos(angle) * speed * delta, sin(angle) * speed * delta);
    angle2 += rotationSpeed * delta;

    // Update trail - add new position at the start and remove last position
    trail.insert(0, position);
    if (trail.length > trailLength) {
      trail.removeLast();
    }

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
  late AnimationController _colorController;
  late Animation<Color?> _gradientAnimation;
  late List<List<int>> _constellationLines = [];

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

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();

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

    // Create dynamic color gradient animation
    _gradientAnimation = ColorTween(
      begin: Colors.blue.shade700,
      end: Colors.purple.shade700,
    ).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );

    // Generate constellation connections between stars
    _generateConstellations();
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

  void _generateConstellations() {
    // Find all constellation stars
    final constellationStars =
        _particles.where((p) => p.isConstellationStar).toList();

    // Skip if we have too few stars
    if (constellationStars.length < 3) return;

    // Create random connections between stars, but keep it sparse and natural-looking
    final random = Random();
    _constellationLines = [];

    // Create a few constellation groups (3-6 groups)
    final groupCount = random.nextInt(4) + 3;

    for (int g = 0; g < groupCount; g++) {
      // Each group has 3-7 stars
      final startIdx = random.nextInt(constellationStars.length);
      final starIndexes = <int>[startIdx];

      final connectionCount = random.nextInt(5) + 2;
      for (int i = 0; i < connectionCount; i++) {
        // Find a nearby star that isn't already in this constellation
        int nearestIdx = -1;
        double minDist = double.infinity;

        for (int j = 0; j < constellationStars.length; j++) {
          if (starIndexes.contains(j)) continue;

          final dist =
              (constellationStars[j].position -
                      constellationStars[starIndexes.last].position)
                  .distance;

          if (dist < minDist && dist < 300) {
            // Only connect nearby stars
            minDist = dist;
            nearestIdx = j;
          }
        }

        if (nearestIdx != -1) {
          // Add connection
          _constellationLines.add([starIndexes.last, nearestIdx]);
          starIndexes.add(nearestIdx);

          // Update particles to show they're connected
          constellationStars[starIndexes.last].connectedStars.add(nearestIdx);
          constellationStars[nearestIdx].connectedStars.add(starIndexes.last);
        } else {
          // No more stars to connect
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _colorController.dispose();
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
      body: AnimatedBuilder(
        animation: _colorController,
        builder: (context, child) {
          return Stack(
            children: [
              // Animated color gradient background
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      (_gradientAnimation.value ?? primaryColor).withOpacity(
                        0.12,
                      ),
                      Theme.of(context).colorScheme.background,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),

              // Light rays animation
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _glowAnimation,
                    _pulseAnimation,
                  ]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: LightRaysPainter(
                        glowStrength: _glowAnimation.value,
                        pulseValue: _pulseAnimation.value,
                        baseColor: primaryColor,
                      ),
                    );
                  },
                ),
              ),

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
                            0.15 *
                                _backgroundOpacity.value *
                                _glowAnimation.value,
                          ),
                          Theme.of(
                            context,
                          ).colorScheme.background.withOpacity(0.95),
                          Theme.of(context).colorScheme.background,
                        ],
                        stops: [
                          sin(_waveAnimation.value) * 0.15 + 0.15,
                          0.65,
                          1.0,
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Constellation connections
              Positioned.fill(
                child: CustomPaint(
                  painter: ConstellationPainter(
                    stars:
                        _particles.where((p) => p.isConstellationStar).toList(),
                    connections: _constellationLines,
                    animation: _particleAnimation,
                    baseColor: primaryColor,
                  ),
                ),
              ),

              // Animated particles with trails
              ...List.generate(_particles.length, (index) {
                final particle = _particles[index];
                return Stack(
                  children: [
                    // Particle trail
                    CustomPaint(
                      size: Size(
                        MediaQueryData.fromView(
                          WidgetsBinding.instance.window,
                        ).size.width,
                        MediaQueryData.fromView(
                          WidgetsBinding.instance.window,
                        ).size.height,
                      ),
                      painter: ParticleTrailPainter(
                        particle: particle,
                        animation: _particleAnimation,
                      ),
                    ),
                    // Particle itself
                    Positioned(
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
                              scale:
                                  particle.scale *
                                  _particleAnimation.value *
                                  (particle.isConstellationStar
                                      ? 1.0 +
                                          sin(_pulseAnimation.value * pi * 2) *
                                              0.2
                                      : 1.0),
                              child: Opacity(
                                opacity:
                                    particle.opacity * _particleAnimation.value,
                                child: Container(
                                  width: particle.size,
                                  height: particle.size,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors:
                                          particle.isConstellationStar
                                              ? [
                                                Colors.white.withOpacity(0.95),
                                                particle.color.withOpacity(0.7),
                                                particle.color.withOpacity(0.3),
                                              ]
                                              : [
                                                particle.color.withOpacity(0.9),
                                                particle.color.withOpacity(0.5),
                                                particle.color.withOpacity(0.1),
                                              ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            particle.isConstellationStar
                                                ? Colors.white.withOpacity(0.5)
                                                : particle.color.withOpacity(
                                                  0.5,
                                                ),
                                        blurRadius:
                                            particle.size *
                                            (particle.isConstellationStar
                                                ? 3
                                                : 2),
                                        spreadRadius:
                                            particle.size /
                                            (particle.isConstellationStar
                                                ? 1.5
                                                : 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),

              // Radial glow behind icon with ripple effect
              Center(
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(240, 240),
                      painter: RipplePainter(
                        color: _gradientAnimation.value ?? primaryColor,
                        glowStrength: _glowAnimation.value,
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
                        _colorController,
                      ]),
                      builder: (context, child) {
                        // Calculate color shift for the icon
                        final baseColor =
                            _gradientAnimation.value ?? primaryColor;
                        final hslColor = HSLColor.fromColor(baseColor);
                        final hue =
                            (hslColor.hue + _logoColorAnimation.value * 20) %
                            360;
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
                            scale:
                                _containerScale.value * _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(26),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: iconColor.withOpacity(
                                      0.4 * _glowAnimation.value,
                                    ),
                                    blurRadius: 35 * _containerScale.value,
                                    spreadRadius: 10 * _containerScale.value,
                                  ),
                                ],
                                border: Border.all(
                                  color: primaryColor.withOpacity(
                                    0.4 * _glowAnimation.value,
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
                                      Colors.white.withOpacity(0.97),
                                      iconColor.withOpacity(0.9),
                                    ],
                                    stops: [0.0, _shimmerOffset.value, 1.0],
                                  ).createShader(bounds);
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Pages flipping effect
                                    ...List.generate(3, (index) {
                                      final pageOffset =
                                          index * 0.33; // Stagger pages
                                      return Transform(
                                        transform:
                                            Matrix4.identity()
                                              ..setEntry(3, 2, 0.001)
                                              ..rotateY(
                                                (sin(
                                                          (_pulseController
                                                                      .value *
                                                                  pi *
                                                                  2) +
                                                              pageOffset,
                                                        ) *
                                                        0.2) -
                                                    0.1,
                                              ),
                                        alignment: Alignment.center,
                                        child: Opacity(
                                          opacity: 0.7 - (index * 0.2),
                                          child: Transform.scale(
                                            scale:
                                                _iconScale.value *
                                                (1.0 - (index * 0.1)),
                                            child: Icon(
                                              Icons.menu_book_rounded,
                                              size: 70,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    // Main icon
                                    Transform.rotate(
                                      angle: _iconRotation.value,
                                      child: Transform.scale(
                                        scale: _iconScale.value,
                                        child: Icon(
                                          Icons.menu_book_rounded,
                                          size: 70,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
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
                        _colorController,
                      ]),
                      builder: (context, child) {
                        // Calculate text color shift
                        final baseColor =
                            _gradientAnimation.value ?? primaryColor;
                        final hslColor = HSLColor.fromColor(baseColor);
                        final hue =
                            (hslColor.hue + _logoColorAnimation.value * 20) %
                            360;
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
                                      Colors.white.withOpacity(0.95),
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
                                        color: textColor.withOpacity(0.8),
                                        blurRadius: 18,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (int i = 0; i < 3; i++)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4.0,
                                                  ),
                                              child: Transform.scale(
                                                scale:
                                                    1.0 +
                                                    sin(
                                                          (_pulseController
                                                                      .value *
                                                                  2 *
                                                                  pi) +
                                                              (i * pi / 3),
                                                        ) *
                                                        0.4,
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: (_gradientAnimation
                                                                .value ??
                                                            primaryColor)
                                                        .withOpacity(0.7),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: (_gradientAnimation
                                                                    .value ??
                                                                primaryColor)
                                                            .withOpacity(0.5),
                                                        blurRadius: 8,
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
                                const SizedBox(height: 8),
                                Text(
                                  'Loading...',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground.withOpacity(0.7),
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
          );
        },
      ),
    );
  }
}

// ... existing painters ...

class ConstellationPainter extends CustomPainter {
  final List<Particle> stars;
  final List<List<int>> connections;
  final Animation<double> animation;
  final Color baseColor;

  ConstellationPainter({
    required this.stars,
    required this.connections,
    required this.animation,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stars.isEmpty || connections.isEmpty) return;

    final paint =
        Paint()
          ..color = baseColor.withOpacity(0.2 * animation.value)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0);

    for (final connection in connections) {
      if (connection.length != 2) continue;

      final star1 = stars[connection[0]];
      final star2 = stars[connection[1]];

      // Draw connection line with a subtle glow
      final path = Path();
      path.moveTo(star1.position.dx, star1.position.dy);
      path.lineTo(star2.position.dx, star2.position.dy);

      // Draw a subtle glow around the line
      final glowPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                baseColor.withOpacity(0.2 * animation.value),
                baseColor.withOpacity(0.05 * animation.value),
              ],
            ).createShader(Rect.fromPoints(star1.position, star2.position))
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationPainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
        oldDelegate.stars != stars ||
        oldDelegate.connections != connections;
  }
}

class LightRaysPainter extends CustomPainter {
  final double glowStrength;
  final double pulseValue;
  final Color baseColor;

  LightRaysPainter({
    required this.glowStrength,
    required this.pulseValue,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final numRays = 12;

    for (int i = 0; i < numRays; i++) {
      final angle = (i * pi / (numRays / 2)) + (pulseValue * pi / 6);
      final rayLength = size.width * 0.8 * glowStrength;

      final start = center;
      final end = Offset(
        center.dx + cos(angle) * rayLength,
        center.dy + sin(angle) * rayLength,
      );

      final paint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.center,
              end: Alignment(cos(angle), sin(angle)),
              colors: [
                baseColor.withOpacity(0.4 * glowStrength),
                baseColor.withOpacity(0.1 * glowStrength),
                baseColor.withOpacity(0.0),
              ],
            ).createShader(Rect.fromPoints(start, end))
            ..strokeWidth = 20 + (pulseValue * 10)
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * glowStrength);

      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LightRaysPainter oldDelegate) {
    return oldDelegate.glowStrength != glowStrength ||
        oldDelegate.pulseValue != pulseValue;
  }
}

class ParticleTrailPainter extends CustomPainter {
  final Particle particle;
  final Animation<double> animation;

  ParticleTrailPainter({required this.particle, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    if (particle.trail.length < 2) return;

    final path = Path();
    path.moveTo(particle.trail[0].dx, particle.trail[0].dy);

    for (int i = 1; i < particle.trail.length; i++) {
      path.lineTo(particle.trail[i].dx, particle.trail[i].dy);
    }

    final paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              particle.color.withOpacity(0.7 * animation.value),
              particle.color.withOpacity(0.3 * animation.value),
              particle.color.withOpacity(0.0),
            ],
          ).createShader(
            Rect.fromPoints(
              Offset(particle.trail.first.dx, particle.trail.first.dy),
              Offset(particle.trail.last.dx, particle.trail.last.dy),
            ),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = particle.size * 0.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ParticleTrailPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

class RipplePainter extends CustomPainter {
  final Color color;
  final double glowStrength;

  RipplePainter({required this.color, required this.glowStrength});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw several ripple circles
    for (int i = 0; i < 4; i++) {
      final radius =
          maxRadius *
          (0.4 + (i * 0.15)) *
          (1.0 + sin(glowStrength * pi * 2) * 0.2);
      final opacity = (0.8 - (i * 0.2)) * glowStrength;

      final paint =
          Paint()
            ..color = color.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5);

      canvas.drawCircle(center, radius, paint);
    }

    // Draw central glow
    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(0.4 * glowStrength),
              color.withOpacity(0.2 * glowStrength),
              color.withOpacity(0.0),
            ],
            stops: [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius * 0.8, glowPaint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.glowStrength != glowStrength;
  }
}
