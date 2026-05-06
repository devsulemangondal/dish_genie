package com.dishgenie.recipeapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    private val consentChannelName = "com.dishgenie.recipeapp/gdpr_consent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        android.util.Log.d("MainActivity", "Configuring Flutter engine - registering native ad factories")

        // GDPR/UMP consent bridge for Flutter (must be called before MobileAds.initialize()).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, consentChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "gatherConsent" -> {
                    val mgr = GoogleMobileAdsConsentManager.getInstance(applicationContext)
                    mgr.gatherConsent(this) { error ->
                        val map = hashMapOf<String, Any?>(
                            "canRequestAds" to mgr.canRequestAds,
                            "isPrivacyOptionsRequired" to mgr.isPrivacyOptionsRequired,
                            "errorCode" to error?.errorCode,
                            "errorMessage" to error?.message
                        )
                        result.success(map)
                    }
                }
                "canRequestAds" -> {
                    val mgr = GoogleMobileAdsConsentManager.getInstance(applicationContext)
                    result.success(mgr.canRequestAds)
                }
                "showPrivacyOptionsForm" -> {
                    val mgr = GoogleMobileAdsConsentManager.getInstance(applicationContext)
                    mgr.showPrivacyOptionsForm(this) { formError ->
                        val map = hashMapOf<String, Any?>(
                            "canRequestAds" to mgr.canRequestAds,
                            "isPrivacyOptionsRequired" to mgr.isPrivacyOptionsRequired,
                            "errorCode" to formError?.errorCode,
                            "errorMessage" to formError?.message
                        )
                        result.success(map)
                    }
                }
                "resetConsent" -> {
                    val mgr = GoogleMobileAdsConsentManager.getInstance(applicationContext)
                    mgr.reset()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Register custom native ad factory for medium ads
        try {
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine,
                "mediumAd",
                MediumNativeAdFactory(this)
            )
            android.util.Log.d("MainActivity", "✓ Registered factory: mediumAd")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "✗ Failed to register mediumAd factory: ${e.message}", e)
        }
        
        // Register custom native ad factory for small ads
        try {
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine,
                "smallAd",
                SmallNativeAdFactory(this)
            )
            android.util.Log.d("MainActivity", "✓ Registered factory: smallAd")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "✗ Failed to register smallAd factory: ${e.message}", e)
        }

        try {
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine,
                "bottomNativeAd",
                BottomNativeAdFactory(this)
            )
            android.util.Log.d("MainActivity", "✓ Registered factory: bottomNativeAd")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "✗ Failed to register bottomNativeAd factory: ${e.message}", e)
        }
    }
}
