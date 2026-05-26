package link.moely.mobile;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.annotations.SerializedName;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class UpdateChecker {

    private static final String TAG = "MoelyUpdate"; // 更新 Logcat 标签
    private static final String UPDATE_URL = "https://mobile.moely.link/app/version.txt"; // 您的更新 JSON URL
    private static final String FIXED_DOWNLOAD_URL = "https://mobile.moely.link/"; // 固定下载链接
    private Context context;
    private OnUpdateCheckListener listener;
    private ExecutorService executorService;
    private Handler mainHandler;

    public interface OnUpdateCheckListener {
        void onUpdateCheckComplete(UpdateInfo updateInfo);
        void onUpdateCheckFailed(String errorMessage);
    }

    public UpdateChecker(Context context, OnUpdateCheckListener listener) {
        this.context = context.getApplicationContext(); // Use application context to prevent leaks
        this.listener = listener;
        this.executorService = Executors.newSingleThreadExecutor();
        this.mainHandler = new Handler(Looper.getMainLooper()); // Initialize Handler for UI thread
    }

    /**
     * 在后台线程中启动更新检查过程。
     */
    public void checkForUpdates() {
        executorService.execute(() -> {
            HttpURLConnection connection = null; // Declare connection outside try block
            try {
                URL url = new URL(UPDATE_URL);
                connection = (HttpURLConnection) url.openConnection(); // Assign value here
                connection.setRequestMethod("GET");
                connection.setConnectTimeout(5000);
                connection.setReadTimeout(5000);

                int responseCode = connection.getResponseCode();
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
                    String remoteVersionString = in.readLine(); // Read the version string directly
                    in.close();

                    UpdateInfo remoteUpdateInfo = new UpdateInfo();
                    remoteUpdateInfo.setLatestVersionName(remoteVersionString != null ? remoteVersionString.trim() : "");
                    remoteUpdateInfo.setDownloadUrl(FIXED_DOWNLOAD_URL); // Set the fixed download URL
                    // releaseNotes will not be available from version.txt

                    // 获取当前应用版本
                    PackageInfo pInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
                    String currentVersionName = pInfo.versionName;
                    // int currentVersionCode = pInfo.versionCode; // 使用 versionCode 进行可靠比较，但此处仅用作参考，不用于比较逻辑

                    // 比较版本
                    if (remoteUpdateInfo != null &&
                        compareVersions(remoteUpdateInfo.latestVersionName, currentVersionName) > 0) {
                        // 有更新可用
                        remoteUpdateInfo.setCurrentVersionName(currentVersionName);
                        remoteUpdateInfo.setUpdateAvailable(true);
                        mainHandler.post(() -> listener.onUpdateCheckComplete(remoteUpdateInfo));
                    } else {
                        // 没有更新可用或远程版本更旧/相同
                        UpdateInfo noUpdateInfo = new UpdateInfo();
                        noUpdateInfo.setUpdateAvailable(false);
                        noUpdateInfo.setCurrentVersionName(currentVersionName);
                        mainHandler.post(() -> listener.onUpdateCheckComplete(noUpdateInfo));
                    }
                } else {
                    mainHandler.post(() -> listener.onUpdateCheckFailed("服务器响应码: " + responseCode));
                }
            } catch (Exception e) {
                Log.e(TAG, "检查更新失败: " + e.getMessage(), e);
                mainHandler.post(() -> listener.onUpdateCheckFailed("网络错误或解析失败: " + e.getMessage()));
            } finally {
                if (connection != null) {
                    connection.disconnect(); // Ensure connection is closed
                }
            }
        });
    }

    /**
     * 比较两个版本字符串 (例如，"1.0.0" 与 "1.0.1")。
     * 返回值:
     * > 0 如果 version1 比 version2 新
     * < 0 如果 version1 比 version2 旧
     * = 0 如果版本相同
     */
    private int compareVersions(String version1, String version2) {
        String[] parts1 = version1.split("\\.");
        String[] parts2 = version2.split("\\.");

        int length = Math.max(parts1.length, parts2.length);
        for (int i = 0; i < length; i++) {
            // Extract only numeric part before parsing to handle suffixes like "-beta"
            String p1 = i < parts1.length ? parts1[i].replaceAll("\\D+", "") : "0";
            String p2 = i < parts2.length ? parts2[i].replaceAll("\\D+", "") : "0";

            int v1 = Integer.parseInt(p1);
            int v2 = Integer.parseInt(p2);

            if (v1 < v2) {
                return -1;
            } else if (v1 > v2) {
                return 1;
            }
        }
        return 0; // 版本相同
    }

    /**
     * 用于保存 JSON 中更新信息的数据类。
     */
    public static class UpdateInfo {
        @SerializedName("latest_version")
        private String latestVersionName;
        @SerializedName("download_url")
        private String downloadUrl;
        @SerializedName("release_notes")
        private String releaseNotes;

        private String currentVersionName; // 不来自 JSON，本地设置
        private boolean isUpdateAvailable; // 不来自 JSON，本地设置

        public String getLatestVersionName() {
            return latestVersionName;
        }

        public void setLatestVersionName(String latestVersionName) {
            this.latestVersionName = latestVersionName;
        }

        public String getDownloadUrl() {
            return downloadUrl;
        }

        public void setDownloadUrl(String downloadUrl) {
            this.downloadUrl = downloadUrl;
        }

        public String getReleaseNotes() {
            return releaseNotes;
        }

        public String getCurrentVersionName() {
            return currentVersionName;
        }

        public void setCurrentVersionName(String currentVersionName) {
            this.currentVersionName = currentVersionName;
        }

        public boolean isUpdateAvailable() {
            return isUpdateAvailable;
        }

        public void setUpdateAvailable(boolean updateAvailable) {
            isUpdateAvailable = updateAvailable;
        }
    }
}
