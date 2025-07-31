// D:\AndroidStudioProject\moely\app\src\main\java\link\moely\mobile\MainActivity.java

package link.moely.mobile;

import android.annotation.SuppressLint;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.JavascriptInterface;
import android.webkit.URLUtil;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ProgressBar;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.webkit.WebViewCompat;
import androidx.core.content.ContextCompat;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;

import com.google.android.material.bottomnavigation.BottomNavigationView;

import java.io.File;
import android.Manifest;

public class MainActivity extends AppCompatActivity {

    private WebView webView;
    private ProgressBar progressBar;
    private BottomNavigationView bottomNavigationView;
    private SharedPreferences prefs; // 用于获取下载目录偏好设置
    private ActivityResultLauncher<String[]> requestPermissionLauncher;
    private static final String PREFS_NAME = "MoelyAppPrefs";
    private static final String PREF_DOWNLOAD_DIRECTORY = "download_directory"; // 下载目录偏好设置键
    private static final String HOME_URL = "https://www.moely.link"; // 您的网站 URL
    private static final int MIN_WEBVIEW_VERSION_CODE = 120; // 所需的最低 WebView 版本
    private static final String TAG = "MoelyMobileWebView"; // Logcat 标签

    // 默认下载子目录名称
    private static final String DEFAULT_DOWNLOAD_SUBDIR = "Moely";
    // 默认公共下载目录的完整路径（用于回退和非 SAF 情况）
    private static final String DEFAULT_PUBLIC_DOWNLOAD_PATH = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS) + File.separator + DEFAULT_DOWNLOAD_SUBDIR;



    @SuppressLint("SetJavaScriptEnabled")
@Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // 初始化主题模式
        ThemeModeManager.getInstance(this).initializeTheme();
        
        // 应用动态主题
        ThemeUtils.applyTheme(this);

        // --- Modern Permissions API: register the launcher ---
        requestPermissionLauncher = registerForActivityResult(new ActivityResultContracts.RequestMultiplePermissions(), permissions -> {
            boolean allPermissionsGranted = true;
            for (Boolean granted : permissions.values()) {
                if (!granted) {
                    allPermissionsGranted = false;
                    break;
                }
            }

            if (allPermissionsGranted) {
                Log.d(TAG, "所有请求的存储/媒体权限已授予。初始化 WebView。");
                initializeWebView();
            } else {
                Log.w(TAG, "一个或多个存储/媒体权限被拒绝。WebView 将不会加载。");
                Toast.makeText(this, "存储/媒体权限被拒绝，应用部分功能可能受限。", Toast.LENGTH_LONG).show();
            }
        });

        webView = findViewById(R.id.webView);
        progressBar = findViewById(R.id.progressBar);
        bottomNavigationView = findViewById(R.id.bottomNavigationView);
        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE); // 初始化 SharedPreferences
        
        // 为 BottomNavigationView 应用主题色
        applyThemeToBottomNavigation();

        // --- 启动时请求权限 ---
        requestStoragePermissions();
    }

    /**
     * 初始化 WebView 设置并加载主页 URL。
     * 此方法应仅在授予必要权限后调用。
     */
    @SuppressLint("SetJavaScriptEnabled")
    private void initializeWebView() {
        Log.d(TAG, "初始化 WebView...");
        WebSettings webSettings = webView.getSettings();
        webSettings.setJavaScriptEnabled(true); // 启用 JavaScript
        webSettings.setDomStorageEnabled(true); // 启用 DOM 存储
        webSettings.setAllowFileAccess(true); // 允许文件访问
        webSettings.setCacheMode(WebSettings.LOAD_DEFAULT); // 使用默认缓存策略
        webSettings.setLoadWithOverviewMode(true); // 以概述模式加载页面
        webSettings.setUseWideViewPort(true); // 使用宽视口
        webSettings.setSupportZoom(true); // 启用缩放支持
        webSettings.setBuiltInZoomControls(true); // 显示内置缩放控件
        webSettings.setDisplayZoomControls(false); // 隐藏屏幕上的缩放控件
        webSettings.setMediaPlaybackRequiresUserGesture(false); // 允许媒体自动播放

        // 启用第三方 Cookie (对某些网站很重要)
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptThirdPartyCookies(webView, true);

        // 添加 JavaScript 接口
        // "Android" 是 JavaScript 中用于调用 Java 方法的对象名称
        webView.addJavascriptInterface(new WebAppInterface(this), "Android");

        // --- WebView 客户端 ---
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                Log.d(TAG, "shouldOverrideUrlLoading: " + url);
                // 处理外部链接或特定方案
                if (url.startsWith("http://") || url.startsWith("https://")) {
                    view.loadUrl(url);
                    return true;
                } else {
                    // 尝试使用外部应用打开其他方案 (例如，mailto, tel)
                    try {
                        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                        startActivity(intent);
                    } catch (Exception e) {
                        runOnUiThread(() -> Toast.makeText(MainActivity.this, "无法打开链接: " + url, Toast.LENGTH_SHORT).show());
                        Log.e(TAG, "打开外部链接失败: " + url, e);
                    }
                    return true;
                }
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                Log.d(TAG, "onPageFinished: " + url);
                progressBar.setVisibility(View.GONE); // 页面加载后隐藏进度条

                // 更新工具栏按钮状态
                boolean canGoBack = webView.canGoBack();
                boolean canGoForward = webView.canGoForward();
                bottomNavigationView.getMenu().findItem(R.id.navigation_back).setEnabled(canGoBack);
                bottomNavigationView.getMenu().findItem(R.id.navigation_forward).setEnabled(canGoForward);
                Log.d(TAG, "onPageFinished - canGoBack: " + canGoBack + ", canGoForward: " + canGoForward);

                // 注入脚本拦截网站下载
                injectDownloadInterceptor(view);

            }

            @Override
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                super.onReceivedError(view, errorCode, description, failingUrl);
                Log.e(TAG, "WebView 错误: " + errorCode + " - " + description + " URL: " + failingUrl);
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "加载页面出错: " + description, Toast.LENGTH_LONG).show());
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                super.onProgressChanged(view, newProgress);
                if (newProgress == 100) {
                    progressBar.setVisibility(View.GONE);
                } else {
                    progressBar.setVisibility(View.VISIBLE);
                    progressBar.setProgress(newProgress);
                }
                Log.d(TAG, "页面进度: " + newProgress);
            }
        });

        // --- 下载监听器 ---
        webView.setDownloadListener(new DownloadListener() {
            @Override
            public void onDownloadStart(String url, String userAgent, String contentDisposition, String mimetype, long contentLength) {
                Log.d(TAG, "开始下载: " + url);
                Log.d(TAG, "User-Agent: " + userAgent);
                Log.d(TAG, "Content-Disposition: " + contentDisposition);
                Log.d(TAG, "MIME Type: " + mimetype);
                Log.d(TAG, "Content Length: " + contentLength);

                // --- 处理常规 HTTP/HTTPS URL ---
                // 注意: Blob URL 下载和 JS 拦截的下载不会进入此流程
                try {
                    DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));

                    String cookies = CookieManager.getInstance().getCookie(url);
                    if (cookies != null && !cookies.isEmpty()) {
                        request.addRequestHeader("cookie", cookies);
                        Log.d(TAG, "添加 Cookie 到下载请求。");
                    }
                    request.addRequestHeader("User-Agent", userAgent);
                    request.setDescription("正在下载文件...");
                    String fileName = URLUtil.guessFileName(url, contentDisposition, mimetype);
                    request.setTitle(fileName);
                    request.allowScanningByMediaScanner();
                    request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);

                    // --- 统一使用公共下载目录和子目录 ---
                    String finalDestinationSubPath = getDownloadDestinationSubPath(prefs.getString(PREF_DOWNLOAD_DIRECTORY, null));
                    request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, finalDestinationSubPath + File.separator + fileName);
                    Log.d(TAG, "下载目标: " + Environment.DIRECTORY_DOWNLOADS + "/" + finalDestinationSubPath + "/" + fileName);

                    DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                    if (dm != null) {
                        long downloadId = dm.enqueue(request);
                        runOnUiThread(() -> Toast.makeText(getApplicationContext(), "开始下载文件: " + fileName, Toast.LENGTH_LONG).show());
                        Log.d(TAG, "下载成功加入队列。下载 ID: " + downloadId);
                    } else {
                        runOnUiThread(() -> Toast.makeText(getApplicationContext(), "下载服务不可用。", Toast.LENGTH_LONG).show());
                        Log.e(TAG, "DownloadManager 服务为空。");
                    }
                } catch (Exception e) {
                    runOnUiThread(() -> Toast.makeText(getApplicationContext(), "下载失败: " + e.getMessage(), Toast.LENGTH_LONG).show());
                    Log.e(TAG, "启动下载时出错: " + e.getMessage(), e);
                }
            }
        });

        // --- 加载 URL ---
        webView.loadUrl(HOME_URL);
        Log.d(TAG, "加载初始 URL: " + HOME_URL);

        // --- 底部导航栏监听器 ---
        bottomNavigationView.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == R.id.navigation_back) {
                if (webView.canGoBack()) {
                    Log.d(TAG, "导航回退。");
                    webView.goBack();
                } else {
                    Toast.makeText(MainActivity.this, "已是第一页", Toast.LENGTH_SHORT).show();
                    Log.d(TAG, "无法回退，已是第一页。");
                }
                return false;
            } else if (id == R.id.navigation_forward) {
                if (webView.canGoForward()) {
                    Log.d(TAG, "导航前进。");
                    webView.goForward();
                } else {
                    Toast.makeText(MainActivity.this, "已是最后一页", Toast.LENGTH_SHORT).show();
                    Log.d(TAG, "无法前进，已是最后一页。");
                }
                return false;
            } else if (id == R.id.navigation_refresh) {
                Log.d(TAG, "刷新页面。");
                webView.reload();
                return false;
            } else if (id == R.id.navigation_download) {
                Log.d(TAG, "打开下载活动。");
                startActivity(new Intent(MainActivity.this, DownloadsActivity.class));
                return false;
            } else if (id == R.id.navigation_settings) {
                Log.d(TAG, "打开设置活动。");
                startActivity(new Intent(MainActivity.this, SettingsActivity.class));
                return false;
            }
            return false;
        });

        // 导航按钮的初始状态 (暂时启用以测试点击事件)
        // 实际启用/禁用逻辑将在 onPageFinished 中根据 WebView 历史记录更新
        bottomNavigationView.getMenu().findItem(R.id.navigation_back).setEnabled(true);
        bottomNavigationView.getMenu().findItem(R.id.navigation_forward).setEnabled(true);
        Log.d(TAG, "初始按钮状态: 回退和前进已启用以供测试。");

        // --- 强制取消选择 BottomNavigationView 中的默认选中项 ---
        bottomNavigationView.setSelectedItemId(View.NO_ID);
        Log.d(TAG, "强制 BottomNavigationView 没有选中项。");

        // --- WebView 版本检查 ---
        checkWebViewVersion();
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            Log.d(TAG, "按下返回按钮，WebView 回退。");
            webView.goBack();
        } else {
            Log.d(TAG, "按下返回按钮，没有 WebView 历史记录，调用 super.onBackPressed()。");
            super.onBackPressed();
        }
    }

    /**
     * 检查 Android 系统 WebView 的版本。
     * 如果版本低于 MIN_WEBVIEW_VERSION_CODE，则显示警告对话框。
     */
    private void checkWebViewVersion() {
        PackageInfo webViewPackageInfo = WebViewCompat.getCurrentWebViewPackage(this);
        if (webViewPackageInfo != null) {
            long currentWebViewVersionCode = 0;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                currentWebViewVersionCode = webViewPackageInfo.getLongVersionCode();
            } else {
                currentWebViewVersionCode = webViewPackageInfo.versionCode;
            }
            Log.d(TAG, "当前 WebView 版本: " + webViewPackageInfo.versionName + " (代码: " + currentWebViewVersionCode + ")");

            if (currentWebViewVersionCode < MIN_WEBVIEW_VERSION_CODE) {
                new AlertDialog.Builder(this)
                        .setTitle(R.string.webview_version_warning_title)
                        .setMessage(getString(R.string.webview_version_warning_message, webViewPackageInfo.versionName))
                        .setPositiveButton(R.string.update_webview, (dialog, which) -> {
                            try {
                                startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.google.android.webview")));
                            } catch (android.content.ActivityNotFoundException anfe) {
                                startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.webview")));
                            }
                        })
                        .setNegativeButton(R.string.dismiss, (dialog, which) -> dialog.dismiss())
                        .show();
                Log.w(TAG, "WebView 版本过低，显示警告对话框。");
            }
        } else {
            runOnUiThread(() -> Toast.makeText(this, "无法检测到 Android System WebView。", Toast.LENGTH_LONG).show());
            Log.e(TAG, "无法检测到 Android System WebView 包。");
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        
        // 检查并应用最新的主题模式设置
        ThemeModeManager themeModeManager = ThemeModeManager.getInstance(this);
        int savedMode = themeModeManager.getThemeMode();
        
        // 获取当前主题模式进行平滑切换
        int nightMode;
        switch (savedMode) {
            case ThemeModeManager.MODE_LIGHT:
                nightMode = androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_NO;
                break;
            case ThemeModeManager.MODE_DARK:
                nightMode = androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_YES;
                break;
            case ThemeModeManager.MODE_SYSTEM:
            default:
                nightMode = androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM;
                break;
        }
        
        // 应用到当前Activity的Delegate，实现平滑切换
        getDelegate().setLocalNightMode(nightMode);
        
        // 重新应用主题（以防主题在其他Activity中被更改）
        ThemeUtils.applyTheme(this);
        applyThemeToBottomNavigation();
        
        // 仅在 WebView 未加载任何内容时尝试重新请求权限并初始化 WebView。
        // 避免在每次 Activity 恢复时都重新加载页面。
        if (webView.getUrl() == null) {
            Log.d(TAG, "Activity 恢复，WebView 未初始化。重新请求权限。");
            requestStoragePermissions();
        } else {
            Log.d(TAG, "Activity 恢复，WebView 已加载。不进行页面重载。");
        }
    }

    /**
     * 根据 Android 版本在运行时请求必要的存储权限。
     * 此方法根据用户的请求专门为 Android 10+ 设备定制。
     */
    private void requestStoragePermissions() {
        String[] permissionsToRequest;

        Log.d(TAG, "开始检查 Android " + Build.VERSION.SDK_INT + " 的权限...");

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) { // Android 13 (API 33) 及以上
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO,
                    Manifest.permission.READ_MEDIA_AUDIO
            };
        } else { // Android 12 (API 32) 及以下
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
            };
        }
        
        boolean allGranted = true;
        for (String permission : permissionsToRequest) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                allGranted = false;
                break;
            }
        }

        if (allGranted) {
            Log.d(TAG, "所有必需的权限已授予。初始化 WebView。");
            initializeWebView();
        } else {
            Log.d(TAG, "并非所有必需的权限都已授予。现在请求它们。");
            requestPermissionLauncher.launch(permissionsToRequest);
        }
    }


    /**
     * JavaScript 接口，用于从 WebView 接收数据。
     */
    public class WebAppInterface {
        Context mContext;
        private SharedPreferences prefs; // WebAppInterface 内部的 SharedPreferences 实例

        WebAppInterface(Context c) {
            mContext = c;
            // 在 WebAppInterface 构造函数中初始化 prefs
            prefs = c.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        }

        /**
         * 通过拦截器进行下载
         */
        @JavascriptInterface
        public void startDownload(String url, String contentDisposition, String mimetype) {
            Log.d(TAG, "startDownload: 通过 JS 拦截器启动下载: " + url);
            // 在主线程上执行下载操作
            runOnUiThread(() -> {
                try {
                    DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                    String cookies = CookieManager.getInstance().getCookie(url);
                    if (cookies != null && !cookies.isEmpty()) {
                        request.addRequestHeader("cookie", cookies);
                    }
                    request.addRequestHeader("User-Agent", webView.getSettings().getUserAgentString());
                    request.setDescription("正在下载文件...");
                    String fileName = URLUtil.guessFileName(url, contentDisposition, mimetype);
                    request.setTitle(fileName);
                    request.allowScanningByMediaScanner();
                    request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);

                    String finalDestinationSubPath = getDownloadDestinationSubPath(prefs.getString(PREF_DOWNLOAD_DIRECTORY, null));
                    request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, finalDestinationSubPath + File.separator + fileName);

                    DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                    if (dm != null) {
                        dm.enqueue(request);
                        Toast.makeText(getApplicationContext(), "开始下载文件: " + fileName, Toast.LENGTH_LONG).show();
                    } else {
                        Toast.makeText(getApplicationContext(), "下载服务不可用。", Toast.LENGTH_LONG).show();
                    }
                } catch (Exception e) {
                    Toast.makeText(getApplicationContext(), "下载失败: " + e.getMessage(), Toast.LENGTH_LONG).show();
                    Log.e(TAG, "从 JS 拦截器启动下载时出错: ", e);
                }
            });
        }

        /**
         * 从 JavaScript 记录错误消息。
         * 此方法通过 Android.logError() 从 JavaScript 调用。
         * @param message JavaScript 中的错误消息。
         */
        @JavascriptInterface
        public void logError(String message) {
            Log.e(TAG, "JavaScript 错误: " + message);
            // 或者，您可以在此处显示 Toast 或对话框以显示关键错误
            // runOnUiThread(() -> Toast.makeText(mContext, "JavaScript Error: " + message, Toast.LENGTH_LONG).show());
        }
    }

    /**
     * 根据存储的偏好设置获取下载目标子路径。
     * 优先使用用户选择的文件夹（如果它是公共下载目录下的文件路径）。
     * 如果是 SAF URI 或其他非标准路径，则回退到默认子目录。
     * 此方法在 MainActivity 内部，因此 WebAppInterface 需要通过 MainActivity 实例调用或复制此逻辑。
     * 为了简化和避免重复代码，这里让 WebAppInterface 访问 MainActivity 的 prefs，并直接调用此私有方法。
     * @param customDownloadDirectoryUriString 从 SharedPreferences 获取的自定义下载目录 URI 字符串。
     * @return 最终的下载目标子路径（例如 "Moely" 或 "MyCustomFolder"）。
     */
    private String getDownloadDestinationSubPath(String customDownloadDirectoryUriString) {
        String finalDestinationSubPath = DEFAULT_DOWNLOAD_SUBDIR; // 默认回退

        Log.d(TAG, "getDownloadDestinationSubPath: Processing customDownloadDirectoryUriString: " + customDownloadDirectoryUriString);

        if (customDownloadDirectoryUriString != null && !customDownloadDirectoryUriString.isEmpty()) {
            try {
                Uri customUri = Uri.parse(customDownloadDirectoryUriString);
                Log.d(TAG, "Parsed custom URI scheme: " + customUri.getScheme() + ", path: " + customUri.getPath());

                if (customUri.getScheme() != null && customUri.getScheme().equals("file")) {
                    File customSelectedDir = new File(customUri.getPath());
                    String downloadsPath = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).getAbsolutePath();

                    // 检查自定义路径是否在标准下载目录内
                    if (customSelectedDir.getAbsolutePath().startsWith(downloadsPath)) {
                        String relativePath = customSelectedDir.getAbsolutePath().substring(downloadsPath.length());
                        // 移除前导文件分隔符（如果存在）
                        if (relativePath.startsWith(File.separator)) {
                            relativePath = relativePath.substring(File.separator.length());
                        }
                        // 确保相对路径不为空（例如，如果用户选择了 Downloads 根目录）
                        if (!relativePath.isEmpty()) {
                            finalDestinationSubPath = relativePath;
                        }
                        Log.d(TAG, "自定义文件路径在 Downloads 内。相对路径: " + finalDestinationSubPath);
                    } else {
                        // 如果自定义路径不在标准 Downloads 目录内，仍使用默认公共 Downloads/Moely。
                        Log.w(TAG, "自定义文件路径不在标准 Downloads 目录内。回退到默认公共 Downloads/Moely。");
                    }
                } else if (customUri.getScheme() != null && customUri.getScheme().equals("content")) {
                    // 对于 content:// URI，尝试获取 document ID 来解析更具体的路径
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        String documentId = android.provider.DocumentsContract.getTreeDocumentId(customUri);
                        Log.d(TAG, "getDownloadDestinationSubPath: Document ID for content URI: " + documentId);

                        if (documentId != null) {
                            // 处理主外部存储 (primary)
                            if (documentId.startsWith("primary:")) {
                                String relativePath = documentId.substring("primary:".length());
                                relativePath = Uri.decode(relativePath); // 解码 URL 编码字符
                                // 如果是 Downloads 目录本身或其子目录
                                if (relativePath.equals(Environment.DIRECTORY_DOWNLOADS)) {
                                    finalDestinationSubPath = DEFAULT_DOWNLOAD_SUBDIR; // 如果选择了 Downloads 根目录，仍使用默认子目录
                                } else if (relativePath.startsWith(Environment.DIRECTORY_DOWNLOADS + "/")) {
                                    finalDestinationSubPath = relativePath.substring(Environment.DIRECTORY_DOWNLOADS.length() + 1);
                                } else {
                                    // 其他 primary 存储路径
                                    finalDestinationSubPath = relativePath;
                                }
                                Log.d(TAG, "Resolved primary content URI to relative path: " + finalDestinationSubPath);
                            } else if (documentId.contains(":")) {
                                // 处理其他文档提供者 (例如 SD 卡)
                                String[] parts = documentId.split(":");
                                if (parts.length == 2) {
                                    String folderPath = parts[1];
                                    finalDestinationSubPath = folderPath; // 使用文档 ID 中的文件夹路径
                                }
                                Log.d(TAG, "Resolved non-primary content URI to relative path: " + finalDestinationSubPath);
                            } else {
                                Log.w(TAG, "无法从 document ID 解析出明确的相对路径。回退到默认公共 Downloads/Moely。");
                            }
                        } else {
                            Log.w(TAG, "SAF URI 的 document ID 为空。回退到默认公共 Downloads/Moely。");
                        }
                    } else {
                        Log.w(TAG, "自定义下载目录是 SAF URI (content://) 且 Android 版本过低。回退到默认公共 Downloads/Moely。");
                    }
                } else {
                    // 假设它是一个可能在标准公共目录之外的直接路径字符串。
                    // 为了简单性和可靠性，回退到默认公共 Downloads/Moely。
                    Log.w(TAG, "自定义下载目录是一个非标准路径。回退到默认公共 Downloads/Moely。");
                }
            } catch (Exception e) {
                Log.e(TAG, "解析自定义下载目录 URI 时出错: " + e.getMessage(), e);
                // 解析失败时回退到默认
                finalDestinationSubPath = DEFAULT_DOWNLOAD_SUBDIR;
            }
        }
        Log.d(TAG, "Final download subdirectory determined: " + finalDestinationSubPath);
        return finalDestinationSubPath;
    }

    private void injectDownloadInterceptor(WebView webView) {
        String script = "javascript:(" +
                "function() { " +
                "    if (typeof window.downloadImg_original === 'undefined') { " +
                "        window.downloadImg_original = window.downloadImg;" +
                "        window.downloadImg = function(textId, imgId, url) { " +
                "            console.log('Intercepted downloadImg call. URL: ' + url);" +
                "            if (window.Android && typeof window.Android.startDownload === 'function') { " +
                "                window.Android.startDownload(url, '', '');" +
                "            } else { " +
                "                console.log('Android.startDownload not found, falling back to original.');" +
                "                window.downloadImg_original(textId, imgId, url);" +
                "            } " +
                "        }; " +
                "        console.log('downloadImg function intercepted.'); " +
                "    } " +
                "})();";
        webView.evaluateJavascript(script, null);
        Log.d(TAG, "已注入 downloadImg 拦截脚本。");
    }
    
    /**
     * 为 BottomNavigationView 应用主题色
     */
    private void applyThemeToBottomNavigation() {
        ThemeManager themeManager = ThemeManager.getInstance(this);
        int primaryColor = themeManager.getPrimaryColor();
        
        // 创建颜色状态列表用于图标着色
        android.content.res.ColorStateList colorStateList = android.content.res.ColorStateList.valueOf(primaryColor);
        bottomNavigationView.setItemIconTintList(colorStateList);
        bottomNavigationView.setItemTextColor(colorStateList);
        
        // 为 ProgressBar 应用主题色
        if (progressBar != null) {
            progressBar.getProgressDrawable().setTint(primaryColor);
        }
    }
    
    /**
     * 检查并请求存储权限以支持动态颜色提取
     */
    public void checkAndRequestStoragePermission() {
        String[] permissionsToRequest;
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) { // Android 13 (API 33) 及以上
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_MEDIA_IMAGES
            };
        } else { // Android 12 (API 32) 及以下
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_EXTERNAL_STORAGE
            };
        }
        
        boolean allGranted = true;
        for (String permission : permissionsToRequest) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                allGranted = false;
                break;
            }
        }
        
        if (!allGranted) {
            // 直接请求权限
            requestPermissionLauncher.launch(permissionsToRequest);
            Log.d(TAG, "Requesting media permissions for dynamic color extraction.");
        } else {
            Log.i(TAG, "Media permissions already granted for dynamic color extraction.");
        }
    }
}
