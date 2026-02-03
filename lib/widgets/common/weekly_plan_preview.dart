import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../providers/meal_plan_provider.dart';
import 'rtl_helper.dart';
import 'rtl_icon.dart';

class WeeklyPlanPreview extends StatefulWidget {
  final int delay;

  const WeeklyPlanPreview({super.key, this.delay = 0});

  @override
  State<WeeklyPlanPreview> createState() => _WeeklyPlanPreviewState();
}

class _WeeklyPlanPreviewState extends State<WeeklyPlanPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isDateInCurrentWeek(DateTime date) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return date.isAfter(monday.subtract(const Duration(days: 1))) &&
        date.isBefore(sunday.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanProvider = context.watch<MealPlanProvider>();
    final mealPlan = mealPlanProvider.currentMealPlan;
    final selectedDay = mealPlanProvider.selectedDay ?? DateTime.now();
    
    // Get locale from Localizations
    final locale = Localizations.localeOf(context);
    
    // Generate full day names using DateFormat
    final weekDays = List.generate(7, (index) {
      // Monday = 1, so we calculate the date for each day of the week
      // Starting from Monday (index 0)
      final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      final dayDate = monday.add(Duration(days: index));
      return DateFormat('EEEE', locale.toString()).format(dayDate);
    });
    
    const defaultMealIcons = ['🍳', '🥗', '🍲', '🥪', '🍛', '🍜', '🥘'];

    // Use selected day instead of today
    final referenceDate = selectedDay;
    final currentDayIndex = (referenceDate.weekday + 5) % 7; // Convert to Monday=0

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _fadeAnimation.value) * 20),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.getCardShadow(context),
              ),
              child: Stack(
                children: [
                  // Background decoration
                  if (Theme.of(context).brightness == Brightness.light)
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.geniePurple.withOpacity(0.2),
                              AppColors.geniePink.withOpacity(0.2),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mealPlan?.name ??
                                            context.t('weekly.plan.title'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                      Text(
                                        context.t('weeklyPlanPersonalizedMeals'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // TextButton(
                          //   onPressed: () => context.go('/planner'),
                          //   style: TextButton.styleFrom(
                          //     padding: EdgeInsets.zero,
                          //     minimumSize: Size.zero,
                          //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          //   ),
                          //   child: Row(
                          //     mainAxisSize: MainAxisSize.min,
                          //     children: [
                          //       Text(
                          //         context.t('weeklyPlanView'),
                          //         style: TextStyle(
                          //           fontSize: 12,
                          //           fontWeight: FontWeight.w600,
                          //           color: AppColors.primary,
                          //         ),
                          //       ),
                          //       const SizedBox(width: 2),
                          //       RtlChevronRight(
                          //         size: 16,
                          //         color: AppColors.primary,
                          //       ),
                          //     ],
                          //   ),
                          // ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Days preview
                      SizedBox(
                        height: 70,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(7, (index) {
                              // Calculate the actual date for this day in the week
                              final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
                              final dayDate = monday.add(Duration(days: index));
                              // Check if this day matches the selected day
                              final isSelectedDay = selectedDay.year == dayDate.year &&
                                  selectedDay.month == dayDate.month &&
                                  selectedDay.day == dayDate.day;
                              // Use selected day highlight if it's in this week, otherwise use today
                              final isToday = index == currentDayIndex;
                              final shouldHighlight = isSelectedDay || (!_isDateInCurrentWeek(selectedDay) && isToday);
                              return Container(
                                width: 70,
                                height: 70,
                                margin: RtlEdgeInsets.only(context: context, right: index < 6 ? 4 : 0),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: shouldHighlight
                                      ? AppColors.primary
                                      : Theme.of(context).colorScheme.surface.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: shouldHighlight
                                      ? Border.all(
                                          color: AppColors.primary.withOpacity(0.3),
                                          width: 1,
                                        )
                                      : Border.all(
                                          color: Theme.of(context).dividerColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      defaultMealIcons[index],
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      weekDays[index],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: shouldHighlight
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      if (mealPlan != null && mealPlan.meals.isNotEmpty) ...[

                        // Today's meals preview
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('weekly.plan.todays.meals'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              // Show meals for selected day
                              ...mealPlan.meals
                                  .where((meal) {
                                    final mealDate = meal.date;
                                    return mealDate.year == selectedDay.year &&
                                        mealDate.month == selectedDay.month &&
                                        mealDate.day == selectedDay.day;
                                  })
                                  .map((meal) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${meal.mealType == 'breakfast' ? '🍳' : meal.mealType == 'lunch' ? '🥗' : '🍲'} ${meal.recipeTitle}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              '${context.t('weekly.plan.cal')}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ],
                          ),
                        ),
                      ], // CTA Button
                        SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.genieLavender,
                                AppColors.primary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => context.go('/planner'),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.t('weeklyPlanGenerateAIMealPlan'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
