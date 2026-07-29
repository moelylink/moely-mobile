package link.moely.mobile

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

fun getUserAgent(context: Context): String {
    val versionName = try {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, 0)
        }
        packageInfo.versionName ?: "1.0.0"
    } catch (e: Exception) {
        "1.0.0"
    }
    return "MoelyMobile/$versionName"
}
