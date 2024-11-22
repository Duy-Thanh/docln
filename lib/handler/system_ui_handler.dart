import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/theme_services.dart';

class AnimatedSystemUIHandler extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AnimatedSystemUIHandler({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<AnimatedSystemUIHandler> createState() => _AnimatedSystemUIHandlerState();
}

class _AnimatedSystemUIHandlerState extends State<AnimatedSystemUIHandler> 
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Color? _previousNavigationBarColor;
  Color? _targetNavigationBarColor;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted) {
      _updateSystemUI(animate: true);
    }
  }

  void _updateSystemUI({bool animate = true}) {
    final themeService = Provider.of<ThemeServices>(context, listen: false);
    final themeMode = themeService.themeMode;
    final isDarkMode = themeMode == ThemeMode.dark;
    final currentTheme = isDarkMode 
        ? themeService.getDarkTheme() 
        : themeService.getLightTheme();

    // Set status bar immediately
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    ));

    // Animate navigation bar color
    final newNavigationBarColor = currentTheme.scaffoldBackgroundColor;
    if (_targetNavigationBarColor != newNavigationBarColor) {
      _previousNavigationBarColor = _targetNavigationBarColor ?? newNavigationBarColor;
      _targetNavigationBarColor = newNavigationBarColor;
      
      if (animate) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    }

    // Update navigation bar during animation
    _controller.addListener(() {
      final color = Color.lerp(
        _previousNavigationBarColor,
        _targetNavigationBarColor,
        _controller.value,
      );
      
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: color,
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeServices>(
      builder: (context, themeService, _) {
        // Update system UI whenever theme changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateSystemUI(animate: true);
        });

        return TweenAnimationBuilder<double>(
          duration: widget.duration,
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) => widget.child,
        );
      },
    );
  }
}