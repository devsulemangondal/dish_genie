import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

/// RTL-aware EdgeInsets helper
class RtlEdgeInsets {
  static EdgeInsets symmetric({
    required BuildContext context,
    double? horizontal,
    double? vertical,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal ?? 0,
      vertical: vertical ?? 0,
    );
  }

  static EdgeInsets only({
    required BuildContext context,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    final isRTL = Provider.of<LanguageProvider>(context, listen: false).isRTL;
    return EdgeInsets.only(
      left: isRTL ? (right ?? 0) : (left ?? 0),
      top: top ?? 0,
      right: isRTL ? (left ?? 0) : (right ?? 0),
      bottom: bottom ?? 0,
    );
  }

  static EdgeInsets fromLTRB({
    required BuildContext context,
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final isRTL = Provider.of<LanguageProvider>(context, listen: false).isRTL;
    return EdgeInsets.fromLTRB(
      isRTL ? right : left,
      top,
      isRTL ? left : right,
      bottom,
    );
  }
}

/// RTL-aware alignment helper
class RtlAlignment {
  static AlignmentGeometry start({
    required BuildContext context,
    double y = 0,
  }) {
    final isRTL = Provider.of<LanguageProvider>(context, listen: false).isRTL;
    return isRTL ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart;
  }

  static AlignmentGeometry end({
    required BuildContext context,
    double y = 0,
  }) {
    final isRTL = Provider.of<LanguageProvider>(context, listen: false).isRTL;
    return isRTL ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd;
  }
}
