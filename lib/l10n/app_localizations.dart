import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_uz.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('af'),
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('fa'),
    Locale('fil'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('kk'),
    Locale('ko'),
    Locale('ms'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('th'),
    Locale('tr'),
    Locale('uk'),
    Locale('ur'),
    Locale('uz'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @commonHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get commonHome;

  /// No description provided for @commonRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get commonRecipes;

  /// No description provided for @commonPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get commonPlan;

  /// No description provided for @commonShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get commonShop;

  /// No description provided for @commonChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get commonChat;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @adLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading ad'**
  String get adLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get commonFavorites;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get commonViewAll;

  /// No description provided for @commonGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get commonGetStarted;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonRetry;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get commonVersion;

  /// No description provided for @commonExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get commonExit;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get commonCopied;

  /// No description provided for @exitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit App?'**
  String get exitDialogTitle;

  /// No description provided for @exitDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get exitDialogMessage;

  /// No description provided for @exitDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get exitDialogCancel;

  /// No description provided for @exitDialogExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitDialogExit;

  /// No description provided for @languageSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get languageSelectionTitle;

  /// No description provided for @languageSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get languageSelectionSubtitle;

  /// No description provided for @languageSelectionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get languageSelectionContinue;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingStep1Title.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Recipes'**
  String get onboardingStep1Title;

  /// No description provided for @onboardingStep1Description.
  ///
  /// In en, this message translates to:
  /// **'Get personalized recipes based on your ingredients, preferences, and dietary needs. Our AI creates delicious dishes just for you.'**
  String get onboardingStep1Description;

  /// No description provided for @onboardingStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Smart Meal Planning'**
  String get onboardingStep2Title;

  /// No description provided for @onboardingStep2Description.
  ///
  /// In en, this message translates to:
  /// **'Plan your week with personalized meal plans that match your health goals, budget, and cooking skill level.'**
  String get onboardingStep2Description;

  /// No description provided for @onboardingStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Intelligent Grocery Lists'**
  String get onboardingStep3Title;

  /// No description provided for @onboardingStep3Description.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate shopping lists from your meal plans. Voice-add items and get smart suggestions to save time and money.'**
  String get onboardingStep3Description;

  /// No description provided for @onboardingStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Your Personal AI Chef'**
  String get onboardingStep4Title;

  /// No description provided for @onboardingStep4Description.
  ///
  /// In en, this message translates to:
  /// **'Ask questions, get cooking tips, and receive personalized nutrition advice from your AI kitchen assistant.'**
  String get onboardingStep4Description;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'What can I cook'**
  String get homeGreeting;

  /// No description provided for @homeGreetingEnd.
  ///
  /// In en, this message translates to:
  /// **'for you today?'**
  String get homeGreetingEnd;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your magical AI kitchen assistant'**
  String get homeSubtitle;

  /// No description provided for @homeSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search recipes, ingredients...'**
  String get homeSearchPlaceholder;

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get homeQuickActions;

  /// No description provided for @homeGenerateRecipe.
  ///
  /// In en, this message translates to:
  /// **'Generate Recipe'**
  String get homeGenerateRecipe;

  /// No description provided for @homeAiCreates.
  ///
  /// In en, this message translates to:
  /// **'AI creates dishes'**
  String get homeAiCreates;

  /// No description provided for @homeMealPlanner.
  ///
  /// In en, this message translates to:
  /// **'Meal Planner'**
  String get homeMealPlanner;

  /// No description provided for @homePlanWeek.
  ///
  /// In en, this message translates to:
  /// **'Plan your week'**
  String get homePlanWeek;

  /// No description provided for @homeSmartGrocery.
  ///
  /// In en, this message translates to:
  /// **'Smart Grocery'**
  String get homeSmartGrocery;

  /// No description provided for @homeShoppingLists.
  ///
  /// In en, this message translates to:
  /// **'Shopping lists'**
  String get homeShoppingLists;

  /// No description provided for @homeAiChefChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chef Chat'**
  String get homeAiChefChat;

  /// No description provided for @homeAskQuestions.
  ///
  /// In en, this message translates to:
  /// **'Ask questions'**
  String get homeAskQuestions;

  /// No description provided for @homeFeaturedRecipes.
  ///
  /// In en, this message translates to:
  /// **'Featured Recipes'**
  String get homeFeaturedRecipes;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get authFullName;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHasAccount;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to DishGenie!'**
  String get authWelcomeBack;

  /// No description provided for @authWelcomeNew.
  ///
  /// In en, this message translates to:
  /// **'Welcome to DishGenie! Your account has been created.'**
  String get authWelcomeNew;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authInvalidCredentials;

  /// No description provided for @authAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try logging in.'**
  String get authAlreadyRegistered;

  /// No description provided for @authEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authEnterName;

  /// No description provided for @authSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get authSigningIn;

  /// No description provided for @authCreatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get authCreatingAccount;

  /// No description provided for @authMagicalAssistant.
  ///
  /// In en, this message translates to:
  /// **'Your magical kitchen assistant'**
  String get authMagicalAssistant;

  /// No description provided for @recipesTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Recipes'**
  String get recipesTitle;

  /// No description provided for @recipesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover & create'**
  String get recipesSubtitle;

  /// No description provided for @recipesBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get recipesBrowse;

  /// No description provided for @recipesAiGenerate.
  ///
  /// In en, this message translates to:
  /// **'AI Generate'**
  String get recipesAiGenerate;

  /// No description provided for @recipesQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get recipesQuick;

  /// No description provided for @recipesHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High Protein'**
  String get recipesHighProtein;

  /// No description provided for @recipesChicken.
  ///
  /// In en, this message translates to:
  /// **'Chicken'**
  String get recipesChicken;

  /// No description provided for @recipesSeafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get recipesSeafood;

  /// No description provided for @recipesEggs.
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get recipesEggs;

  /// No description provided for @recipesHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get recipesHealthy;

  /// No description provided for @recipesKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get recipesKids;

  /// No description provided for @recipesBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get recipesBudget;

  /// No description provided for @recipesGrilled.
  ///
  /// In en, this message translates to:
  /// **'Grilled'**
  String get recipesGrilled;

  /// No description provided for @recipesVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get recipesVegetarian;

  /// No description provided for @recipesVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get recipesVegan;

  /// No description provided for @recipesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No recipes found'**
  String get recipesNoResults;

  /// No description provided for @recipesTryOther.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t find any recipes matching'**
  String get recipesTryOther;

  /// No description provided for @recipesClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get recipesClearSearch;

  /// No description provided for @recipesResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Results for'**
  String get recipesResultsFor;

  /// No description provided for @recipesWhatIngredients.
  ///
  /// In en, this message translates to:
  /// **'What ingredients do you have?'**
  String get recipesWhatIngredients;

  /// No description provided for @recipesIngredientsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., chicken, garlic, tomatoes, rice...'**
  String get recipesIngredientsPlaceholder;

  /// No description provided for @recipesScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get recipesScan;

  /// No description provided for @recipesVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get recipesVoice;

  /// No description provided for @recipesStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recipesStop;

  /// No description provided for @recipesCuisine.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get recipesCuisine;

  /// No description provided for @recipesDietType.
  ///
  /// In en, this message translates to:
  /// **'Diet Type'**
  String get recipesDietType;

  /// No description provided for @recipesHealthGoal.
  ///
  /// In en, this message translates to:
  /// **'Health Goal'**
  String get recipesHealthGoal;

  /// No description provided for @recipesCookingMood.
  ///
  /// In en, this message translates to:
  /// **'Cooking Mood'**
  String get recipesCookingMood;

  /// No description provided for @recipesCookingTime.
  ///
  /// In en, this message translates to:
  /// **'Cooking Time'**
  String get recipesCookingTime;

  /// No description provided for @recipesTargetCalories.
  ///
  /// In en, this message translates to:
  /// **'Target Calories'**
  String get recipesTargetCalories;

  /// No description provided for @recipesGenerateRecipe.
  ///
  /// In en, this message translates to:
  /// **'Generate Recipe'**
  String get recipesGenerateRecipe;

  /// No description provided for @recipesCreatingRecipe.
  ///
  /// In en, this message translates to:
  /// **'Creating Your Recipe...'**
  String get recipesCreatingRecipe;

  /// No description provided for @recipesCreatingRecipeWith.
  ///
  /// In en, this message translates to:
  /// **'Creating recipes with {ingredients}...'**
  String recipesCreatingRecipeWith(String ingredients);

  /// No description provided for @recipesYourIngredients.
  ///
  /// In en, this message translates to:
  /// **'your ingredients'**
  String get recipesYourIngredients;

  /// No description provided for @recipesEnterIngredients.
  ///
  /// In en, this message translates to:
  /// **'Please enter your ingredients'**
  String get recipesEnterIngredients;

  /// No description provided for @recipesMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get recipesMin;

  /// No description provided for @recipesServings.
  ///
  /// In en, this message translates to:
  /// **'servings'**
  String get recipesServings;

  /// No description provided for @recipesTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get recipesTime;

  /// No description provided for @recipesCal.
  ///
  /// In en, this message translates to:
  /// **'Cal'**
  String get recipesCal;

  /// No description provided for @recipesGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get recipesGenerating;

  /// No description provided for @recipesNewRecipe.
  ///
  /// In en, this message translates to:
  /// **'New Recipe'**
  String get recipesNewRecipe;

  /// No description provided for @recipesWhatCraving.
  ///
  /// In en, this message translates to:
  /// **'What are you craving?'**
  String get recipesWhatCraving;

  /// No description provided for @recipesMoodsComfortFood.
  ///
  /// In en, this message translates to:
  /// **'Comfort Food'**
  String get recipesMoodsComfortFood;

  /// No description provided for @recipesMoodsLightFresh.
  ///
  /// In en, this message translates to:
  /// **'Light & Fresh'**
  String get recipesMoodsLightFresh;

  /// No description provided for @recipesMoodsHighEnergy.
  ///
  /// In en, this message translates to:
  /// **'High Energy'**
  String get recipesMoodsHighEnergy;

  /// No description provided for @recipesMoodsSweetCravings.
  ///
  /// In en, this message translates to:
  /// **'Sweet Cravings'**
  String get recipesMoodsSweetCravings;

  /// No description provided for @recipesMoodsSpicyFix.
  ///
  /// In en, this message translates to:
  /// **'Spicy Fix'**
  String get recipesMoodsSpicyFix;

  /// No description provided for @recipesMoodsQuickBite.
  ///
  /// In en, this message translates to:
  /// **'Quick Bite'**
  String get recipesMoodsQuickBite;

  /// No description provided for @recipesCuisinesPakistani.
  ///
  /// In en, this message translates to:
  /// **'Pakistani'**
  String get recipesCuisinesPakistani;

  /// No description provided for @recipesCuisinesIndian.
  ///
  /// In en, this message translates to:
  /// **'Indian'**
  String get recipesCuisinesIndian;

  /// No description provided for @recipesCuisinesItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get recipesCuisinesItalian;

  /// No description provided for @recipesCuisinesMediterranean.
  ///
  /// In en, this message translates to:
  /// **'Mediterranean'**
  String get recipesCuisinesMediterranean;

  /// No description provided for @recipesCuisinesThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get recipesCuisinesThai;

  /// No description provided for @recipesCuisinesKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get recipesCuisinesKorean;

  /// No description provided for @recipesCuisinesMiddleEastern.
  ///
  /// In en, this message translates to:
  /// **'Middle Eastern'**
  String get recipesCuisinesMiddleEastern;

  /// No description provided for @recipesCuisinesAmerican.
  ///
  /// In en, this message translates to:
  /// **'American'**
  String get recipesCuisinesAmerican;

  /// No description provided for @recipesDietsBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get recipesDietsBalanced;

  /// No description provided for @recipesDietsKeto.
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get recipesDietsKeto;

  /// No description provided for @recipesDietsVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get recipesDietsVegan;

  /// No description provided for @recipesDietsVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get recipesDietsVegetarian;

  /// No description provided for @recipesDietsHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get recipesDietsHalal;

  /// No description provided for @recipesDietsDesi.
  ///
  /// In en, this message translates to:
  /// **'Desi'**
  String get recipesDietsDesi;

  /// No description provided for @recipesGoalsWeightLoss.
  ///
  /// In en, this message translates to:
  /// **'Weight Loss'**
  String get recipesGoalsWeightLoss;

  /// No description provided for @recipesGoalsMuscle.
  ///
  /// In en, this message translates to:
  /// **'Muscle'**
  String get recipesGoalsMuscle;

  /// No description provided for @recipesGoalsMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get recipesGoalsMaintain;

  /// No description provided for @recipesGoalsEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get recipesGoalsEnergy;

  /// No description provided for @mealPlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Meal Planner'**
  String get mealPlannerTitle;

  /// No description provided for @mealPlannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalized plans for your goals'**
  String get mealPlannerSubtitle;

  /// No description provided for @mealPlannerGeneratePlan.
  ///
  /// In en, this message translates to:
  /// **'Generate Meal Plan'**
  String get mealPlannerGeneratePlan;

  /// No description provided for @mealPlannerCreatingPlan.
  ///
  /// In en, this message translates to:
  /// **'Creating Your Plan...'**
  String get mealPlannerCreatingPlan;

  /// No description provided for @mealPlannerYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get mealPlannerYourProfile;

  /// No description provided for @mealPlannerFamilySize.
  ///
  /// In en, this message translates to:
  /// **'Family Size'**
  String get mealPlannerFamilySize;

  /// No description provided for @mealPlannerDailyCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily Calories'**
  String get mealPlannerDailyCalories;

  /// No description provided for @mealPlannerPlanDuration.
  ///
  /// In en, this message translates to:
  /// **'Plan Duration'**
  String get mealPlannerPlanDuration;

  /// No description provided for @mealPlannerDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get mealPlannerDays;

  /// No description provided for @mealPlannerDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get mealPlannerDay;

  /// No description provided for @mealPlannerHealthGoal.
  ///
  /// In en, this message translates to:
  /// **'Health Goal'**
  String get mealPlannerHealthGoal;

  /// No description provided for @mealPlannerLoseWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose Weight'**
  String get mealPlannerLoseWeight;

  /// No description provided for @mealPlannerBuildMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build Muscle'**
  String get mealPlannerBuildMuscle;

  /// No description provided for @mealPlannerStayHealthy.
  ///
  /// In en, this message translates to:
  /// **'Stay Healthy'**
  String get mealPlannerStayHealthy;

  /// No description provided for @mealPlannerDietType.
  ///
  /// In en, this message translates to:
  /// **'Diet Type'**
  String get mealPlannerDietType;

  /// No description provided for @mealPlannerBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get mealPlannerBalanced;

  /// No description provided for @mealPlannerKeto.
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get mealPlannerKeto;

  /// No description provided for @mealPlannerVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get mealPlannerVegan;

  /// No description provided for @mealPlannerHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get mealPlannerHalal;

  /// No description provided for @mealPlannerHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High-Protein'**
  String get mealPlannerHighProtein;

  /// No description provided for @mealPlannerBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get mealPlannerBudget;

  /// No description provided for @mealPlannerModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get mealPlannerModerate;

  /// No description provided for @mealPlannerPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get mealPlannerPremium;

  /// No description provided for @mealPlannerSkill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get mealPlannerSkill;

  /// No description provided for @mealPlannerBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get mealPlannerBeginner;

  /// No description provided for @mealPlannerIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get mealPlannerIntermediate;

  /// No description provided for @mealPlannerAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get mealPlannerAdvanced;

  /// No description provided for @mealPlannerIntermittentFasting.
  ///
  /// In en, this message translates to:
  /// **'Intermittent Fasting'**
  String get mealPlannerIntermittentFasting;

  /// No description provided for @mealPlannerNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get mealPlannerNone;

  /// No description provided for @mealPlannerAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies / Avoid'**
  String get mealPlannerAllergies;

  /// No description provided for @mealPlannerAllergiesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., peanuts, shellfish, dairy...'**
  String get mealPlannerAllergiesPlaceholder;

  /// No description provided for @mealPlannerGroceryList.
  ///
  /// In en, this message translates to:
  /// **'Grocery List'**
  String get mealPlannerGroceryList;

  /// No description provided for @mealPlannerBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealPlannerBreakfast;

  /// No description provided for @mealPlannerLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealPlannerLunch;

  /// No description provided for @mealPlannerDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealPlannerDinner;

  /// No description provided for @mealPlannerSnacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get mealPlannerSnacks;

  /// No description provided for @mealPlannerSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get mealPlannerSwap;

  /// No description provided for @mealPlannerSwapping.
  ///
  /// In en, this message translates to:
  /// **'Swapping...'**
  String get mealPlannerSwapping;

  /// No description provided for @mealPlannerMinCalories.
  ///
  /// In en, this message translates to:
  /// **'Minimum 1000 calories required'**
  String get mealPlannerMinCalories;

  /// No description provided for @mealPlannerMaxCalories.
  ///
  /// In en, this message translates to:
  /// **'Maximum 5000 calories allowed'**
  String get mealPlannerMaxCalories;

  /// No description provided for @mealPlannerCal.
  ///
  /// In en, this message translates to:
  /// **'cal'**
  String get mealPlannerCal;

  /// No description provided for @mealPlannerDailyTotal.
  ///
  /// In en, this message translates to:
  /// **'Daily Total'**
  String get mealPlannerDailyTotal;

  /// No description provided for @mealPlannerProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get mealPlannerProtein;

  /// No description provided for @mealPlannerCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get mealPlannerCarbs;

  /// No description provided for @mealPlannerFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get mealPlannerFat;

  /// No description provided for @mealPlannerProteinShort.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get mealPlannerProteinShort;

  /// No description provided for @mealPlannerCarbsShort.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get mealPlannerCarbsShort;

  /// No description provided for @mealPlannerMealPrepTips.
  ///
  /// In en, this message translates to:
  /// **'Meal Prep Tips'**
  String get mealPlannerMealPrepTips;

  /// No description provided for @mealPlannerCreateNewPlan.
  ///
  /// In en, this message translates to:
  /// **'Create New Plan'**
  String get mealPlannerCreateNewPlan;

  /// No description provided for @mealPlannerToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get mealPlannerToday;

  /// No description provided for @groceryTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Grocery'**
  String get groceryTitle;

  /// No description provided for @grocerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered shopping'**
  String get grocerySubtitle;

  /// No description provided for @groceryQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get groceryQuickActions;

  /// No description provided for @groceryAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get groceryAddItem;

  /// No description provided for @groceryScanProduct.
  ///
  /// In en, this message translates to:
  /// **'Scan Product'**
  String get groceryScanProduct;

  /// No description provided for @groceryScanKitchen.
  ///
  /// In en, this message translates to:
  /// **'Scan Kitchen'**
  String get groceryScanKitchen;

  /// No description provided for @groceryFromPlan.
  ///
  /// In en, this message translates to:
  /// **'From Plan'**
  String get groceryFromPlan;

  /// No description provided for @groceryWeeklyList.
  ///
  /// In en, this message translates to:
  /// **'Weekly List'**
  String get groceryWeeklyList;

  /// No description provided for @groceryVoiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice Assistant'**
  String get groceryVoiceAssistant;

  /// No description provided for @groceryListeningHint.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get groceryListeningHint;

  /// No description provided for @groceryVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Say \"Add chicken, tomatoes, milk...\"'**
  String get groceryVoiceHint;

  /// No description provided for @groceryCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get groceryCategories;

  /// No description provided for @groceryProduce.
  ///
  /// In en, this message translates to:
  /// **'Produce'**
  String get groceryProduce;

  /// No description provided for @groceryProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get groceryProtein;

  /// No description provided for @groceryDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get groceryDairy;

  /// No description provided for @groceryPantry.
  ///
  /// In en, this message translates to:
  /// **'Pantry'**
  String get groceryPantry;

  /// No description provided for @groceryFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get groceryFrozen;

  /// No description provided for @groceryGrains.
  ///
  /// In en, this message translates to:
  /// **'Grains'**
  String get groceryGrains;

  /// No description provided for @groceryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get groceryOther;

  /// No description provided for @grocerySmartSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Smart Suggestions'**
  String get grocerySmartSuggestions;

  /// No description provided for @groceryLowStock.
  ///
  /// In en, this message translates to:
  /// **'You\'re running low on onions'**
  String get groceryLowStock;

  /// No description provided for @groceryRecipeNeed.
  ///
  /// In en, this message translates to:
  /// **'Add yogurt for Tuesday\'s recipe'**
  String get groceryRecipeNeed;

  /// No description provided for @groceryFrequentItem.
  ///
  /// In en, this message translates to:
  /// **'Rice used 3 times this week — restock?'**
  String get groceryFrequentItem;

  /// No description provided for @groceryExpiringItem.
  ///
  /// In en, this message translates to:
  /// **'Milk expires tomorrow — use or replace'**
  String get groceryExpiringItem;

  /// No description provided for @groceryAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get groceryAdded;

  /// No description provided for @groceryAddedStatus.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get groceryAddedStatus;

  /// No description provided for @grocerySavedLists.
  ///
  /// In en, this message translates to:
  /// **'Saved Lists'**
  String get grocerySavedLists;

  /// No description provided for @groceryCurrentList.
  ///
  /// In en, this message translates to:
  /// **'Current List'**
  String get groceryCurrentList;

  /// No description provided for @groceryViewList.
  ///
  /// In en, this message translates to:
  /// **'View List'**
  String get groceryViewList;

  /// No description provided for @groceryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get groceryTotal;

  /// No description provided for @groceryBought.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get groceryBought;

  /// No description provided for @groceryEstCost.
  ///
  /// In en, this message translates to:
  /// **'Est. Cost'**
  String get groceryEstCost;

  /// No description provided for @groceryShoppingMode.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get groceryShoppingMode;

  /// No description provided for @groceryShopMode.
  ///
  /// In en, this message translates to:
  /// **'Shop Mode'**
  String get groceryShopMode;

  /// No description provided for @groceryBudgetMode.
  ///
  /// In en, this message translates to:
  /// **'Budget Mode'**
  String get groceryBudgetMode;

  /// No description provided for @groceryBudgetPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter budget (e.g., 2000 PKR)'**
  String get groceryBudgetPlaceholder;

  /// No description provided for @groceryOn.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get groceryOn;

  /// No description provided for @groceryOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get groceryOff;

  /// No description provided for @groceryAddItemPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add item...'**
  String get groceryAddItemPlaceholder;

  /// No description provided for @groceryItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name...'**
  String get groceryItemName;

  /// No description provided for @groceryQuantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get groceryQuantity;

  /// No description provided for @groceryCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get groceryCategory;

  /// No description provided for @groceryAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get groceryAddToList;

  /// No description provided for @groceryItemAdded.
  ///
  /// In en, this message translates to:
  /// **'Item added!'**
  String get groceryItemAdded;

  /// No description provided for @groceryItemRequired.
  ///
  /// In en, this message translates to:
  /// **'Item name is required'**
  String get groceryItemRequired;

  /// No description provided for @groceryCreateMealPlanFirst.
  ///
  /// In en, this message translates to:
  /// **'Please create a meal plan first'**
  String get groceryCreateMealPlanFirst;

  /// No description provided for @groceryItems.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get groceryItems;

  /// No description provided for @groceryResetList.
  ///
  /// In en, this message translates to:
  /// **'Reset List'**
  String get groceryResetList;

  /// No description provided for @groceryResetListConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all items from your grocery list? This action cannot be undone.'**
  String get groceryResetListConfirm;

  /// No description provided for @groceryListCleared.
  ///
  /// In en, this message translates to:
  /// **'Grocery list cleared'**
  String get groceryListCleared;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @groceryNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No Items Yet'**
  String get groceryNoItemsYet;

  /// No description provided for @groceryNoItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Add items or generate from meal plan'**
  String get groceryNoItemsHint;

  /// No description provided for @groceryGenerateDemoList.
  ///
  /// In en, this message translates to:
  /// **'Generate Demo List'**
  String get groceryGenerateDemoList;

  /// No description provided for @groceryEstimatedTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated Total'**
  String get groceryEstimatedTotal;

  /// No description provided for @grocerySearchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items...'**
  String get grocerySearchItems;

  /// No description provided for @groceryYourItems.
  ///
  /// In en, this message translates to:
  /// **'Your Items'**
  String get groceryYourItems;

  /// No description provided for @grocerySearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get grocerySearchResults;

  /// No description provided for @groceryItemsIn.
  ///
  /// In en, this message translates to:
  /// **'Items in'**
  String get groceryItemsIn;

  /// No description provided for @groceryNoItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found for'**
  String get groceryNoItemsFound;

  /// No description provided for @groceryAddAsNewItem.
  ///
  /// In en, this message translates to:
  /// **'Add as new item'**
  String get groceryAddAsNewItem;

  /// No description provided for @groceryQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick Add'**
  String get groceryQuickAdd;

  /// No description provided for @groceryAddToCategory.
  ///
  /// In en, this message translates to:
  /// **'Add items to this category'**
  String get groceryAddToCategory;

  /// No description provided for @groceryListShared.
  ///
  /// In en, this message translates to:
  /// **'List shared!'**
  String get groceryListShared;

  /// No description provided for @groceryListCopied.
  ///
  /// In en, this message translates to:
  /// **'List copied to clipboard!'**
  String get groceryListCopied;

  /// No description provided for @groceryListSaved.
  ///
  /// In en, this message translates to:
  /// **'List saved!'**
  String get groceryListSaved;

  /// No description provided for @groceryNoItemsToShare.
  ///
  /// In en, this message translates to:
  /// **'No items to share'**
  String get groceryNoItemsToShare;

  /// No description provided for @groceryNoItemsToSave.
  ///
  /// In en, this message translates to:
  /// **'No items to save'**
  String get groceryNoItemsToSave;

  /// No description provided for @groceryCreatingSmartList.
  ///
  /// In en, this message translates to:
  /// **'Creating smart list...'**
  String get groceryCreatingSmartList;

  /// No description provided for @groceryUpdatingList.
  ///
  /// In en, this message translates to:
  /// **'Updating list...'**
  String get groceryUpdatingList;

  /// No description provided for @groceryHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get groceryHome;

  /// No description provided for @groceryList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get groceryList;

  /// No description provided for @groceryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get groceryAdd;

  /// No description provided for @groceryMyGroceryList.
  ///
  /// In en, this message translates to:
  /// **'My Grocery List'**
  String get groceryMyGroceryList;

  /// No description provided for @grocerySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get grocerySaved;

  /// No description provided for @groceryAddItemHint.
  ///
  /// In en, this message translates to:
  /// **'Add item...'**
  String get groceryAddItemHint;

  /// No description provided for @savedListListNotFound.
  ///
  /// In en, this message translates to:
  /// **'List not found'**
  String get savedListListNotFound;

  /// No description provided for @savedListListNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'This grocery list seems to have disappeared!'**
  String get savedListListNotFoundHint;

  /// No description provided for @savedListGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get savedListGoBack;

  /// No description provided for @savedListAddToCurrentList.
  ///
  /// In en, this message translates to:
  /// **'Add to Current List'**
  String get savedListAddToCurrentList;

  /// No description provided for @savedListRegenerateWithAI.
  ///
  /// In en, this message translates to:
  /// **'Regenerate with AI'**
  String get savedListRegenerateWithAI;

  /// No description provided for @savedListDeleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get savedListDeleteList;

  /// No description provided for @savedListItemsAdded.
  ///
  /// In en, this message translates to:
  /// **'items added to current list!'**
  String get savedListItemsAdded;

  /// No description provided for @savedListFailedToAdd.
  ///
  /// In en, this message translates to:
  /// **'Failed to add items'**
  String get savedListFailedToAdd;

  /// No description provided for @savedListOptimizedWithAI.
  ///
  /// In en, this message translates to:
  /// **'List optimized with AI suggestions!'**
  String get savedListOptimizedWithAI;

  /// No description provided for @savedListFailedToRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Failed to regenerate'**
  String get savedListFailedToRegenerate;

  /// No description provided for @savedListDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get savedListDeleteConfirm;

  /// No description provided for @savedListCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get savedListCannotUndo;

  /// No description provided for @savedListDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get savedListDeleting;

  /// No description provided for @savedListAddItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get savedListAddItemTitle;

  /// No description provided for @savedListItemNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get savedListItemNamePlaceholder;

  /// No description provided for @savedListQuantityPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Quantity (e.g., 2 kg)'**
  String get savedListQuantityPlaceholder;

  /// No description provided for @savedListCategoryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Category (e.g., Dairy)'**
  String get savedListCategoryPlaceholder;

  /// No description provided for @savedListEnterItemName.
  ///
  /// In en, this message translates to:
  /// **'Please enter item name'**
  String get savedListEnterItemName;

  /// No description provided for @savedListNutritionSummary.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Summary'**
  String get savedListNutritionSummary;

  /// No description provided for @savedListTotalProtein.
  ///
  /// In en, this message translates to:
  /// **'Total Protein'**
  String get savedListTotalProtein;

  /// No description provided for @savedListEstCalories.
  ///
  /// In en, this message translates to:
  /// **'Est. Calories'**
  String get savedListEstCalories;

  /// No description provided for @savedListAiOptimizing.
  ///
  /// In en, this message translates to:
  /// **'AI is optimizing your list...'**
  String get savedListAiOptimizing;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'DishGenie Chat'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI cooking assistant'**
  String get chatSubtitle;

  /// No description provided for @chatGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m DishGenie!'**
  String get chatGreeting;

  /// No description provided for @chatGreetingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about cooking, recipes, nutrition, or meal planning.'**
  String get chatGreetingSubtitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything...'**
  String get chatPlaceholder;

  /// No description provided for @chatListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get chatListening;

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chatThinking;

  /// No description provided for @chatSuggestion1.
  ///
  /// In en, this message translates to:
  /// **'What can I make with chicken and rice?'**
  String get chatSuggestion1;

  /// No description provided for @chatSuggestion2.
  ///
  /// In en, this message translates to:
  /// **'Give me a healthy breakfast idea'**
  String get chatSuggestion2;

  /// No description provided for @chatSuggestion3.
  ///
  /// In en, this message translates to:
  /// **'How do I substitute eggs in baking?'**
  String get chatSuggestion3;

  /// No description provided for @chatSuggestion4.
  ///
  /// In en, this message translates to:
  /// **'What\'s a quick 15-minute dinner?'**
  String get chatSuggestion4;

  /// No description provided for @chatNewChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get chatNewChat;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// No description provided for @chatMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get chatMessageCopied;

  /// No description provided for @chatEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEdit;

  /// No description provided for @chatHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get chatHistoryTitle;

  /// No description provided for @chatHistoryConversation.
  ///
  /// In en, this message translates to:
  /// **'conversation'**
  String get chatHistoryConversation;

  /// No description provided for @chatHistoryConversations.
  ///
  /// In en, this message translates to:
  /// **'conversations'**
  String get chatHistoryConversations;

  /// No description provided for @chatHistorySearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search chats...'**
  String get chatHistorySearchPlaceholder;

  /// No description provided for @chatHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved chats yet'**
  String get chatHistoryEmpty;

  /// No description provided for @chatHistoryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your conversations will appear here automatically'**
  String get chatHistoryEmptyHint;

  /// No description provided for @chatHistoryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get chatHistoryNoResults;

  /// No description provided for @chatHistoryTryDifferent.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get chatHistoryTryDifferent;

  /// No description provided for @chatHistoryStartChatting.
  ///
  /// In en, this message translates to:
  /// **'Start Chatting'**
  String get chatHistoryStartChatting;

  /// No description provided for @chatHistoryToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatHistoryToday;

  /// No description provided for @chatHistoryYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatHistoryYesterday;

  /// No description provided for @chatHistoryDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'days ago'**
  String get chatHistoryDaysAgo;

  /// No description provided for @chatHistoryMessages.
  ///
  /// In en, this message translates to:
  /// **'messages'**
  String get chatHistoryMessages;

  /// No description provided for @chatHistoryNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get chatHistoryNoMessages;

  /// No description provided for @chatHistoryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get chatHistoryOpen;

  /// No description provided for @chatHistoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted!'**
  String get chatHistoryDeleted;

  /// No description provided for @chatHistoryRenamed.
  ///
  /// In en, this message translates to:
  /// **'Chat renamed!'**
  String get chatHistoryRenamed;

  /// No description provided for @chatHistoryAllCleared.
  ///
  /// In en, this message translates to:
  /// **'All chats cleared!'**
  String get chatHistoryAllCleared;

  /// No description provided for @chatHistoryClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get chatHistoryClearAll;

  /// No description provided for @chatHistoryDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get chatHistoryDeleteConfirmTitle;

  /// No description provided for @chatHistoryDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. This will permanently delete the conversation.'**
  String get chatHistoryDeleteConfirmMessage;

  /// No description provided for @chatHistoryClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all chats?'**
  String get chatHistoryClearAllTitle;

  /// No description provided for @chatHistoryClearAllMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your saved conversations. This action cannot be undone.'**
  String get chatHistoryClearAllMessage;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'My Collection'**
  String get favoritesTitle;

  /// No description provided for @favoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your saved content'**
  String get favoritesSubtitle;

  /// No description provided for @favoritesNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No Favorites Yet'**
  String get favoritesNoFavorites;

  /// No description provided for @favoritesNoFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on recipes you love!'**
  String get favoritesNoFavoritesHint;

  /// No description provided for @favoritesNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No Saved Recipes Yet'**
  String get favoritesNoSaved;

  /// No description provided for @favoritesNoSavedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark icon to save recipes for later!'**
  String get favoritesNoSavedHint;

  /// No description provided for @favoritesNoMealPlans.
  ///
  /// In en, this message translates to:
  /// **'No Saved Meal Plans'**
  String get favoritesNoMealPlans;

  /// No description provided for @favoritesNoMealPlansHint.
  ///
  /// In en, this message translates to:
  /// **'Create a meal plan to see it here!'**
  String get favoritesNoMealPlansHint;

  /// No description provided for @favoritesNoGrocery.
  ///
  /// In en, this message translates to:
  /// **'No Grocery List'**
  String get favoritesNoGrocery;

  /// No description provided for @favoritesNoGroceryHint.
  ///
  /// In en, this message translates to:
  /// **'Add items to your grocery list to see them here!'**
  String get favoritesNoGroceryHint;

  /// No description provided for @favoritesBrowseRecipes.
  ///
  /// In en, this message translates to:
  /// **'Browse Recipes'**
  String get favoritesBrowseRecipes;

  /// No description provided for @favoritesCreateMealPlan.
  ///
  /// In en, this message translates to:
  /// **'Create Meal Plan'**
  String get favoritesCreateMealPlan;

  /// No description provided for @favoritesGoToGrocery.
  ///
  /// In en, this message translates to:
  /// **'Go to Grocery'**
  String get favoritesGoToGrocery;

  /// No description provided for @favoritesPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get favoritesPlans;

  /// No description provided for @favoritesCalPerDay.
  ///
  /// In en, this message translates to:
  /// **'cal/day'**
  String get favoritesCalPerDay;

  /// No description provided for @favoritesViewPlan.
  ///
  /// In en, this message translates to:
  /// **'View Plan'**
  String get favoritesViewPlan;

  /// No description provided for @favoritesCheckedItems.
  ///
  /// In en, this message translates to:
  /// **'items checked'**
  String get favoritesCheckedItems;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send us your thoughts'**
  String get settingsFeedbackSubtitle;

  /// No description provided for @settingsRateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get settingsRateUs;

  /// No description provided for @settingsRateUsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Love the app? Rate us!'**
  String get settingsRateUsSubtitle;

  /// No description provided for @settingsShareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get settingsShareApp;

  /// No description provided for @settingsShareAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell your friends'**
  String get settingsShareAppSubtitle;

  /// No description provided for @settingsHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help / Support'**
  String get settingsHelpSupport;

  /// No description provided for @settingsHelpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FAQs & contact us'**
  String get settingsHelpSupportSubtitle;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get settingsTermsConditions;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsClearAllData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get settingsClearAllData;

  /// No description provided for @settingsClearDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset app to fresh state'**
  String get settingsClearDataSubtitle;

  /// No description provided for @settingsClearDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data?'**
  String get settingsClearDataConfirm;

  /// No description provided for @settingsClearDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your saved data including:'**
  String get settingsClearDataWarning;

  /// No description provided for @settingsSavedRecipes.
  ///
  /// In en, this message translates to:
  /// **'Saved recipes and favorites'**
  String get settingsSavedRecipes;

  /// No description provided for @settingsMealPlans.
  ///
  /// In en, this message translates to:
  /// **'Meal plans'**
  String get settingsMealPlans;

  /// No description provided for @settingsGroceryLists.
  ///
  /// In en, this message translates to:
  /// **'Grocery lists'**
  String get settingsGroceryLists;

  /// No description provided for @settingsChatHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get settingsChatHistory;

  /// No description provided for @settingsPreferencesSettings.
  ///
  /// In en, this message translates to:
  /// **'Preferences and settings'**
  String get settingsPreferencesSettings;

  /// No description provided for @settingsCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get settingsCannotUndo;

  /// No description provided for @settingsDataCleared.
  ///
  /// In en, this message translates to:
  /// **'All app data has been reset.'**
  String get settingsDataCleared;

  /// No description provided for @settingsSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get settingsSendFeedback;

  /// No description provided for @settingsYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get settingsYourName;

  /// No description provided for @settingsYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message...'**
  String get settingsYourMessage;

  /// No description provided for @settingsFeedbackSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback.'**
  String get settingsFeedbackSent;

  /// No description provided for @settingsNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get settingsNameRequired;

  /// No description provided for @settingsMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Message is required'**
  String get settingsMessageRequired;

  /// No description provided for @settingsFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get settingsFaqTitle;

  /// No description provided for @settingsFaq1Q.
  ///
  /// In en, this message translates to:
  /// **'How do I generate recipes?'**
  String get settingsFaq1Q;

  /// No description provided for @settingsFaq1A.
  ///
  /// In en, this message translates to:
  /// **'Tap \'Generate Recipe\' from the home screen or use the search bar to describe what you want to cook.'**
  String get settingsFaq1A;

  /// No description provided for @settingsFaq2Q.
  ///
  /// In en, this message translates to:
  /// **'Is my data secure?'**
  String get settingsFaq2Q;

  /// No description provided for @settingsFaq2A.
  ///
  /// In en, this message translates to:
  /// **'Yes, all your data is encrypted and stored securely. We never share your personal information.'**
  String get settingsFaq2A;

  /// No description provided for @settingsFaq3Q.
  ///
  /// In en, this message translates to:
  /// **'Can I use the app offline?'**
  String get settingsFaq3Q;

  /// No description provided for @settingsFaq3A.
  ///
  /// In en, this message translates to:
  /// **'Basic features work offline, but AI generation requires an internet connection.'**
  String get settingsFaq3A;

  /// No description provided for @settingsFaq4Q.
  ///
  /// In en, this message translates to:
  /// **'How do I save my favorite recipes?'**
  String get settingsFaq4Q;

  /// No description provided for @settingsFaq4A.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any recipe to save it to your favorites for quick access later.'**
  String get settingsFaq4A;

  /// No description provided for @settingsContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get settingsContactUs;

  /// No description provided for @settingsViewPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'View Privacy Policy'**
  String get settingsViewPrivacyPolicy;

  /// No description provided for @settingsViewTerms.
  ///
  /// In en, this message translates to:
  /// **'View Terms & Conditions'**
  String get settingsViewTerms;

  /// No description provided for @settingsViewOnWebsite.
  ///
  /// In en, this message translates to:
  /// **'View our complete'**
  String get settingsViewOnWebsite;

  /// No description provided for @settingsOnWebsite.
  ///
  /// In en, this message translates to:
  /// **'on our website.'**
  String get settingsOnWebsite;

  /// No description provided for @settingsRatingThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your interest! Rating available on mobile devices.'**
  String get settingsRatingThanks;

  /// No description provided for @settingsLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied!'**
  String get settingsLinkCopied;

  /// No description provided for @settingsShareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Share link copied to clipboard'**
  String get settingsShareLinkCopied;

  /// No description provided for @scannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Ingredient Scanner'**
  String get scannerTitle;

  /// No description provided for @scannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your ingredients'**
  String get scannerSubtitle;

  /// No description provided for @scannerTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get scannerTakePhoto;

  /// No description provided for @scannerAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your ingredients...'**
  String get scannerAnalyzing;

  /// No description provided for @scannerDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected Ingredients'**
  String get scannerDetected;

  /// No description provided for @scannerAddAll.
  ///
  /// In en, this message translates to:
  /// **'Add All to Recipe'**
  String get scannerAddAll;

  /// No description provided for @scannerUseIngredients.
  ///
  /// In en, this message translates to:
  /// **'Use Ingredients'**
  String get scannerUseIngredients;

  /// No description provided for @scannerNoIngredients.
  ///
  /// In en, this message translates to:
  /// **'No ingredients detected. Try again with a clearer photo.'**
  String get scannerNoIngredients;

  /// No description provided for @scannerAiIngredientScanner.
  ///
  /// In en, this message translates to:
  /// **'AI Ingredient Scanner'**
  String get scannerAiIngredientScanner;

  /// No description provided for @scannerTakePhotoDescription.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of your ingredients and I\'ll suggest delicious recipes!'**
  String get scannerTakePhotoDescription;

  /// No description provided for @scannerOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Open Camera'**
  String get scannerOpenCamera;

  /// No description provided for @scannerUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get scannerUploadPhoto;

  /// No description provided for @scannerRecipePreferences.
  ///
  /// In en, this message translates to:
  /// **'Recipe Preferences'**
  String get scannerRecipePreferences;

  /// No description provided for @scannerDietType.
  ///
  /// In en, this message translates to:
  /// **'Diet Type'**
  String get scannerDietType;

  /// No description provided for @scannerCookingTime.
  ///
  /// In en, this message translates to:
  /// **'Cooking Time'**
  String scannerCookingTime(String time);

  /// No description provided for @scannerTargetCalories.
  ///
  /// In en, this message translates to:
  /// **'Target Calories'**
  String scannerTargetCalories(String calories);

  /// No description provided for @scannerViewRecipeSuggestions.
  ///
  /// In en, this message translates to:
  /// **'View {count} Recipe Suggestions'**
  String scannerViewRecipeSuggestions(String count);

  /// No description provided for @scannerGenerateRecipes.
  ///
  /// In en, this message translates to:
  /// **'Generate Recipes'**
  String get scannerGenerateRecipes;

  /// No description provided for @scannerNoRecipesGenerated.
  ///
  /// In en, this message translates to:
  /// **'No recipes generated yet'**
  String get scannerNoRecipesGenerated;

  /// No description provided for @scannerViewFullRecipe.
  ///
  /// In en, this message translates to:
  /// **'View Full Recipe'**
  String get scannerViewFullRecipe;

  /// No description provided for @scannerNutritionPerServing.
  ///
  /// In en, this message translates to:
  /// **'Nutrition per Serving'**
  String get scannerNutritionPerServing;

  /// No description provided for @scannerCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get scannerCalories;

  /// No description provided for @scannerFats.
  ///
  /// In en, this message translates to:
  /// **'Fats'**
  String get scannerFats;

  /// No description provided for @scannerRecipeSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Recipe Suggestions'**
  String get scannerRecipeSuggestions;

  /// No description provided for @scannerRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get scannerRecipe;

  /// No description provided for @scannerNoRecipeSelected.
  ///
  /// In en, this message translates to:
  /// **'No recipe selected'**
  String get scannerNoRecipeSelected;

  /// No description provided for @scannerErrorPickingImage.
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String scannerErrorPickingImage(String error, Object erreur, Object fout);

  /// No description provided for @scannerErrorCapturingImage.
  ///
  /// In en, this message translates to:
  /// **'Error capturing image: {error}'**
  String scannerErrorCapturingImage(String error, Object erreur, Object fout);

  /// No description provided for @scannerErrorAnalyzingImage.
  ///
  /// In en, this message translates to:
  /// **'Error analyzing image: {error}'**
  String scannerErrorAnalyzingImage(String error, Object erreur, Object fout);

  /// No description provided for @scannerNoIngredientsDetected.
  ///
  /// In en, this message translates to:
  /// **'No ingredients detected. Please try another image.'**
  String get scannerNoIngredientsDetected;

  /// No description provided for @favoritesCreatedRecently.
  ///
  /// In en, this message translates to:
  /// **'Created recently'**
  String get favoritesCreatedRecently;

  /// No description provided for @recipeDetailPrepTime.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get recipeDetailPrepTime;

  /// No description provided for @recipeDetailCookTime.
  ///
  /// In en, this message translates to:
  /// **'Cook'**
  String get recipeDetailCookTime;

  /// No description provided for @recipeDetailServings.
  ///
  /// In en, this message translates to:
  /// **'servings'**
  String get recipeDetailServings;

  /// No description provided for @recipeDetailCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get recipeDetailCalories;

  /// No description provided for @recipeDetailCal.
  ///
  /// In en, this message translates to:
  /// **'cal'**
  String get recipeDetailCal;

  /// No description provided for @recipeDetailMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get recipeDetailMin;

  /// No description provided for @recipeDetailIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get recipeDetailIngredients;

  /// No description provided for @recipeDetailInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get recipeDetailInstructions;

  /// No description provided for @recipeDetailNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get recipeDetailNutrition;

  /// No description provided for @recipeDetailNutritionPerServing.
  ///
  /// In en, this message translates to:
  /// **'Nutrition per serving'**
  String get recipeDetailNutritionPerServing;

  /// No description provided for @recipeDetailProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get recipeDetailProtein;

  /// No description provided for @recipeDetailCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get recipeDetailCarbs;

  /// No description provided for @recipeDetailFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get recipeDetailFat;

  /// No description provided for @recipeDetailFiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber'**
  String get recipeDetailFiber;

  /// No description provided for @recipeDetailTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get recipeDetailTips;

  /// No description provided for @recipeDetailChefsTip.
  ///
  /// In en, this message translates to:
  /// **'Chef\'s Tip'**
  String get recipeDetailChefsTip;

  /// No description provided for @recipeDetailAddToGrocery.
  ///
  /// In en, this message translates to:
  /// **'Add to Grocery'**
  String get recipeDetailAddToGrocery;

  /// No description provided for @recipeDetailStartCooking.
  ///
  /// In en, this message translates to:
  /// **'Start Cooking'**
  String get recipeDetailStartCooking;

  /// No description provided for @recipeDetailStartCookingAI.
  ///
  /// In en, this message translates to:
  /// **'Start Cooking with AI Chef'**
  String get recipeDetailStartCookingAI;

  /// No description provided for @recipeDetailRecipeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Recipe Not Found'**
  String get recipeDetailRecipeNotFound;

  /// No description provided for @recipeDetailGenerateCustom.
  ///
  /// In en, this message translates to:
  /// **'Let me generate a custom recipe for you!'**
  String get recipeDetailGenerateCustom;

  /// No description provided for @recipeDetailGenieHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help? Ask me for tips, substitutions, or step-by-step guidance!'**
  String get recipeDetailGenieHelp;

  /// No description provided for @tagsHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High Protein'**
  String get tagsHighProtein;

  /// No description provided for @tagsDesi.
  ///
  /// In en, this message translates to:
  /// **'Desi'**
  String get tagsDesi;

  /// No description provided for @tagsComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get tagsComfort;

  /// No description provided for @tagsCreamy.
  ///
  /// In en, this message translates to:
  /// **'Creamy'**
  String get tagsCreamy;

  /// No description provided for @tagsVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get tagsVegetarian;

  /// No description provided for @tagsBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get tagsBudget;

  /// No description provided for @tagsHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get tagsHealthy;

  /// No description provided for @tagsBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get tagsBreakfast;

  /// No description provided for @tagsLowCarb.
  ///
  /// In en, this message translates to:
  /// **'Low Carb'**
  String get tagsLowCarb;

  /// No description provided for @tagsKeto.
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get tagsKeto;

  /// No description provided for @tagsQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get tagsQuick;

  /// No description provided for @tagsOmega3.
  ///
  /// In en, this message translates to:
  /// **'Omega-3'**
  String get tagsOmega3;

  /// No description provided for @tagsKidsFriendly.
  ///
  /// In en, this message translates to:
  /// **'Kids Friendly'**
  String get tagsKidsFriendly;

  /// No description provided for @tagsDessert.
  ///
  /// In en, this message translates to:
  /// **'Dessert'**
  String get tagsDessert;

  /// No description provided for @tagsSweet.
  ///
  /// In en, this message translates to:
  /// **'Sweet'**
  String get tagsSweet;

  /// No description provided for @tagsIndulgent.
  ///
  /// In en, this message translates to:
  /// **'Indulgent'**
  String get tagsIndulgent;

  /// No description provided for @tagsMiddleEastern.
  ///
  /// In en, this message translates to:
  /// **'Middle Eastern'**
  String get tagsMiddleEastern;

  /// No description provided for @tagsItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get tagsItalian;

  /// No description provided for @tagsAsian.
  ///
  /// In en, this message translates to:
  /// **'Asian'**
  String get tagsAsian;

  /// No description provided for @tagsColorful.
  ///
  /// In en, this message translates to:
  /// **'Colorful'**
  String get tagsColorful;

  /// No description provided for @tagsSpicy.
  ///
  /// In en, this message translates to:
  /// **'Spicy'**
  String get tagsSpicy;

  /// No description provided for @tagsVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get tagsVegan;

  /// No description provided for @weeklyPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Week at a Glance'**
  String get weeklyPlanTitle;

  /// No description provided for @weeklyPlanNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No meal plans yet'**
  String get weeklyPlanNoPlans;

  /// No description provided for @weeklyPlanCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Create a meal plan to see your week here!'**
  String get weeklyPlanCreatePlan;

  /// No description provided for @weeklyPlanStartPlanning.
  ///
  /// In en, this message translates to:
  /// **'Start Planning'**
  String get weeklyPlanStartPlanning;

  /// No description provided for @weeklyPlanTodaysMeals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Meals'**
  String get weeklyPlanTodaysMeals;

  /// No description provided for @weeklyPlanMeals.
  ///
  /// In en, this message translates to:
  /// **'meals'**
  String get weeklyPlanMeals;

  /// No description provided for @weeklyPlanCal.
  ///
  /// In en, this message translates to:
  /// **'cal'**
  String get weeklyPlanCal;

  /// No description provided for @weeklyPlanCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get weeklyPlanCreated;

  /// No description provided for @weeklyPlanMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weeklyPlanMon;

  /// No description provided for @weeklyPlanTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weeklyPlanTue;

  /// No description provided for @weeklyPlanWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weeklyPlanWed;

  /// No description provided for @weeklyPlanThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weeklyPlanThu;

  /// No description provided for @weeklyPlanFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weeklyPlanFri;

  /// No description provided for @weeklyPlanSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weeklyPlanSat;

  /// No description provided for @weeklyPlanSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weeklyPlanSun;

  /// No description provided for @weeklyPlanPersonalizedMeals.
  ///
  /// In en, this message translates to:
  /// **'Personalized meals for you'**
  String get weeklyPlanPersonalizedMeals;

  /// No description provided for @weeklyPlanView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get weeklyPlanView;

  /// No description provided for @weeklyPlanGenerateAIMealPlan.
  ///
  /// In en, this message translates to:
  /// **'Generate AI Meal Plan'**
  String get weeklyPlanGenerateAIMealPlan;

  /// No description provided for @savedMealPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Meal Plan'**
  String get savedMealPlanTitle;

  /// No description provided for @savedMealPlanContinuePlan.
  ///
  /// In en, this message translates to:
  /// **'Continue Plan'**
  String get savedMealPlanContinuePlan;

  /// No description provided for @splashAppName.
  ///
  /// In en, this message translates to:
  /// **'DishGenie'**
  String get splashAppName;

  /// No description provided for @splashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI Kitchen Companion'**
  String get splashSubtitle;

  /// No description provided for @commonErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonErrorMessage(
    String error,
    Object erreur,
    Object erro,
    Object errore,
    Object fout,
    Object hata,
    Object kesalahan,
  );

  /// No description provided for @commonCouldNotOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String commonCouldNotOpenUrl(String url);

  /// No description provided for @noInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet'**
  String get noInternetTitle;

  /// No description provided for @noInternetMessage.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get noInternetMessage;

  /// No description provided for @permissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permissionDeniedTitle;

  /// No description provided for @permissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone access is needed for this feature. Please enable it in system settings.'**
  String get permissionDeniedMessage;

  /// No description provided for @permissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permissionOpenSettings;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsChooseTheme.
  ///
  /// In en, this message translates to:
  /// **'Choose Theme'**
  String get settingsChooseTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @landingAppName.
  ///
  /// In en, this message translates to:
  /// **'DishGenie AI'**
  String get landingAppName;

  /// No description provided for @landingDownloadForIOS.
  ///
  /// In en, this message translates to:
  /// **'Download for iOS'**
  String get landingDownloadForIOS;

  /// No description provided for @landingGetOnAndroid.
  ///
  /// In en, this message translates to:
  /// **'Get on Android'**
  String get landingGetOnAndroid;

  /// No description provided for @landingFreeToDownload.
  ///
  /// In en, this message translates to:
  /// **'Free to download • No credit card required'**
  String get landingFreeToDownload;

  /// No description provided for @premiumSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get premiumSuccess;

  /// No description provided for @premiumWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to DishGenie Pro! Enjoy all premium features.'**
  String get premiumWelcomeMessage;

  /// No description provided for @premiumPurchasesRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored successfully'**
  String get premiumPurchasesRestored;

  /// No description provided for @premiumSubscriptionLoading.
  ///
  /// In en, this message translates to:
  /// **'Subscription plans are loading. Please try again in a moment.'**
  String get premiumSubscriptionLoading;

  /// No description provided for @premiumYouArePro.
  ///
  /// In en, this message translates to:
  /// **'You are Pro!'**
  String get premiumYouArePro;

  /// No description provided for @premiumUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock DishGenie Pro'**
  String get premiumUnlockTitle;

  /// No description provided for @premiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Personal AI Cooking Assistant'**
  String get premiumSubtitle;

  /// No description provided for @premiumFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get premiumFeature;

  /// No description provided for @premiumPro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get premiumPro;

  /// No description provided for @premiumBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get premiumBasic;

  /// No description provided for @premiumFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full Premium Access'**
  String get premiumFullAccess;

  /// No description provided for @premiumSubscribeNow.
  ///
  /// In en, this message translates to:
  /// **'Subscribe Now'**
  String get premiumSubscribeNow;

  /// No description provided for @premiumRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get premiumRestorePurchases;

  /// No description provided for @premiumPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get premiumPrivacyPolicy;

  /// No description provided for @premiumTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get premiumTermsOfUse;

  /// No description provided for @premiumFailedToInitiatePurchase.
  ///
  /// In en, this message translates to:
  /// **'Failed to initiate purchase'**
  String get premiumFailedToInitiatePurchase;

  /// No description provided for @premiumError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String premiumError(
    String error,
    Object erreur,
    Object errore,
    Object fout,
    Object hata,
    Object kesalahan,
  );

  /// No description provided for @premiumFeatureUnlimitedRecipes.
  ///
  /// In en, this message translates to:
  /// **'Unlimited AI Recipes'**
  String get premiumFeatureUnlimitedRecipes;

  /// No description provided for @premiumFeatureNutritionAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Full Nutrition Analytics'**
  String get premiumFeatureNutritionAnalytics;

  /// No description provided for @premiumFeatureVoiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice Cooking Assistant'**
  String get premiumFeatureVoiceAssistant;

  /// No description provided for @premiumFeatureImageAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Recipe Image Analysis'**
  String get premiumFeatureImageAnalysis;

  /// No description provided for @premiumFeatureGroceryList.
  ///
  /// In en, this message translates to:
  /// **'Smart Grocery List'**
  String get premiumFeatureGroceryList;

  /// No description provided for @premiumFeatureAdFree.
  ///
  /// In en, this message translates to:
  /// **'Ad Free Experience'**
  String get premiumFeatureAdFree;

  /// No description provided for @scannerMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get scannerMin;

  /// No description provided for @scannerKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get scannerKcal;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DishGenie'**
  String get appTitle;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find recipes and ingredients'**
  String get searchSubtitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search recipes, ingredients.'**
  String get searchHint;

  /// No description provided for @searchTrySearching.
  ///
  /// In en, this message translates to:
  /// **'Try searching for:'**
  String get searchTrySearching;

  /// No description provided for @searchSuggestionPasta.
  ///
  /// In en, this message translates to:
  /// **'Pasta'**
  String get searchSuggestionPasta;

  /// No description provided for @searchSuggestionHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get searchSuggestionHealthy;

  /// No description provided for @searchSuggestionQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get searchSuggestionQuick;

  /// No description provided for @searchSuggestionChicken.
  ///
  /// In en, this message translates to:
  /// **'Chicken'**
  String get searchSuggestionChicken;

  /// No description provided for @searchSuggestionDessert.
  ///
  /// In en, this message translates to:
  /// **'Dessert'**
  String get searchSuggestionDessert;

  /// No description provided for @scannerEnterIngredientName.
  ///
  /// In en, this message translates to:
  /// **'Please enter an ingredient name'**
  String get scannerEnterIngredientName;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @chatErrorNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Chat API is not configured. Please contact support or check your app settings.'**
  String get chatErrorNotConfigured;

  /// No description provided for @chatErrorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Rate limit exceeded. Please try again later.'**
  String get chatErrorRateLimit;

  /// No description provided for @chatErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I couldn\'t process your request. Please try again.'**
  String get chatErrorGeneric;

  /// No description provided for @premiumPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get premiumPurchaseFailed;

  /// No description provided for @premiumUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get premiumUpgrade;

  /// No description provided for @scannerLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You have reached your limit of {limit} free recipe generations. Upgrade to premium for unlimited access!'**
  String scannerLimitReached(String limit);

  /// No description provided for @scannerAiDisabled.
  ///
  /// In en, this message translates to:
  /// **'AI recipe generation is currently disabled. Upgrade to premium for unlimited access!'**
  String get scannerAiDisabled;

  /// No description provided for @scannerAddIngredient.
  ///
  /// In en, this message translates to:
  /// **'Add Ingredient'**
  String get scannerAddIngredient;

  /// No description provided for @scannerIngredientName.
  ///
  /// In en, this message translates to:
  /// **'Ingredient Name'**
  String get scannerIngredientName;

  /// No description provided for @scannerIngredientNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Tomatoes'**
  String get scannerIngredientNameHint;

  /// No description provided for @scannerQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get scannerQuantity;

  /// No description provided for @scannerQuantityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 2 medium'**
  String get scannerQuantityHint;

  /// No description provided for @scannerCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get scannerCategory;

  /// No description provided for @scannerCaptureOrUpload.
  ///
  /// In en, this message translates to:
  /// **'Capture or upload a photo of your ingredients'**
  String get scannerCaptureOrUpload;

  /// No description provided for @scannerDietBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get scannerDietBalanced;

  /// No description provided for @scannerDietHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High Protein'**
  String get scannerDietHighProtein;

  /// No description provided for @scannerDietLowCarb.
  ///
  /// In en, this message translates to:
  /// **'Low Carb'**
  String get scannerDietLowCarb;

  /// No description provided for @scannerDietKeto.
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get scannerDietKeto;

  /// No description provided for @scannerDietVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get scannerDietVegetarian;

  /// No description provided for @scannerDietVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get scannerDietVegan;

  /// No description provided for @scannerDetectedIngredients.
  ///
  /// In en, this message translates to:
  /// **'Detected Ingredients'**
  String get scannerDetectedIngredients;

  /// No description provided for @scannerIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get scannerIngredients;

  /// No description provided for @scannerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get scannerInstructions;

  /// No description provided for @chatLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You have reached your limit'**
  String get chatLimitReached;

  /// No description provided for @chatLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {limit} free messages. Upgrade to premium for unlimited access!'**
  String chatLimitReachedMessage(String limit);

  /// No description provided for @chatAiChefDisabled.
  ///
  /// In en, this message translates to:
  /// **'AI Chef chat is currently disabled. Upgrade to premium for unlimited access!'**
  String get chatAiChefDisabled;

  /// No description provided for @commonUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get commonUpgrade;

  /// No description provided for @backButtonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backButtonCancel;

  /// No description provided for @backButtonExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get backButtonExit;

  /// No description provided for @appHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'DishGenie'**
  String get appHeaderTitle;

  /// No description provided for @premiumCardUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock '**
  String get premiumCardUnlock;

  /// No description provided for @premiumCardDishGeniePro.
  ///
  /// In en, this message translates to:
  /// **'DishGenie Pro'**
  String get premiumCardDishGeniePro;

  /// No description provided for @premiumCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ad Free Experience, & Unlimited AI Features'**
  String get premiumCardSubtitle;

  /// No description provided for @scannerCookingTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Cooking Time'**
  String get scannerCookingTimeLabel;

  /// No description provided for @scannerTargetCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Calories'**
  String get scannerTargetCaloriesLabel;

  /// No description provided for @groceryDemoRecipeChickenBiryani.
  ///
  /// In en, this message translates to:
  /// **'Chicken Biryani'**
  String get groceryDemoRecipeChickenBiryani;

  /// No description provided for @groceryDemoRecipeDalMakhani.
  ///
  /// In en, this message translates to:
  /// **'Dal Makhani'**
  String get groceryDemoRecipeDalMakhani;

  /// No description provided for @groceryDemoRecipeAlooParatha.
  ///
  /// In en, this message translates to:
  /// **'Aloo Paratha'**
  String get groceryDemoRecipeAlooParatha;

  /// No description provided for @groceryPlaceholderWeeklyGrocery.
  ///
  /// In en, this message translates to:
  /// **'Weekly Grocery'**
  String get groceryPlaceholderWeeklyGrocery;

  /// No description provided for @groceryPlaceholderMonthlyStock.
  ///
  /// In en, this message translates to:
  /// **'Monthly Stock'**
  String get groceryPlaceholderMonthlyStock;

  /// No description provided for @groceryPlaceholderHighProteinDiet.
  ///
  /// In en, this message translates to:
  /// **'High Protein Diet'**
  String get groceryPlaceholderHighProteinDiet;

  /// No description provided for @groceryVoiceHintExample.
  ///
  /// In en, this message translates to:
  /// **'Say \"Add chicken, tomatoes...\"'**
  String get groceryVoiceHintExample;

  /// No description provided for @searchPlaceholder1.
  ///
  /// In en, this message translates to:
  /// **'✨ Ask the genie anything...'**
  String get searchPlaceholder1;

  /// No description provided for @searchPlaceholder2.
  ///
  /// In en, this message translates to:
  /// **'🍳 What\'s cooking today?'**
  String get searchPlaceholder2;

  /// No description provided for @searchPlaceholder3.
  ///
  /// In en, this message translates to:
  /// **'🌟 Your wish is my command...'**
  String get searchPlaceholder3;

  /// No description provided for @searchPlaceholder4.
  ///
  /// In en, this message translates to:
  /// **'🥗 Craving something healthy?'**
  String get searchPlaceholder4;

  /// No description provided for @searchPlaceholder5.
  ///
  /// In en, this message translates to:
  /// **'🛒 Add to grocery list...'**
  String get searchPlaceholder5;

  /// No description provided for @ingredientOnions.
  ///
  /// In en, this message translates to:
  /// **'Onions'**
  String get ingredientOnions;

  /// No description provided for @ingredientYogurt.
  ///
  /// In en, this message translates to:
  /// **'Yogurt'**
  String get ingredientYogurt;

  /// No description provided for @ingredientRice.
  ///
  /// In en, this message translates to:
  /// **'Rice'**
  String get ingredientRice;

  /// No description provided for @ingredientMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get ingredientMilk;

  /// No description provided for @ingredientTomatoes.
  ///
  /// In en, this message translates to:
  /// **'Tomatoes'**
  String get ingredientTomatoes;

  /// No description provided for @ingredientPotatoes.
  ///
  /// In en, this message translates to:
  /// **'Potatoes'**
  String get ingredientPotatoes;

  /// No description provided for @ingredientEggs.
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get ingredientEggs;

  /// No description provided for @ingredientBread.
  ///
  /// In en, this message translates to:
  /// **'Bread'**
  String get ingredientBread;

  /// No description provided for @ingredientOil.
  ///
  /// In en, this message translates to:
  /// **'Oil'**
  String get ingredientOil;

  /// No description provided for @scannerLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'You have reached your limit'**
  String get scannerLimitReachedTitle;

  /// No description provided for @landingHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Meet Your AI Chef — Create Recipes, Meal Plans & Smart Grocery Lists Instantly'**
  String get landingHeroTitle;

  /// No description provided for @landingHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal AI-powered kitchen assistant. Generate healthy recipes, plan meals for the week, and create smart grocery lists — all tailored to your taste, budget, and goals.'**
  String get landingHeroSubtitle;

  /// No description provided for @landingWhyDishGenie.
  ///
  /// In en, this message translates to:
  /// **'Why DishGenie?'**
  String get landingWhyDishGenie;

  /// No description provided for @landingKitchenSupercharged.
  ///
  /// In en, this message translates to:
  /// **'Your Kitchen, Supercharged'**
  String get landingKitchenSupercharged;

  /// No description provided for @landingFeatureRecipeBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Recipe Builder'**
  String get landingFeatureRecipeBuilderTitle;

  /// No description provided for @landingFeatureRecipeBuilderDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate personalized recipes from ingredients you have at home using AI'**
  String get landingFeatureRecipeBuilderDesc;

  /// No description provided for @landingFeatureMealPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalized Meal Plans'**
  String get landingFeatureMealPlansTitle;

  /// No description provided for @landingFeatureMealPlansDesc.
  ///
  /// In en, this message translates to:
  /// **'AI-powered weekly and monthly meal plans tailored to your goals'**
  String get landingFeatureMealPlansDesc;

  /// No description provided for @landingFeatureGroceryTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Grocery List'**
  String get landingFeatureGroceryTitle;

  /// No description provided for @landingFeatureGroceryDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate shopping lists organized by category with budget options'**
  String get landingFeatureGroceryDesc;

  /// No description provided for @landingSimpleEasy.
  ///
  /// In en, this message translates to:
  /// **'Simple & Easy'**
  String get landingSimpleEasy;

  /// No description provided for @landingHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get landingHowItWorks;

  /// No description provided for @landingStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Set Your Preferences'**
  String get landingStep1Title;

  /// No description provided for @landingStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Tell us your dietary goals, allergies, and cuisine preferences'**
  String get landingStep1Desc;

  /// No description provided for @landingStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Get AI Recommendations'**
  String get landingStep2Title;

  /// No description provided for @landingStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Receive personalized recipes and meal plans instantly'**
  String get landingStep2Desc;

  /// No description provided for @landingStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Cook & Track'**
  String get landingStep3Title;

  /// No description provided for @landingStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'Follow step-by-step guides and track your nutrition progress'**
  String get landingStep3Desc;

  /// No description provided for @landingLovedByThousands.
  ///
  /// In en, this message translates to:
  /// **'Loved by Thousands'**
  String get landingLovedByThousands;

  /// No description provided for @landingWhatUsersSay.
  ///
  /// In en, this message translates to:
  /// **'What Our Users Say'**
  String get landingWhatUsersSay;

  /// No description provided for @landingTestimonial1Name.
  ///
  /// In en, this message translates to:
  /// **'Sarah M.'**
  String get landingTestimonial1Name;

  /// No description provided for @landingTestimonial1Role.
  ///
  /// In en, this message translates to:
  /// **'Busy Mom'**
  String get landingTestimonial1Role;

  /// No description provided for @landingTestimonial1Quote.
  ///
  /// In en, this message translates to:
  /// **'DishGenie transformed my meal planning. I save 5+ hours every week!'**
  String get landingTestimonial1Quote;

  /// No description provided for @landingTestimonial2Name.
  ///
  /// In en, this message translates to:
  /// **'Ahmed K.'**
  String get landingTestimonial2Name;

  /// No description provided for @landingTestimonial2Role.
  ///
  /// In en, this message translates to:
  /// **'Fitness Enthusiast'**
  String get landingTestimonial2Role;

  /// No description provided for @landingTestimonial2Quote.
  ///
  /// In en, this message translates to:
  /// **'The calorie tracking and high-protein recipes are exactly what I needed.'**
  String get landingTestimonial2Quote;

  /// No description provided for @landingTestimonial3Name.
  ///
  /// In en, this message translates to:
  /// **'Priya S.'**
  String get landingTestimonial3Name;

  /// No description provided for @landingTestimonial3Role.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get landingTestimonial3Role;

  /// No description provided for @landingTestimonial3Quote.
  ///
  /// In en, this message translates to:
  /// **'Budget-friendly desi recipes that taste like home. Absolutely love it!'**
  String get landingTestimonial3Quote;

  /// No description provided for @landingStartCookingSmarter.
  ///
  /// In en, this message translates to:
  /// **'Start Cooking Smarter Today'**
  String get landingStartCookingSmarter;

  /// No description provided for @landingJoinThousands.
  ///
  /// In en, this message translates to:
  /// **'Join thousands of home cooks who\'ve transformed their kitchen experience with AI-powered meal planning.'**
  String get landingJoinThousands;

  /// No description provided for @landingCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2024 DishGenie AI. All rights reserved.'**
  String get landingCopyright;

  /// No description provided for @recipesLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You have reached your limit'**
  String get recipesLimitReached;

  /// No description provided for @recipesLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {limit} free recipe generations. Upgrade to premium for unlimited access!'**
  String recipesLimitReachedMessage(String limit);

  /// No description provided for @recipesAiRecipeDisabled.
  ///
  /// In en, this message translates to:
  /// **'AI recipe generation is currently disabled. Upgrade to premium for unlimited access!'**
  String get recipesAiRecipeDisabled;

  /// No description provided for @premiumPerWeek.
  ///
  /// In en, this message translates to:
  /// **'/Week'**
  String get premiumPerWeek;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'af',
    'ar',
    'bn',
    'de',
    'en',
    'fa',
    'fil',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'kk',
    'ko',
    'ms',
    'nl',
    'pl',
    'pt',
    'ru',
    'th',
    'tr',
    'uk',
    'ur',
    'uz',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'fil':
      return AppLocalizationsFil();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'kk':
      return AppLocalizationsKk();
    case 'ko':
      return AppLocalizationsKo();
    case 'ms':
      return AppLocalizationsMs();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'ur':
      return AppLocalizationsUr();
    case 'uz':
      return AppLocalizationsUz();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
