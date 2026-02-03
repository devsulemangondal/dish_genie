package com.dishgenie.recipeapp

import android.content.Context
import android.view.LayoutInflater
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/**
 * NativeAdFactory for medium horizontal native ads
 * Factory ID: "mediumAd"
 * Layout: custom_medium_native_ad.xml
 * 
 * This factory creates a horizontal layout with:
 * - MediaView on the left (120dp x 120dp)
 * - Headline, body text, and CTA button on the right
 */
class MediumNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {
        android.util.Log.d(TAG, "=== Factory called: mediumAd ===")
        android.util.Log.d(TAG, "Native ad headline: ${nativeAd.headline}")
        android.util.Log.d(TAG, "Native ad body: ${nativeAd.body}")
        android.util.Log.d(TAG, "Native ad CTA: ${nativeAd.callToAction}")
        android.util.Log.d(TAG, "Native ad has media: ${nativeAd.mediaContent != null}")
        
        val layoutInflater = LayoutInflater.from(context)
        val adView = try {
            val inflated = layoutInflater.inflate(
                com.dishgenie.recipeapp.R.layout.custom_medium_native_ad,
                null
            ) as NativeAdView
            // Ensure proper layout parameters
            inflated.layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT
            )
            inflated
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to inflate layout: ${e.message}", e)
            throw e
        }

        try {
            android.util.Log.d(TAG, "Layout inflated successfully, binding views...")
            
            // CRITICAL: Always bind views if they exist in layout, regardless of ad content
            // The SDK will automatically show/hide views based on available content
            
            // 1. Bind MediaView (required for medium native ads with images/videos)
            val mediaView = adView.findViewById<MediaView>(com.dishgenie.recipeapp.R.id.ad_media)
            if (mediaView != null) {
                adView.mediaView = mediaView
                android.util.Log.d(TAG, "✓ MediaView bound (ID: ad_media)")
            } else {
                android.util.Log.e(TAG, "✗ MediaView not found in layout! Check XML.")
            }

            // 2. Bind HeadlineView (required - ad title)
            val headlineView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_headline)
            if (headlineView != null) {
                adView.headlineView = headlineView
                // Ensure text is visible
                headlineView.visibility = android.view.View.VISIBLE
                android.util.Log.d(TAG, "✓ HeadlineView bound (ID: ad_headline), visibility: VISIBLE")
            } else {
                android.util.Log.e(TAG, "✗ HeadlineView not found in layout! Check XML.")
            }

            // 3. Bind BodyView (required - ad description)
            val bodyView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_body)
            if (bodyView != null) {
                adView.bodyView = bodyView
                // Ensure text is visible
                bodyView.visibility = android.view.View.VISIBLE
                android.util.Log.d(TAG, "✓ BodyView bound (ID: ad_body), visibility: VISIBLE")
            } else {
                android.util.Log.e(TAG, "✗ BodyView not found in layout! Check XML.")
            }

            // 4. Bind CallToActionView (required - button)
            val callToActionView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_call_to_action)
            if (callToActionView != null) {
                adView.callToActionView = callToActionView
                android.util.Log.d(TAG, "✓ CallToActionView bound (ID: ad_call_to_action)")
            } else {
                android.util.Log.e(TAG, "✗ CallToActionView not found in layout! Check XML.")
            }

            // CRITICAL: Set native ad AFTER all views are bound
            // This populates the views and enables impression/click tracking
            adView.setNativeAd(nativeAd)
            android.util.Log.d(TAG, "✓ Native ad set successfully - all views registered")
            android.util.Log.d(TAG, "AdView width: ${adView.width}, height: ${adView.height}")
            android.util.Log.d(TAG, "AdView visibility: ${adView.visibility}")
            
            // Explicitly set text content AFTER setNativeAd() to ensure it's populated
            // Text colors are handled by XML theme attributes (?attr/nativeAdTextSecondary)
            // which automatically adapt to light/dark mode
            headlineView?.let {
                nativeAd.headline?.let { headline ->
                    it.text = headline
                    android.util.Log.d(TAG, "✓ Headline text explicitly set: $headline (color from theme)")
                }
            }
            bodyView?.let {
                nativeAd.body?.let { body ->
                    it.text = body
                    android.util.Log.d(TAG, "✓ Body text explicitly set: $body (color from theme)")
                }
            }
            callToActionView?.let {
                nativeAd.callToAction?.let { cta ->
                    it.text = cta
                    android.util.Log.d(TAG, "✓ CTA text explicitly set: $cta")
                }
            }
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "✗ Error creating native ad: ${e.message}", e)
            e.printStackTrace()
            // Still set the native ad even if binding failed - SDK might handle it
            try {
                adView.setNativeAd(nativeAd)
                android.util.Log.d(TAG, "Native ad set despite binding errors")
            } catch (setError: Exception) {
                android.util.Log.e(TAG, "Failed to set native ad: ${setError.message}", setError)
            }
        }

        android.util.Log.d(TAG, "=== Factory returning adView ===")
        return adView
    }
    
    companion object {
        private const val TAG = "MediumNativeAdFactory"
    }
}
