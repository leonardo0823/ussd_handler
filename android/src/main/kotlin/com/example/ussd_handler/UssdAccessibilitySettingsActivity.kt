package com.example.ussd_handler

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings

class UssdAccessibilitySettingsActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Open accessibility settings directly
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
        
        // Close this activity immediately
        finish()
    }
}
