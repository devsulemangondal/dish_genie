import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// In-app subscription (weekly). Product ID in code must match Play Console exactly.
///
/// If subscription doesn't work, check:
/// 1. Play Console → Your app → Monetize → Subscriptions: create a subscription with
///    product ID exactly "weekly_sub" (no extra characters).
/// 2. Upload the app to at least Internal testing (Setup → App integrity). Products
///    often don't load for draft-only or unsigned debug builds.
/// 3. Activate the subscription (not Draft) and wait a few hours if just created.
/// 4. On device: use a Google account that is a License tester (Setup → License testing)
///    or install the app from the Internal testing track.
/// 5. App package name must match: com.dishgenie.recipeapp
class BillingService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static bool _isAvailable = false;
  static bool _isInitialized = false;
  static bool _hasPremiumEntitlement = false;

  // Product ID must match EXACTLY the subscription ID in Play Console (Monetize → Subscriptions).
  static const String weeklySubscriptionId = 'weekly_sub';

  static final List<String> _productIds = [weeklySubscriptionId];

  static List<ProductDetails> _products = [];
  static final StreamController<PurchaseDetails> _purchaseController =
      StreamController<PurchaseDetails>.broadcast();
  static final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  static Stream<PurchaseDetails> get purchaseStream =>
      _purchaseController.stream;
  static Stream<String?> get errorStream => _errorController.stream;
  static List<ProductDetails> get products => _products;
  static bool get isAvailable => _isAvailable;
  static bool get hasPremiumEntitlement => _hasPremiumEntitlement;
  static bool get isLoadingProducts => _isLoadingProducts;
  static bool isPremiumProductId(String productId) =>
      productId == weeklySubscriptionId;

  static bool _isLoadingProducts = false;
  static String? _lastError;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    _isAvailable = await _iap.isAvailable();

    if (kDebugMode) {
      if (!_isAvailable) {
        print(
          '[BillingService] In-App Purchase not available (device/Play Services). Install from Play or use Internal testing build.',
        );
      } else {
        print('[BillingService] IAP available, loading products...');
      }
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      (purchases) {
        for (var purchase in purchases) {
          _handlePurchaseUpdate(purchase);
        }
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        if (kDebugMode) {
          print('Purchase stream error: $error');
        }
      },
    );

    // Load products
    await loadProducts();

    _isInitialized = true;
  }

  static Future<bool> loadProducts({bool retry = false}) async {
    if (!_isAvailable) {
      _lastError = 'In-App Purchase is not available on this device';
      _errorController.add(_lastError);
      return false;
    }

    if (_isLoadingProducts && !retry) {
      return false; // Already loading
    }

    _isLoadingProducts = true;
    _lastError = null;
    _errorController.add(null);

    try {
      final productDetailsResponse = await _iap.queryProductDetails(
        _productIds.toSet(),
      );

      if (kDebugMode) {
        final notFound = productDetailsResponse.notFoundIDs;
        if (notFound.isNotEmpty) {
          print(
            '[BillingService] ⚠️ Product IDs NOT FOUND in Play Console: $notFound',
          );
          print(
            '[BillingService] → Create a subscription with ID exactly: $weeklySubscriptionId',
          );
        }
      }

      if (productDetailsResponse.error != null) {
        final err = productDetailsResponse.error!;
        final errorMessage = err.message.isNotEmpty
            ? err.message
            : 'Failed to load subscription plans';
        _lastError = errorMessage;
        _errorController.add(_lastError);

        if (kDebugMode) {
          print(
            '[BillingService] Error: code=${err.code} message=${err.message} details=${err.details}',
          );
        }
        _isLoadingProducts = false;
        return false;
      }

      _products = productDetailsResponse.productDetails;

      if (_products.isEmpty) {
        _lastError =
            'No subscription found. In Play Console use product ID "$weeklySubscriptionId" and upload app to Internal testing.';
        _errorController.add(_lastError);
        if (kDebugMode) {
          print(
            '[BillingService] No products for IDs: $_productIds; notFoundIDs: ${productDetailsResponse.notFoundIDs}',
          );
        }
        _isLoadingProducts = false;
        return false;
      }

      if (kDebugMode) {
        print(
          '[BillingService] Successfully loaded ${_products.length} product(s)',
        );
        for (var product in _products) {
          print(
            '[BillingService] Product: ${product.id} - ${product.title} - ${product.price}',
          );
        }
      }

      // Restore previous purchases
      await _restorePurchases();

      _isLoadingProducts = false;
      return true;
    } catch (e) {
      final errorMessage = 'Failed to load subscription plans: ${e.toString()}';
      _lastError = errorMessage;
      _errorController.add(_lastError);

      if (kDebugMode) {
        print('[BillingService] Exception loading products: $e');
      }
      _isLoadingProducts = false;
      return false;
    }
  }

  static Future<void> _restorePurchases() async {
    await _iap.restorePurchases();
  }

  static Future<void> restorePurchases() async {
    await _restorePurchases();
  }

  static Future<bool> purchaseProduct(ProductDetails product) async {
    if (!_isAvailable) {
      _lastError = 'In-App Purchase is not available on this device';
      _errorController.add(_lastError);
      if (kDebugMode) {
        print('[BillingService] In-App Purchase not available');
      }
      return false;
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);

      // For subscriptions, the in_app_purchase package uses buyNonConsumable
      // The actual subscription type is determined by how the product is configured
      // in Google Play Console (for Android) or App Store Connect (for iOS)
      // Subscriptions must be configured as subscription products in the store
      if (product.id == weeklySubscriptionId) {
        // This is a subscription product - use buyNonConsumable
        // The store will handle it as a subscription based on product configuration
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      }

      if (kDebugMode) {
        print('[BillingService] Purchase initiated for: ${product.id}');
      }
      return true;
    } catch (e) {
      final errorMessage = 'Failed to initiate purchase: ${e.toString()}';
      _lastError = errorMessage;
      _errorController.add(_lastError);

      if (kDebugMode) {
        print('[BillingService] Purchase error: $e');
      }
      return false;
    }
  }

  static void _handlePurchaseUpdate(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        if (kDebugMode) {
          print('Purchase pending: ${purchase.productID}');
        }
        _purchaseController.add(purchase);
        break;
      case PurchaseStatus.purchased:
        if (kDebugMode) {
          print('Purchase successful: ${purchase.productID}');
        }
        if (isPremiumProductId(purchase.productID)) {
          // Verify purchase before granting entitlement
          _verifyPurchase(purchase).then((isValid) {
            if (isValid) {
              _hasPremiumEntitlement = true;
            }
          });
        }
        _purchaseController.add(purchase);
        break;
      case PurchaseStatus.restored:
        if (kDebugMode) {
          print('Purchase restored: ${purchase.productID}');
        }
        if (isPremiumProductId(purchase.productID)) {
          // Verify restored purchase before granting entitlement
          _verifyPurchase(purchase).then((isValid) {
            if (isValid) {
              _hasPremiumEntitlement = true;
            }
          });
        }
        _purchaseController.add(purchase);
        break;
      case PurchaseStatus.error:
        if (kDebugMode) {
          print('Purchase error: ${purchase.error}');
        }
        // If error occurs for premium product, revoke entitlement
        if (isPremiumProductId(purchase.productID)) {
          _hasPremiumEntitlement = false;
        }
        _purchaseController.add(purchase);
        break;
      case PurchaseStatus.canceled:
        if (kDebugMode) {
          print('Purchase canceled: ${purchase.productID}');
        }
        // For subscriptions, canceled status means subscription expired/canceled
        // Revoke premium entitlement when subscription is canceled
        if (isPremiumProductId(purchase.productID)) {
          _hasPremiumEntitlement = false;
        }
        _purchaseController.add(purchase);
        break;
    }

    // Complete the purchase if it's not pending
    if (purchase.pendingCompletePurchase) {
      _iap.completePurchase(purchase);
    }
  }

  /// Verify purchase with backend server
  /// Returns true if purchase is valid, false otherwise
  ///
  /// TODO: Implement server-side verification
  /// 1. Send purchase.verificationData to your backend
  /// 2. Backend should verify with Google Play/App Store APIs
  /// 3. Backend should check subscription status and expiry
  /// 4. Return verification result
  static Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    if (kDebugMode) {
      print('Verifying purchase: ${purchase.productID}');
      print('Transaction date: ${purchase.transactionDate}');
      print('Verification data source: ${purchase.verificationData.source}');
    }

    // TODO: Implement server-side verification
    // Example structure:
    // try {
    //   final response = await http.post(
    //     Uri.parse('https://your-backend.com/verify-purchase'),
    //     body: {
    //       'verification_data': purchase.verificationData.serverVerificationData,
    //       'product_id': purchase.productID,
    //       'transaction_date': purchase.transactionDate,
    //     },
    //   );
    //   return response.statusCode == 200 && jsonDecode(response.body)['valid'] == true;
    // } catch (e) {
    //   if (kDebugMode) print('Verification error: $e');
    //   return false;
    // }

    // For now, accept local verification for subscriptions
    // In production, this should always verify with backend
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Check if subscription is still active (for subscriptions)
      // For subscriptions, you should check expiry date from server
      return true;
    }

    return false;
  }

  /// Check subscription status periodically
  /// This should be called on app start and periodically to verify active subscriptions
  static Future<void> checkSubscriptionStatus() async {
    if (!_isAvailable || !_isInitialized) return;

    try {
      // Restore purchases to get latest subscription status
      await _restorePurchases();

      // The purchase stream will automatically update _hasPremiumEntitlement
      // based on the restored purchase status
    } catch (e) {
      if (kDebugMode) {
        print('Error checking subscription status: $e');
      }
    }
  }

  static ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  static String? get lastError => _lastError;

  static void dispose() {
    _subscription?.cancel();
    _purchaseController.close();
    _errorController.close();
  }
}
