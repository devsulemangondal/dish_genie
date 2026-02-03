import 'package:flutter/material.dart';

/// RTL-aware icon widget that flips directional icons (arrows, chevrons) in RTL languages
class RtlIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final bool flip;

  const RtlIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.flip = true,
  });

  // Icons that should flip in RTL - using codePoint for reliable comparison
  static final _flipIconCodePoints = {
    Icons.arrow_back.codePoint,
    Icons.arrow_forward.codePoint,
    Icons.arrow_back_ios.codePoint,
    Icons.arrow_forward_ios.codePoint,
    Icons.chevron_left.codePoint,
    Icons.chevron_right.codePoint,
    Icons.keyboard_arrow_left.codePoint,
    Icons.keyboard_arrow_right.codePoint,
    Icons.navigate_before.codePoint,
    Icons.navigate_next.codePoint,
  };

  @override
  Widget build(BuildContext context) {
    // Depend on Directionality so this rebuilds when the app switches LTR/RTL.
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    // Many Material icons already come with IconData.matchTextDirection=true,
    // which Flutter will mirror automatically in RTL.
    //
    // Only apply a manual mirror when:
    // - we explicitly want to flip (`flip`),
    // - this is a directional icon we care about,
    // - we're currently in RTL,
    // - and the icon does NOT already auto-mirror.
    final isDirectional = flip && _flipIconCodePoints.contains(icon.codePoint);
    final shouldManuallyFlip = isDirectional && isRTL && !icon.matchTextDirection;

    final iconWidget = Icon(
      icon,
      size: size,
      color: color,
    );

    if (!shouldManuallyFlip) return iconWidget;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
      child: iconWidget,
    );
  }
}

/// RTL-aware back arrow
class RtlBackIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const RtlBackIcon({
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RtlIcon(
      icon: Icons.arrow_back,
      size: size,
      color: color,
    );
  }
}

/// RTL-aware forward/next arrow
class RtlForwardIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const RtlForwardIcon({
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RtlIcon(
      icon: Icons.arrow_forward,
      size: size,
      color: color,
    );
  }
}

/// RTL-aware chevron right
class RtlChevronRight extends StatelessWidget {
  final double? size;
  final Color? color;

  const RtlChevronRight({
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RtlIcon(
      icon: Icons.chevron_right,
      size: size,
      color: color,
    );
  }
}

/// RTL-aware chevron left
class RtlChevronLeft extends StatelessWidget {
  final double? size;
  final Color? color;

  const RtlChevronLeft({
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RtlIcon(
      icon: Icons.chevron_left,
      size: size,
      color: color,
    );
  }
}
