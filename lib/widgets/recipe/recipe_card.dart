import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import 'recipe_image_widget.dart';

class RecipeCard extends StatefulWidget {
  final String title;
  final String image;
  final String time;
  final int servings;
  final int calories;
  final List<String>? tags;
  final int delay;
  final bool hideImage;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.title,
    required this.image,
    required this.time,
    required this.servings,
    required this.calories,
    this.tags,
    this.delay = 0,
    this.hideImage = false,
    this.onTap,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _scaleAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onTap ?? () {
                context.push('/recipe/${_createSlug(widget.title)}');
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.getCardShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image container (hidden if hideImage is true)
                    if (!widget.hideImage)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: SizedBox(
                              height: 192, // h-48 = 192px to match web app
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  RecipeImageWidget(
                                    image: widget.image,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 192,
                                    placeholder: Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                      child: const Icon(Icons.error),
                                    ),
                                  ),
                                ],
                              ),
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
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Action buttons
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Row(
                              children: [
                                _ActionButton(
                                  icon: Icons.favorite,
                                  isActive: _isLiked,
                                  color: AppColors.geniePink,
                                  onTap: () =>
                                      setState(() => _isLiked = !_isLiked),
                                ),
                                const SizedBox(width: 8),
                                _ActionButton(
                                  icon: Icons.bookmark,
                                  isActive: _isSaved,
                                  color: AppColors.geniePurple,
                                  onTap: () =>
                                      setState(() => _isSaved = !_isSaved),
                                ),
                              ],
                            ),
                          ),
                          // Tags
                          if (widget.tags != null && widget.tags!.isNotEmpty)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Wrap(
                                spacing: 6,
                                children: widget.tags!
                                    .take(2)
                                    .map(
                                      (tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).cardColor.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          tag,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: Directionality.of(context),
                          ),
                          const SizedBox(height: 12),
                          // Stats
                          Row(
                            children: [
                              _StatItem(
                                icon: Icons.access_time,
                                value: _formatTime(widget.time, context),
                                color: AppColors.geniePurple,
                              ),
                              const SizedBox(width: 16),
                              _StatItem(
                                icon: Icons.people,
                                value:
                                    '${widget.servings} ${context.t('recipe.detail.servings')}',
                                color: AppColors.geniePink,
                              ),
                              const SizedBox(width: 16),
                              Flexible(
                                child: _StatItem(
                                  icon: Icons.local_fire_department,
                                  value:
                                      '${widget.calories} ${context.t('recipe.detail.cal')}',
                                  color: AppColors.genieGold,
                                ),
                              ),
                            ],
                          ),
                          if (widget.hideImage &&
                              widget.tags != null &&
                              widget.tags!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.tags!
                                  .take(3)
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? color
              : Theme.of(context).cardColor.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isActive
                    ? color
                    : Theme.of(context).cardColor.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
