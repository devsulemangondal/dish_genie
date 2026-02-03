import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget for displaying recipe images
/// Supports both network URLs and data URIs (base64 images)
class RecipeImageWidget extends StatelessWidget {
  final String image;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const RecipeImageWidget({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  /// Check if the image is a data URI (base64)
  bool _isDataUri(String image) {
    return image.startsWith('data:image/');
  }

  /// Extract base64 data from data URI
  Uint8List? _decodeDataUri(String dataUri) {
    try {
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex == -1) return null;

      final base64String = dataUri.substring(commaIndex + 1);
      return base64Decode(base64String);
    } catch (e) {
      debugPrint('Error decoding data URI: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty or null image
    if (image.isEmpty) {
      return _buildErrorWidget(context);
    }

    // Handle data URI (base64 images)
    if (_isDataUri(image)) {
      final imageBytes = _decodeDataUri(image);
      if (imageBytes == null) {
        return _buildErrorWidget(context);
      }

      return SizedBox(
        width: width,
        height: height,
        child: Image.memory(
          imageBytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget(context);
          },
        ),
      );
    }

    // Handle network URL
    return SizedBox(
      width: width,
      height: height,
      child: CachedNetworkImage(
        imageUrl: image,
        fit: fit,
        placeholder: (context, url) =>
            placeholder ?? _buildPlaceholder(context),
        errorWidget: (context, url, error) =>
            errorWidget ?? _buildErrorWidget(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: errorWidget ?? const Center(child: Icon(Icons.error)),
    );
  }
}
