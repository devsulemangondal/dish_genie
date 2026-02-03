import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../data/models/recipe.dart';
import 'recipe_image_widget.dart';

class RecipeGridCard extends StatelessWidget {
  final Recipe recipe;

  const RecipeGridCard({
    super.key,
    required this.recipe,
  });

  String _createSlug(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  String _formatTime(String time, BuildContext context) {
    // Extract number from time string (e.g., "30 min" -> "30")
    final numberMatch = RegExp(r'\d+').firstMatch(time);
    if (numberMatch != null) {
      final number = numberMatch.group(0)!;
      return '$number ${context.t('recipe.detail.min')}';
    }
    // Fallback: return as-is if no number found
    return time;
  }

  ({Color bg, Color fg}) _getTagColors(String tag, BuildContext context) {
    final lowerTag = tag.toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;

    if (lowerTag.contains('high protein') || lowerTag.contains('protein')) {
      return (
        bg: colorScheme.primaryContainer,
        fg: colorScheme.onPrimaryContainer,
      );
    } else if (lowerTag.contains('vegetarian') || lowerTag.contains('vegan')) {
      return (
        bg: colorScheme.secondaryContainer,
        fg: colorScheme.onSecondaryContainer,
      );
    } else if (lowerTag.contains('healthy')) {
      return (
        bg: colorScheme.tertiaryContainer,
        fg: colorScheme.onTertiaryContainer,
      );
    } else if (lowerTag.contains('quick')) {
      return (bg: colorScheme.errorContainer, fg: colorScheme.onErrorContainer);
    }
    return (bg: colorScheme.surfaceVariant, fg: colorScheme.onSurfaceVariant);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/recipe/${_createSlug(recipe.title)}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.getCardShadow(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Image - Expanded to take maximum space
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                    RecipeImageWidget(
                      image: recipe.image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: Container(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                      ),
                      errorWidget: Container(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: const Icon(Icons.error, size: 24),
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Tag badge
                    if (recipe.tags.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getTagColors(recipe.tags[0], context).bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            recipe.tags[0],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getTagColors(recipe.tags[0], context).fg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content - tightly packed
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      recipe.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: Directionality.of(context),
                    ),
                    const SizedBox(height: 2),
                    // Stats row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 10,
                          color: AppColors.geniePurple,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            _formatTime(recipe.time, context),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                            textDirection: Directionality.of(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.local_fire_department,
                          size: 10,
                          color: AppColors.genieGold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${recipe.calories} ${context.t('recipe.detail.cal')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
