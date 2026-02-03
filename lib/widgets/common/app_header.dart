import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import 'genie_mascot.dart';

class AppHeader extends StatelessWidget {
  final bool showMenu;
  final VoidCallback? onSearch;
  final VoidCallback? onFavorites;
  final VoidCallback? onMenu;

  const AppHeader({
    super.key,
    this.showMenu = true,
    this.onSearch,
    this.onFavorites,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              const GenieMascot(size: GenieMascotSize.sm),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.gradientPrimary
                    .createShader(bounds),
                child: Text(
                  context.t('app.header.title'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Icons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: onSearch ?? () => context.go('/search'),
                color: Theme.of(context).colorScheme.onSurface,
                iconSize: 24,
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: onFavorites ?? () => context.push('/favorites'),
                color: Theme.of(context).colorScheme.onSurface,
                iconSize: 24,
              ),
              if (showMenu)
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onMenu ?? () {},
                  color: Theme.of(context).colorScheme.onSurface,
                  iconSize: 24,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
