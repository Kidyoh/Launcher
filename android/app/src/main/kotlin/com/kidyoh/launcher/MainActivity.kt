package com.kidyoh.launcher

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.app.Activity
import android.app.SearchManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingDefaultRequest: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val launcherApps by lazy { getSystemService(LauncherApps::class.java) }
    private val userManager by lazy { getSystemService(UserManager::class.java) }

    // Install, uninstall and update events arrive in bursts, so they are
    // coalesced into one "appsChanged" message for Dart.
    private val notifyAppsChanged = Runnable { channel?.invokeMethod("appsChanged", null) }

    private val appsCallback = object : LauncherApps.Callback() {
        override fun onPackageRemoved(packageName: String, user: UserHandle) = scheduleAppsChanged()
        override fun onPackageAdded(packageName: String, user: UserHandle) = scheduleAppsChanged()
        override fun onPackageChanged(packageName: String, user: UserHandle) = scheduleAppsChanged()
        override fun onPackagesAvailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) =
            scheduleAppsChanged()
        override fun onPackagesUnavailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) =
            scheduleAppsChanged()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(::handle)
        }
        launcherApps.registerCallback(appsCallback, mainHandler)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        launcherApps.unregisterCallback(appsCallback)
        mainHandler.removeCallbacks(notifyAppsChanged)
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Pressing home while the launcher is already in front returns to the home page.
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            channel?.invokeMethod("home", null)
        }
    }

    private fun scheduleAppsChanged() {
        mainHandler.removeCallbacks(notifyAppsChanged)
        mainHandler.postDelayed(notifyAppsChanged, 300)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getApps" -> worker.execute {
                val apps = try {
                    loadApps()
                } catch (e: Exception) {
                    emptyList()
                }
                mainHandler.post { result.success(apps) }
            }
            "launch" -> result.success(attempt {
                launcherApps.startMainActivity(component(call), user(call), null, null)
            })
            "appInfo" -> result.success(attempt {
                launcherApps.startAppDetailsActivity(component(call), user(call), null, null)
            })
            "uninstall" -> result.success(attempt {
                val pkg = call.argument<String>("package")!!
                startActivity(
                    Intent(Intent.ACTION_DELETE, Uri.fromParts("package", pkg, null))
                        .putExtra(Intent.EXTRA_USER, user(call))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            })
            "expandNotifications" -> result.success(expandNotifications())
            "lockScreen" -> result.success(lockScreen())
            "open" -> result.success(open(call.argument<String>("target")!!, call.argument<String>("query")))
            "isDefaultLauncher" -> result.success(isDefaultLauncher())
            "requestDefaultLauncher" -> requestDefaultLauncher(result)
            else -> result.notImplemented()
        }
    }

    private fun loadApps(): List<Map<String, Any>> {
        val apps = ArrayList<Map<String, Any>>()
        val me = Process.myUserHandle()
        for (profile in userManager.userProfiles) {
            // Paused work profiles and locked private spaces can't launch anything.
            if (profile != me && userManager.isQuietModeEnabled(profile)) continue
            val serial = userManager.getSerialNumberForUser(profile)
            for (info in launcherApps.getActivityList(null, profile)) {
                val component = info.componentName
                if (component.packageName == packageName) continue
                apps.add(
                    mapOf(
                        "label" to info.label.toString().trim(),
                        "package" to component.packageName,
                        "activity" to component.className,
                        "user" to serial,
                        "work" to (profile != me),
                    )
                )
            }
        }
        return apps
    }

    private fun component(call: MethodCall) =
        ComponentName(call.argument<String>("package")!!, call.argument<String>("activity")!!)

    private fun user(call: MethodCall): UserHandle {
        val serial = call.argument<Number>("user")?.toLong() ?: return Process.myUserHandle()
        return userManager.getUserForSerialNumber(serial) ?: Process.myUserHandle()
    }

    private inline fun attempt(block: () -> Unit): Boolean = try {
        block()
        true
    } catch (e: Exception) {
        false
    }

    // StatusBarManager.expandNotificationsPanel is not in the public SDK, but
    // every major launcher calls it this way. EXPAND_STATUS_BAR is a normal permission.
    @SuppressLint("WrongConstant")
    private fun expandNotifications(): Boolean = attempt {
        val statusBar = getSystemService("statusbar")
        statusBar.javaClass.getMethod("expandNotificationsPanel").invoke(statusBar)
    }

    private fun lockScreen(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return "unsupported"
        val service = LockService.instance ?: return "needs_permission"
        return if (service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN)) "ok" else "failed"
    }

    private fun open(target: String, query: String?): Boolean {
        val intent = when (target) {
            "dialer" -> Intent(Intent.ACTION_DIAL)
            "camera" -> Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
            "alarms" -> Intent(AlarmClock.ACTION_SHOW_ALARMS)
            "calendar" -> Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_CALENDAR)
            "webSearch" -> Intent(Intent.ACTION_WEB_SEARCH).putExtra(SearchManager.QUERY, query ?: "")
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            else -> return false
        }
        return attempt { startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }

    /**
     * Shows Android's "Set as default home app?" dialog (Android 10+), or the
     * home app picker in system settings on older versions or if the dialog
     * is blocked because the user declined it before. Replies with whether
     * Launcher is now the default.
     */
    private fun requestDefaultLauncher(result: MethodChannel.Result) {
        if (isDefaultLauncher()) return result.success(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = getSystemService(RoleManager::class.java)
            if (roles.isRoleAvailable(RoleManager.ROLE_HOME)) {
                pendingDefaultRequest?.success(false)
                pendingDefaultRequest = result
                startActivityForResult(roles.createRequestRoleIntent(RoleManager.ROLE_HOME), REQUEST_DEFAULT)
                return
            }
        }
        openHomeSettings()
        result.success(false)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_DEFAULT) return
        val result = pendingDefaultRequest ?: return
        pendingDefaultRequest = null
        if (resultCode != Activity.RESULT_OK && !isDefaultLauncher()) {
            // Android stops showing the dialog after it's been declined, so
            // fall back to the settings screen where the choice is always offered.
            openHomeSettings()
        }
        result.success(isDefaultLauncher())
    }

    private fun openHomeSettings() {
        attempt { startActivity(Intent(Settings.ACTION_HOME_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }

    private fun isDefaultLauncher(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = getSystemService(RoleManager::class.java)
            if (roles.isRoleAvailable(RoleManager.ROLE_HOME)) return roles.isRoleHeld(RoleManager.ROLE_HOME)
        }
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
        return resolved?.activityInfo?.packageName == packageName
    }

    companion object {
        private const val CHANNEL = "launcher/native"
        private const val REQUEST_DEFAULT = 1
    }
}
