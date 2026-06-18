package com.healthconnectreporter

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.util.TypedValue
import android.view.Gravity

/**
 * Required by Health Connect and Google Play Store review.
 *
 * This activity is launched when users tap "Learn more" in the
 * Health Connect permissions dialog or via the Android 14+
 * VIEW_PERMISSION_USAGE intent.
 *
 * It explains why the app needs health data access.
 */
class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val scrollView = ScrollView(this).apply {
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        val title = TextView(this).apply {
            text = "Health Data Access"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            setTypeface(null, android.graphics.Typeface.BOLD)
        }

        val subtitle = TextView(this).apply {
            text = "Why this app needs your health data"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, dp(4), 0, dp(16))
            setTextColor(0xFF666666.toInt())
        }

        val body = TextView(this).apply {
            text = """
                This app reads your health and fitness data from Health Connect to provide you with a unified view of your wellness metrics.

                Data types we access:
                • Activity: steps, distance, floors, calories, exercise sessions
                • Sleep: sleep sessions and stage breakdown
                • Vitals: heart rate, HRV, blood pressure, blood oxygen, respiratory rate, body temperature, VO2 max, blood glucose
                • Body: weight, height, body fat, lean body mass, BMR
                • Nutrition: dietary intake and hydration

                How we use your data:
                • Display your health metrics in the app dashboard
                • Track trends and history over time
                • All data stays on your device

                Your data is never sold or shared with third parties. You can revoke access at any time in Health Connect settings.
            """.trimIndent()
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setLineSpacing(dp(4).toFloat(), 1f)
        }

        val closeButton = Button(this).apply {
            text = "Close"
            setPadding(dp(16), dp(12), dp(16), dp(12))
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                topMargin = dp(24)
            }
            layoutParams = params
            setOnClickListener { finish() }
        }

        layout.addView(title)
        layout.addView(subtitle)
        layout.addView(body)
        layout.addView(closeButton)
        scrollView.addView(layout)
        setContentView(scrollView)
    }
}
