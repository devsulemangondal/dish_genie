package com.dishgenie.recipeapp

import android.content.Context
import android.view.LayoutInflater
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/**
 * NativeAdFactory for small horizontal native ads
 * Factory ID: "smallAd"
 * Layout: custom_small_native_ad.xml
 * 
 * This factory creates a horizontal layout with:
 * - MediaView on the left (64dp x 64dp)
 * - Headline and body text in the middle
 * - CTA button on the right
 */
class SmallNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {
        android.util.Log.d(TAG, "=== Factory called: smallAd ===")
        android.util.Log.d(TAG, "Native ad headline: ${nativeAd.headline}")
        android.util.Log.d(TAG, "Native ad body: ${nativeAd.body}")
        android.util.Log.d(TAG, "Native ad CTA: ${nativeAd.callToAction}")
        android.util.Log.d(TAG, "Native ad has media: ${nativeAd.mediaContent != null}")
        
        val layoutInflater = LayoutInflater.from(context)
        val adView = try {
            val inflated = layoutInflater.inflate(
                com.dishgenie.recipeapp.R.layout.custom_small_native_ad,
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
            
            // Set the media view (left side) - only if available
            val mediaView = adView.findViewById<MediaView>(com.dishgenie.recipeapp.R.id.ad_media)
            if (mediaView != null) {
                adView.mediaView = mediaView
                // MediaView handles its own scaling internally
                android.util.Log.d(TAG, "✓ MediaView set - image will be fully visible")
            } else {
                android.util.Log.w(TAG, "✗ MediaView not found")
            }

            // Set the headline - only if available
            val headlineView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_headline)
            if (headlineView != null) {
                adView.headlineView = headlineView
                headlineView.visibility = android.view.View.VISIBLE
                android.util.Log.d(TAG, "✓ HeadlineView set, visibility: VISIBLE")
            } else {
                android.util.Log.w(TAG, "✗ HeadlineView not found")
            }

            // Set the body text - only if available
            val bodyView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_body)
            if (bodyView != null) {
                adView.bodyView = bodyView
                bodyView.visibility = android.view.View.VISIBLE
                android.util.Log.d(TAG, "✓ BodyView set, visibility: VISIBLE")
            } else {
                android.util.Log.w(TAG, "✗ BodyView not found")
            }

            // Set the call to action button (TextView styled as button) - only if available
            val callToActionView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_call_to_action)
            if (callToActionView != null) {
                adView.callToActionView = callToActionView
                android.util.Log.d(TAG, "✓ CallToActionView set")
            } else {
                android.util.Log.w(TAG, "✗ CallToActionView not found")
            }

            // Register all views with the native ad
            // IMPORTANT: This ensures Google properly tracks impressions and clicks
            adView.setNativeAd(nativeAd)
            android.util.Log.d(TAG, "✓ Native ad registered successfully")
            
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

            // Background color will be handled by theme attributes in XML
        } catch (e: Exception) {
            android.util.Log.e(TAG, "✗ Error setting up native ad: ${e.message}", e)
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
        private const val TAG = "SmallNativeAdFactory"
    }
}
