package com.soupreader.soupreader

import android.net.Uri
import android.view.WindowManager
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val brightnessChannelName = "soupreader/screen_brightness"
  private val keepScreenOnChannelName = "soupreader/keep_screen_on"
  private val webviewCookiesChannelName = "soupreader/webview_cookies"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, brightnessChannelName)
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

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, keepScreenOnChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "setEnabled" -> {
            val enabled = call.argument<Boolean>("enabled") ?: false
            runOnUiThread {
              if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
              } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
              }
              result.success(null)
            }
          }
          else -> result.notImplemented()
        }
      }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, webviewCookiesChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getCookiesForUrl" -> {
            val url = call.argument<String>("url")?.trim().orEmpty()
            if (url.isEmpty()) {
              result.error("ARGUMENT_ERROR", "Missing url", null)
              return@setMethodCallHandler
            }
            result.success(readCookiesForUrl(url))
          }
          "getCookies" -> {
            val domain = call.argument<String>("domain")?.trim().orEmpty()
            if (domain.isEmpty()) {
              result.error("ARGUMENT_ERROR", "Missing domain", null)
              return@setMethodCallHandler
            }
            val includeSubdomains = call.argument<Boolean>("includeSubdomains") ?: true
            result.success(readCookiesForDomain(domain, includeSubdomains))
          }
          "clearAllCookies" -> {
            runOnUiThread {
              val cookieManager = CookieManager.getInstance()
              cookieManager.removeAllCookies { removed ->
                cookieManager.flush()
                result.success(removed)
              }
            }
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun readCookiesForUrl(url: String): List<Map<String, Any>> {
    val uri = try {
      Uri.parse(url)
    } catch (_: Exception) {
      null
    } ?: return emptyList()
    val host = uri.host?.trim().orEmpty()
    if (host.isEmpty()) return emptyList()

    val cookieHeader = CookieManager.getInstance().getCookie(url)
    return parseCookieHeader(cookieHeader, host)
  }

  private fun readCookiesForDomain(
    domain: String,
    includeSubdomains: Boolean
  ): List<Map<String, Any>> {
    val normalized = domain.trim().removePrefix(".")
    if (normalized.isEmpty()) return emptyList()

    val hostCandidates = linkedSetOf(normalized)
    if (includeSubdomains) {
      val labels = normalized.split(".").filter { it.isNotBlank() }
      for (start in labels.indices) {
        val candidate = labels.subList(start, labels.size).joinToString(".")
        if (candidate.contains('.')) {
          hostCandidates.add(candidate)
        }
      }
    }

    val merged = linkedMapOf<String, Map<String, Any>>()
    for (host in hostCandidates) {
      val httpsCookies = parseCookieHeader(
        CookieManager.getInstance().getCookie("https://$host/"),
        host
      )
      val httpCookies = parseCookieHeader(
        CookieManager.getInstance().getCookie("http://$host/"),
        host
      )
      for (cookie in httpsCookies + httpCookies) {
        val name = cookie["name"]?.toString().orEmpty()
        val value = cookie["value"]?.toString().orEmpty()
        val key = "$name|$value|$host"
        merged[key] = cookie
      }
    }
    return merged.values.toList()
  }

  private fun parseCookieHeader(
    cookieHeader: String?,
    fallbackDomain: String
  ): List<Map<String, Any>> {
    if (cookieHeader.isNullOrBlank()) return emptyList()

    val out = mutableListOf<Map<String, Any>>()
    for (segment in cookieHeader.split(";")) {
      val pair = segment.trim()
      if (pair.isEmpty()) continue
      val index = pair.indexOf('=')
      if (index <= 0) continue

      val name = pair.substring(0, index).trim()
      if (name.isEmpty()) continue
      val value = pair.substring(index + 1).trim()
      out.add(
        mapOf(
          "name" to name,
          "value" to value,
          "domain" to fallbackDomain,
          "path" to "/",
          "secure" to false,
          "httpOnly" to false
        )
      )
    }
    return out
  }
}
