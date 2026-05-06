package com.dishgenie.recipeapp

import android.content.Context
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/**
 * Compact bottom strip native layout (matches Ummah Pro bottom_native).
 * Factory ID: "bottomNativeAd"
 */
class BottomNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?
    ): NativeAdView {
        val layoutInflater = LayoutInflater.from(context)
        val adView = layoutInflater.inflate(
            com.dishgenie.recipeapp.R.layout.custom_bottom_native_ad,
            null
        ) as NativeAdView

        val mediaView = adView.findViewById<MediaView>(com.dishgenie.recipeapp.R.id.ad_media)
        val headlineView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_headline)
        val bodyView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_body)
        val callToActionView = adView.findViewById<TextView>(com.dishgenie.recipeapp.R.id.ad_call_to_action)

        val ctaParams = callToActionView.layoutParams
        ctaParams?.height = ViewGroup.LayoutParams.MATCH_PARENT
        callToActionView.layoutParams = ctaParams

        adView.mediaView = mediaView
        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.callToActionView = callToActionView
        adView.setNativeAd(nativeAd)

        nativeAd.headline?.let { headlineView.text = it }
        nativeAd.body?.let { bodyView.text = it }
        nativeAd.callToAction?.let { callToActionView.text = it }

        return adView
    }
}
