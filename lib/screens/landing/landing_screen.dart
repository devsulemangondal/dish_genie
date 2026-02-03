import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/localization/l10n_extension.dart';
import '../../widgets/common/floating_sparkles.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.gradientHeroDark
                  : AppColors.gradientHero,
            ),
          ),
          const FloatingSparkles(),
          SingleChildScrollView(
            child: Column(
              children: [
                // Hero Section
                _buildHeroSection(context),
                // Features Section
                _buildFeaturesSection(context),
                // How It Works
                _buildHowItWorksSection(context),
                // Testimonials
                _buildTestimonialsSection(context),
                // Final CTA
                _buildFinalCTA(context),
                // Footer
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(minHeight: 600),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Image.asset(
            'assets/images/genie-mascot.png',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 24),
          Text(
            context.t('landing.app.name'),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
          ),
          const SizedBox(height: 32),
          Text(
            context.t('landing.hero.title'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.t('landing.hero.subtitle'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.download),
                label: Text(context.t('landingDownloadForIOS')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.smartphone),
                label: Text(context.t('landingGetOnAndroid')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    List<Map<String, dynamic>> _getFeatures(BuildContext context) {
      return [
        {
          'icon': Icons.restaurant_menu,
          'title': context.t('landing.feature.recipe.builder.title'),
          'description': context.t('landing.feature.recipe.builder.desc'),
          'color': AppColors.primary,
        },
        {
          'icon': Icons.calendar_today,
          'title': context.t('landing.feature.meal.plans.title'),
          'description': context.t('landing.feature.meal.plans.desc'),
          'color': AppColors.secondary,
        },
        {
          'icon': Icons.shopping_cart,
          'title': context.t('landing.feature.grocery.title'),
          'description': context.t('landing.feature.grocery.desc'),
          'color': AppColors.genieGold,
        },
      ];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Why DishGenie?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('landing.kitchen.supercharged'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._getFeatures(context).map((feature) => _buildFeatureCard(
                context,
                feature['icon'] as IconData,
                feature['title'] as String,
                feature['description'] as String,
                feature['color'] as Color,
              )),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection(BuildContext context) {
    List<Map<String, dynamic>> _getSteps(BuildContext context) {
      return [
        {
          'step': '1',
          'title': context.t('landing.step1.title'),
          'description': context.t('landing.step1.desc'),
        },
        {
          'step': '2',
          'title': context.t('landing.step2.title'),
          'description': context.t('landing.step2.desc'),
        },
        {
          'step': '3',
          'title': context.t('landing.step3.title'),
          'description': context.t('landing.step3.desc'),
        },
      ];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            context.t('landing.simple.easy'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('landing.how.it.works'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._getSteps(context).map((step) => _buildStepCard(
                context,
                step['step'] as String,
                step['title'] as String,
                step['description'] as String,
              )),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context,
    String step,
    String title,
    String description,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: Theme.of(context).cardColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    List<Map<String, dynamic>> _getTestimonials(BuildContext context) {
      return [
        {
          'name': context.t('landing.testimonial1.name'),
          'role': context.t('landing.testimonial1.role'),
          'quote': context.t('landing.testimonial1.quote'),
          'rating': 5,
        },
        {
          'name': context.t('landing.testimonial2.name'),
          'role': context.t('landing.testimonial2.role'),
          'quote': context.t('landing.testimonial2.quote'),
          'rating': 5,
        },
        {
          'name': context.t('landing.testimonial3.name'),
          'role': context.t('landing.testimonial3.role'),
          'quote': context.t('landing.testimonial3.quote'),
          'rating': 5,
        },
      ];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            context.t('landing.loved.by.thousands'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('landing.what.users.say'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._getTestimonials(context).map((testimonial) => _buildTestimonialCard(
                context,
                testimonial['name'] as String,
                testimonial['role'] as String,
                testimonial['quote'] as String,
                testimonial['rating'] as int,
              )),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(
    BuildContext context,
    String name,
    String role,
    String quote,
    int rating,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              rating,
              (index) => const Icon(Icons.star, color: Colors.amber, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"$quote"',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  name[0],
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    role,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinalCTA(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/genie-mascot.png',
            width: 64,
            height: 64,
          ),
          const SizedBox(height: 24),
          Text(
            context.t('landing.start.cooking.smarter'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.t('landing.join.thousands'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.download),
            label: Text(context.t('landingDownloadForIOS')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(context.t('landingFreeToDownload')),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/genie-mascot.png',
                width: 32,
                height: 32,
              ),
              const SizedBox(width: 8),
              Text(
                context.t('landingAppName'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              TextButton(
                onPressed: () {},
                child: Text(context.t('settingsPrivacyPolicy')),
              ),
              TextButton(
                onPressed: () {},
                child: Text(context.t('settingsTermsConditions')),
              ),
              TextButton(
                onPressed: () {},
                child: Text(context.t('settingsSupport')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.t('landing.copyright'),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
