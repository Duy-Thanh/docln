import 'package:flutter/material.dart';
import '../services/eye_protection_service.dart';

/// A text widget that applies eye-protection features to the displayed text
class EyeFriendlyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool applyProtection;

  const EyeFriendlyText({
    Key? key,
    required this.text,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.applyProtection = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eyeProtectionService = EyeProtectionService();

    // Base text style
    final TextStyle baseStyle = style ?? DefaultTextStyle.of(context).style;

    // Apply eye protection if enabled
    final TextStyle finalStyle =
        applyProtection && eyeProtectionService.eyeProtectionEnabled
            ? _applyEyeProtection(baseStyle, eyeProtectionService)
            : baseStyle;

    return Text(
      text,
      style: finalStyle,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }

  /// Apply eye protection features to text style
  TextStyle _applyEyeProtection(
    TextStyle baseStyle,
    EyeProtectionService service,
  ) {
    // Apply eye protection to the text color
    final Color protectedColor = service.applyEyeProtection(
      baseStyle.color ?? Colors.black,
    );

    // Determine optimal letter spacing and weight for reading
    // Slightly increase letter spacing for better readability
    final double letterSpacing = baseStyle.letterSpacing ?? 0.0;
    final double adjustedLetterSpacing = letterSpacing + 0.15;

    // Adjust font weight for better contrast if needed
    final FontWeight adjustedWeight = _adjustFontWeight(baseStyle.fontWeight);

    // Return the modified style
    return baseStyle.copyWith(
      color: protectedColor,
      letterSpacing: adjustedLetterSpacing,
      fontWeight: adjustedWeight,
      // Apply small shadows to reduce contrast strain if in dark mode
      shadows:
          baseStyle.color != null && baseStyle.color!.computeLuminance() > 0.5
              ? [
                Shadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 0.5),
                  blurRadius: 0.5,
                ),
              ]
              : null,
    );
  }

  /// Adjust font weight for better readability
  FontWeight _adjustFontWeight(FontWeight? weight) {
    // If in very thin weights, increase slightly for better readability
    if (weight == null ||
        weight == FontWeight.w100 ||
        weight == FontWeight.w200) {
      return FontWeight.w300;
    }
    return weight;
  }
}
