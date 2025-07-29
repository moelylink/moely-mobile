// D:\AndroidStudioProject\moely\app\src\main\java\link\moely\mobile\SettingsActivity.java

package link.moely.mobile;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.database.Cursor; // Import Cursor
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment; // Import Environment
import android.os.Handler;
import android.os.Looper;
import android.text.format.Formatter;
import android.util.Log;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.WebStorage;
import android.webkit.WebView;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.webkit.WebViewCompat; // Import WebViewCompat
import android.provider.DocumentsContract; // Import DocumentsContract for SAF URI parsing

import com.google.android.material.appbar.MaterialToolbar;

import java.io.File;

public class SettingsActivity extends AppCompatActivity {

    private MaterialToolbar toolbar;
    private Button clearCacheButton;
    private TextView cacheSizeTextView;
    private Button downloadDirectoryButton;
    private TextView currentDownloadDirectoryTextView;
    private Button checkUpdateButton;
    private Button aboutAppButton;

    private SharedPreferences prefs;
    private static final String PREFS_NAME = "MoelyAppPrefs";
    private static final String PREF_DOWNLOAD_DIRECTORY = "download_directory";
    private static final String TAG = "MoelyMobileSettings";

    // Default download subdirectory name
    private static final String DEFAULT_DOWNLOAD_SUBDIR = "Moely";
    // Default download directory's full path (FileProvider cannot directly use)
    private static final String DEFAULT_DOWNLOAD_PATH = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS) + File.separator + DEFAULT_DOWNLOAD_SUBDIR;


    private ActivityResultLauncher<Uri> openDirectoryLauncher;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);

        toolbar = findViewById(R.id.toolbar_settings);
        clearCacheButton = findViewById(R.id.clearCacheButton);
        cacheSizeTextView = findViewById(R.id.cacheSizeTextView);
        downloadDirectoryButton = findViewById(R.id.downloadDirectoryButton);
        currentDownloadDirectoryTextView = findViewById(R.id.currentDownloadDirectoryTextView);
        checkUpdateButton = findViewById(R.id.checkUpdateButton);
        aboutAppButton = findViewById(R.id.aboutAppButton);

        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);

        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setDisplayShowHomeEnabled(true);
        }
        toolbar.setNavigationOnClickListener(v -> onBackPressed());

        // --- 清除缓存 ---
        clearCacheButton.setOnClickListener(v -> {
            clearAppCache();
        });

        // --- 下载目录 ---
        openDirectoryLauncher = registerForActivityResult(new ActivityResultContracts.OpenDocumentTree(), uri -> {
            if (uri != null) {
                // 持久化 URI 权限，以便将来访问
                final int takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION;
                getContentResolver().takePersistableUriPermission(uri, takeFlags);

                // 直接保存 URI 字符串
                String uriString = uri.toString();
                prefs.edit().putString(PREF_DOWNLOAD_DIRECTORY, uriString).apply();
                
                // 获取并显示解析后的路径
                String displayPath = getDisplayPathForUri(uri);
                updateDownloadDirectoryDisplay(uriString); // Update TextView with the resolved display path
                Toast.makeText(this, getString(R.string.directory_set_successfully, displayPath), Toast.LENGTH_LONG).show();
                Log.d(TAG, "Download directory URI set to: " + uriString + ", Display path: " + displayPath);
            } else {
                Toast.makeText(this, R.string.directory_selection_failed, Toast.LENGTH_SHORT).show();
                Log.w(TAG, "Directory selection cancelled or failed.");
            }
        });

        downloadDirectoryButton.setOnClickListener(v -> {
            openDirectoryLauncher.launch(null); // 启动目录选择器
        });

        // 更新当前下载目录显示
        String savedUriString = prefs.getString(PREF_DOWNLOAD_DIRECTORY, null);
        if (savedUriString == null) {
            // If no saved directory, set default directory and save it
            File defaultDir = new File(DEFAULT_DOWNLOAD_PATH);
            if (!defaultDir.exists()) {
                defaultDir.mkdirs(); // Try to create directory
            }
            // Save the default directory's path as a string, not a URI, because DownloadManager needs a path
            prefs.edit().putString(PREF_DOWNLOAD_DIRECTORY, DEFAULT_DOWNLOAD_PATH).apply();
            updateDownloadDirectoryDisplay(DEFAULT_DOWNLOAD_PATH);
            Log.d(TAG, "No custom download directory set, defaulting to: " + DEFAULT_DOWNLOAD_PATH);
        } else {
            updateDownloadDirectoryDisplay(savedUriString);
        }


        // --- 检查更新 ---
        checkUpdateButton.setOnClickListener(v -> {
            Toast.makeText(this, "正在检查更新...", Toast.LENGTH_SHORT).show();
            UpdateChecker updateChecker = new UpdateChecker(this, new UpdateChecker.OnUpdateCheckListener() {
                private Handler handler = new Handler(Looper.getMainLooper());

                @Override
                public void onUpdateCheckComplete(UpdateChecker.UpdateInfo updateInfo) {
                    handler.post(() -> {
                        if (updateInfo.isUpdateAvailable()) {
                            showUpdateDialog(updateInfo);
                        } else {
                            Toast.makeText(SettingsActivity.this, R.string.no_update_available, Toast.LENGTH_SHORT).show();
                        }
                    });
                }

                @Override
                public void onUpdateCheckFailed(String errorMessage) {
                    handler.post(() -> {
                        Toast.makeText(SettingsActivity.this, R.string.update_check_failed, Toast.LENGTH_LONG).show();
                        Log.e(TAG, "更新检查失败: " + errorMessage);
                    });
                }
            });
            updateChecker.checkForUpdates();
        });

        // --- 关于应用 ---
        aboutAppButton.setOnClickListener(v -> {
            showAboutAppDialog();
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        // 每次回到设置页面时更新缓存大小显示
        updateCacheSizeDisplay();
    }

    /**
     * 清除应用程序的缓存数据，不影响网站数据和 Cookies。
     */
    private void clearAppCache() {
        // 清除 WebView 的 HTTP 缓存
        WebView webViewForCache = new WebView(this.getApplicationContext());
        webViewForCache.clearCache(true);
        webViewForCache.clearFormData(); // 清除表单自动填充数据

        // 注意：WebStorage.getInstance().deleteAllData() 和 CookieManager.getInstance().removeAllCookies()
        // 会清除网站数据和 Cookies，导致登录状态丢失。根据用户需求，这里不再调用它们。

        long internalCacheClearedSize = getDirSize(getCacheDir());
        deleteDir(getCacheDir()); // 清除应用的内部缓存目录
        Log.d(TAG, "Cleared internal cache: " + Formatter.formatFileSize(this, internalCacheClearedSize));

        if (getExternalCacheDir() != null) {
            long externalCacheClearedSize = getDirSize(getExternalCacheDir());
            deleteDir(getExternalCacheDir()); // 清除应用的外部缓存目录
            Log.d(TAG, "Cleared external cache: " + Formatter.formatFileSize(this, externalCacheClearedSize));
        }

        Toast.makeText(this, R.string.cache_cleared, Toast.LENGTH_SHORT).show();
        updateCacheSizeDisplay();
    }

    /**
     * 计算目录的大小。
     */
    private long getDirSize(File dir) {
        long size = 0;
        if (dir != null && dir.isDirectory()) {
            for (File file : dir.listFiles()) {
                if (file.isFile()) {
                    size += file.length();
                } else if (file.isDirectory()) {
                    size += getDirSize(file);
                }
            }
        }
        return size;
    }

    /**
     * 递归删除目录及其内容。
     */
    private boolean deleteDir(java.io.File dir) {
        if (dir != null && dir.isDirectory()) {
            String[] children = dir.list();
            for (int i = 0; i < children.length; i++) {
                boolean success = deleteDir(new java.io.File(dir, children[i]));
                if (!success) {
                    return false;
                }
            }
        }
        return dir.delete();
    }

    /**
     * 更新缓存大小的显示。
     */
    private void updateCacheSizeDisplay() {
        long totalCacheSize = getDirSize(getCacheDir());
        if (getExternalCacheDir() != null) {
            totalCacheSize += getDirSize(getExternalCacheDir());
        }
        String formattedSize = Formatter.formatFileSize(this, totalCacheSize);
        cacheSizeTextView.setText(getString(R.string.cache_size_placeholder, formattedSize));
        Log.d(TAG, "Current cache size: " + formattedSize);
    }

    /**
     * 更新下载目录的显示。
     * 直接显示 URI 字符串或其一个友好名称。
     */
    private void updateDownloadDirectoryDisplay(String uriString) {
        if (uriString != null && !uriString.isEmpty()) {
            // 尝试解析为 URI，然后获取显示名称
            Uri uri = Uri.parse(uriString);
            String displayPath = getDisplayPathForUri(uri);
            currentDownloadDirectoryTextView.setText(getString(R.string.current_download_directory, displayPath));
        } else {
            currentDownloadDirectoryTextView.setText(R.string.directory_not_selected);
        }
    }

    /**
     * 尝试获取 URI 的显示路径字符串。
     * 对于 SAF URI，它会尝试解析为更可识别的文件路径格式，如果它在标准 Downloads 目录内。
     * 否则，它将回退到显示名称或 URI 字符串本身。
     */
    private String getDisplayPathForUri(Uri uri) {
        String displayPath = uri.toString(); // Default fallback to full URI string
        Log.d(TAG, "getDisplayPathForUri: Processing URI: " + uri.toString());

        if (uri.getScheme() != null) {
            if (uri.getScheme().equals("file")) {
                // For file:// URIs, directly use the path
                displayPath = uri.getPath();
                Log.d(TAG, "getDisplayPathForUri: File URI, path: " + displayPath);
            } else if (uri.getScheme().equals("content")) {
                Log.d(TAG, "getDisplayPathForUri: Content URI, path: " + uri.getPath());
                String displayNameFromCursor = null;
                try {
                    // 1. Try to get DISPLAY_NAME from ContentResolver (often the most user-friendly folder name)
                    try (Cursor cursor = getContentResolver().query(uri, null, null, null, null)) {
                        if (cursor != null && cursor.moveToFirst()) {
                            int nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME);
                            if (nameIndex != -1) {
                                displayNameFromCursor = cursor.getString(nameIndex);
                                Log.d(TAG, "getDisplayPathForUri: Content URI, DISPLAY_NAME from cursor: " + displayNameFromCursor);
                            }
                        }
                    }

                    // 2. Attempt to resolve SAF URI to a more recognizable path if it's in public storage
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        String documentId = DocumentsContract.getTreeDocumentId(uri);
                        Log.d(TAG, "getDisplayPathForUri: Document ID: " + documentId);

                        if (documentId != null) {
                            // Common case: primary external storage
                            if (documentId.startsWith("primary:")) {
                                String relativePath = documentId.substring("primary:".length());
                                // Decode URL-encoded characters like %2F back to /
                                relativePath = Uri.decode(relativePath);
                                displayPath = "/storage/emulated/0/" + relativePath;
                                Log.d(TAG, "getDisplayPathForUri: Resolved primary storage path: " + displayPath);
                            }
                            // Handle other common document providers (e.g., SD cards, USB drives)
                            else if (documentId.contains(":")) {
                                String[] parts = documentId.split(":");
                                if (parts.length == 2) {
                                    String volumeId = parts[0];
                                    String folderPath = parts[1];
                                    // A very basic attempt to make it more readable for external volumes
                                    if (volumeId.matches("[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}")) { // Common format for SD card IDs
                                        displayPath = "SD Card/" + folderPath;
                                    } else {
                                        // Generic fallback for other volume IDs
                                        displayPath = volumeId + "/" + folderPath;
                                    }
                                    Log.d(TAG, "getDisplayPathForUri: Resolved non-primary document ID: " + displayPath);
                                } else {
                                    // Fallback if split doesn't work as expected
                                    displayPath = documentId;
                                    Log.d(TAG, "getDisplayPathForUri: Fallback for complex document ID: " + displayPath);
                                }
                            } else {
                                // Fallback for document IDs that don't match known patterns, use display name if available
                                if (displayNameFromCursor != null && !displayNameFromCursor.isEmpty()) {
                                    displayPath = displayNameFromCursor;
                                    Log.d(TAG, "getDisplayPathForUri: Fallback to DISPLAY_NAME for unknown document ID pattern: " + displayPath);
                                } else {
                                    // Last resort, use the documentId itself
                                    displayPath = documentId;
                                    Log.d(TAG, "getDisplayPathForUri: Fallback to document ID: " + displayPath);
                                }
                            }
                        } else {
                            // If documentId is null, fall back to display name or original URI
                            if (displayNameFromCursor != null && !displayNameFromCursor.isEmpty()) {
                                displayPath = displayNameFromCursor;
                                Log.d(TAG, "getDisplayPathForUri: Document ID is null, falling back to DISPLAY_NAME: " + displayPath);
                            } else {
                                displayPath = uri.toString();
                                Log.d(TAG, "getDisplayPathForUri: Document ID and DISPLAY_NAME null, falling back to original URI: " + displayPath);
                            }
                        }
                    } else {
                        // For older Android versions (<Lollipop), no DocumentsContract.getTreeDocumentId
                        if (displayNameFromCursor != null && !displayNameFromCursor.isEmpty()) {
                            displayPath = displayNameFromCursor;
                            Log.d(TAG, "getDisplayPathForUri: Old Android, falling back to DISPLAY_NAME: " + displayPath);
                        } else {
                            displayPath = uri.toString();
                            Log.d(TAG, "getDisplayPathForUri: Old Android, falling back to original URI: " + displayPath);
                        }
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error getting display path for content URI: " + uri.toString(), e);
                    // If parsing fails, fall back to original URI string
                    displayPath = uri.toString();
                }
            }
        }
        Log.d(TAG, "getDisplayPathForUri: Final display path: " + displayPath);
        return displayPath;
    }


    /**
     * 当有更新可用时显示对话框。
     */
    private void showUpdateDialog(UpdateChecker.UpdateInfo updateInfo) {
        new AlertDialog.Builder(this)
                .setTitle(R.string.update_available_title)
                .setMessage(getString(R.string.update_available_message,
                        updateInfo.getCurrentVersionName(),
                        updateInfo.getLatestVersionName()))
                .setPositiveButton(R.string.update_now, (dialog, which) -> {
                    // 打开下载 URL
                    if (updateInfo.getDownloadUrl() != null && !updateInfo.getDownloadUrl().isEmpty()) {
                        try {
                            Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(updateInfo.getDownloadUrl()));
                            startActivity(browserIntent);
                        } catch (Exception e) {
                            Toast.makeText(this, "无法打开下载链接。", Toast.LENGTH_SHORT).show();
                            Log.e(TAG, "Failed to open download URL: " + updateInfo.getDownloadUrl(), e);
                        }
                    } else {
                        Toast.makeText(this, "下载链接不可用。", Toast.LENGTH_SHORT).show();
                        Log.w(TAG, "Download URL is null or empty.");
                    }
                })
                .setNegativeButton(R.string.later, (dialog, which) -> dialog.dismiss())
                .show();
    }

    /**
     * 显示关于应用的对话框。
     */
    private void showAboutAppDialog() {
        String appVersion = "未知";
        String webViewVersion = "未知";
        String androidVersion = Build.VERSION.RELEASE; // 获取 Android 系统版本号

        try {
            PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
            appVersion = pInfo.versionName;
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "无法获取应用版本: " + e.getMessage());
        }

        PackageInfo webViewPackageInfo = WebViewCompat.getCurrentWebViewPackage(this);
        if (webViewPackageInfo != null) {
            webViewVersion = webViewPackageInfo.versionName;
        } else {
            Log.e(TAG, "无法检测到 Android System WebView 包。");
        }

        String message = getString(R.string.app_version, appVersion) + "\n" +
                         getString(R.string.webview_version, webViewVersion) + "\n" +
                         getString(R.string.android_version, androidVersion); // 添加 Android 版本号

        new AlertDialog.Builder(this)
                .setTitle(R.string.about_app)
                .setMessage(message)
                .setPositiveButton(android.R.string.ok, (dialog, which) -> dialog.dismiss())
                .show();
    }
}
