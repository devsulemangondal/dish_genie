package com.dishgenie.recipeapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        android.util.Log.d("MainActivity", "Configuring Flutter engine - registering native ad factories")
        
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
    }
}
