package com.dishgenie.recipeapp

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.android.ump.ConsentDebugSettings
import com.google.android.ump.ConsentForm
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.FormError
import com.google.android.ump.UserMessagingPlatform

/**
 * Google UMP (User Messaging Platform) consent manager for GDPR.
 * This gates ad requests until consent is gathered (when required).
 */
class GoogleMobileAdsConsentManager private constructor(context: Context) {
  private val consentInformation: ConsentInformation =
    UserMessagingPlatform.getConsentInformation(context)

  fun interface OnConsentGatheringCompleteListener {
    fun consentGatheringComplete(error: FormError?)
  }

  val canRequestAds: Boolean
    get() = consentInformation.canRequestAds()

  val isPrivacyOptionsRequired: Boolean
    get() =
      consentInformation.privacyOptionsRequirementStatus ==
        ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

  fun gatherConsent(
    activity: Activity,
    onConsentGatheringCompleteListener: OnConsentGatheringCompleteListener,
  ) {
    // Requesting an update to consent information should be called on every app launch.
    // Debug settings are optional; keep them disabled for release builds.
    val paramsBuilder = ConsentRequestParameters.Builder()
    if (BuildConfig.DEBUG && BuildConfig.UMP_DEBUG_FORCE_EEA) {
      Log.i("UMP", "Debug consent enabled: forcing EEA geography")
      val dbg = ConsentDebugSettings.Builder(activity)
        .setDebugGeography(ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA)

      val testId = BuildConfig.UMP_TEST_DEVICE_HASHED_ID
      if (testId.isNotBlank()) {
        Log.i("UMP", "Using test device hashed id: $testId")
        dbg.addTestDeviceHashedId(testId)
      } else {
        Log.w(
          "UMP",
          "UMP_TEST_DEVICE_HASHED_ID is blank; UMP may ignore debug geography. " +
            "Check Logcat for: 'addTestDeviceHashedId(\"...\")' and paste it into build.gradle.kts",
        )
      }

      paramsBuilder.setConsentDebugSettings(dbg.build())
    } else {
      Log.i(
        "UMP",
        "Debug consent NOT enabled (DEBUG=${BuildConfig.DEBUG}, FORCE_EEA=${BuildConfig.UMP_DEBUG_FORCE_EEA})",
      )
    }

    val params = paramsBuilder.build()

    consentInformation.requestConsentInfoUpdate(
      activity,
      params,
      {
        UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { formError ->
          onConsentGatheringCompleteListener.consentGatheringComplete(formError)
        }
      },
      { requestConsentError ->
        onConsentGatheringCompleteListener.consentGatheringComplete(requestConsentError)
      },
    )
  }

  fun showPrivacyOptionsForm(
    activity: Activity,
    onConsentFormDismissedListener: ConsentForm.OnConsentFormDismissedListener,
  ) {
    UserMessagingPlatform.showPrivacyOptionsForm(activity, onConsentFormDismissedListener)
  }

  fun reset() {
    consentInformation.reset()
  }

  companion object {
    @Volatile private var instance: GoogleMobileAdsConsentManager? = null

    fun getInstance(context: Context): GoogleMobileAdsConsentManager =
      instance ?: synchronized(this) {
        instance ?: GoogleMobileAdsConsentManager(context).also { instance = it }
      }
  }
}

