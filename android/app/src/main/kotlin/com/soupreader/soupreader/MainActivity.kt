package com.soupreader.soupreader

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "soupreader/screen_brightness"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "setBrightness" -> {
            val value = (call.argument<Double>("brightness") ?: 1.0).toFloat()
            runOnUiThread {
              val attrs = window.attributes
              attrs.screenBrightness = value.coerceIn(0.0f, 1.0f)
              window.attributes = attrs
              result.success(null)
            }
          }
          "resetBrightness" -> {
            runOnUiThread {
              val attrs = window.attributes
              attrs.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
              window.attributes = attrs
              result.success(null)
            }
          }
          else -> result.notImplemented()
        }
      }
  }
}
