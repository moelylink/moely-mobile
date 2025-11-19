package link.moely.mobile;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ProgressBar;
import android.widget.Toast;
import android.content.res.ColorStateList;
import android.content.res.Configuration; 
import android.graphics.Color;           

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;
import androidx.webkit.WebSettingsCompat;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.activity.OnBackPressedCallback; 

import com.google.android.material.bottomnavigation.BottomNavigationView;

import java.io.File;

/**
 * MainActivity - 应用主界面（Chromium WebView 增强版）
 * * 主要功能：
 * 1. 完整的 Chromium WebView 集成
 * 2. 文件上传支持（相机/相册）
 * 3. 全屏视频播放支持
 * 4. 地理位置权限处理
 * 5. 音频/视频录制支持
 * 6. SSL 错误处理
 * 7. 页面加载进度显示
 * 8. 下载管理集成
 * 9. JavaScript 交互接口
 * 10. 深色模式自动适配
 * 11. WebRTC 支持
 * 12. 多媒体播放支持
 * 13. 主题色应用于导航栏和进度条
 * 14. 迁移到 OnBackPressedDispatcher 处理返回手势
 * 15. 底部导航栏 Ripple 颜色根据深浅模式分离
 * 16. 【修复】确保 WebView 在配置完成后才进行首次 URL 加载
 */

public class MainActivity extends BaseActivity {

    private static final String TAG = "MoelyMobileWebView";
    
    // SharedPreferences 配置
    private static final String PREFS_NAME = "MoelyAppPrefs";
    private static final String PREF_DOWNLOAD_DIRECTORY = "download_directory";
    
    // WebView 配置
    private static final String HOME_URL = "https://www.moely.link";
    private static final int MIN_WEBVIEW_VERSION_CODE = 120;
    private static final String DEFAULT_DOWNLOAD_SUBDIR = "Moely";
    
    // 【新增】用于存储首次加载的 URL，解决首次加载时机问题
    private String initialLoadUrl = HOME_URL; 
    
    // UI 组件
    private WebView webView;
    private ProgressBar progressBar;
    private BottomNavigationView bottomNavigationView;
    private FrameLayout fullscreenContainer;
    private View customView;
    
    // 其他组件
    private SharedPreferences prefs;
    private ActivityResultLauncher<String[]> requestPermissionLauncher;
    private ValueCallback<Uri[]> fileUploadCallback;
    private ActivityResultLauncher<Intent> fileChooserLauncher;
    
    // 全屏视频相关
    private WebChromeClient.CustomViewCallback customViewCallback;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // 初始化 UI 组件
        initializeViews();
        
        // 初始化 SharedPreferences
        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        
        // 注册权限请求启动器
        registerPermissionLaunchers();
        
        // 注册文件选择器启动器
        registerFileChooserLauncher();

        // 【核心修复步骤 1：在请求权限前，确定初始 URL】
        // 确定是默认主页还是深度链接 URL
        String determinedUrl = determineInitialUrl(getIntent()); 
        if (determinedUrl != null) {
            initialLoadUrl = determinedUrl;
        } else {
            initialLoadUrl = HOME_URL;
        }
        Log.d(TAG, "首次加载URL已确定: " + initialLoadUrl);

        // 请求必要权限并初始化 WebView。
        // initializeWebView() 的调用被包装在权限回调中，以确保权限请求已启动/完成。
        requestStoragePermissions();

        // 应用主题色到导航栏和进度条
        applyThemeToBottomNavigation();
        
        // 【核心修复步骤 2：移除这里对 handleDeepLink 的调用，避免在 WebView 未配置完成前加载 URL】
        // handleDeepLink(getIntent()); // 已移除

        // 迁移到 OnBackPressedDispatcher
        setupOnBackPressedCallback();
    }

    /**
     * 设置新的返回按钮处理回调
     */
    private void setupOnBackPressedCallback() {
        OnBackPressedCallback callback = new OnBackPressedCallback(true /* enabled */) {
            @Override
            public void handleOnBackPressed() {
                // 如果在全屏视频模式，先退出全屏
                if (customView != null) {
                    webView.getWebChromeClient().onHideCustomView();
                    return;
                }

                // 如果 WebView 可以后退，则后退
                if (webView.canGoBack()) {
                    Log.d(TAG, "WebView 后退");
                    webView.goBack();
                } else {
                    Log.d(TAG, "退出应用");
                    // 无法后退时，关闭 Activity
                    finish();
                }
            }
        };
        // 将回调添加到分发器
        getOnBackPressedDispatcher().addCallback(this, callback);
        Log.d(TAG, "OnBackPressedCallback 已注册。");
    }

    /**
     * 初始化所有视图组件
     */
    private void initializeViews() {
        webView = findViewById(R.id.webView);
        progressBar = findViewById(R.id.progressBar);
        bottomNavigationView = findViewById(R.id.bottomNavigationView);
        
        // 创建全屏容器（用于全屏视频）
        fullscreenContainer = new FrameLayout(this);
        fullscreenContainer.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));
        fullscreenContainer.setBackgroundColor(getResources().getColor(android.R.color.black));
        fullscreenContainer.setVisibility(View.GONE);
        
        // 将全屏容器添加到根布局
        ViewGroup rootView = findViewById(android.R.id.content);
        rootView.addView(fullscreenContainer);
    }

    /**
     * 注册权限请求启动器
     */
    private void registerPermissionLaunchers() {
        requestPermissionLauncher = registerForActivityResult(
                new ActivityResultContracts.RequestMultiplePermissions(),
                permissions -> {
                    boolean allPermissionsGranted = true;
                    for (Boolean granted : permissions.values()) {
                        if (!granted) {
                            allPermissionsGranted = false;
                            break;
                        }
                    }

                    if (allPermissionsGranted) {
                        Log.d(TAG, "所有请求的权限已授予");
                        initializeWebView();
                    } else {
                        Log.w(TAG, "部分权限被拒绝");
                        Toast.makeText(this, "部分权限被拒绝，某些功能可能无法使用", Toast.LENGTH_LONG).show();
                        // 即使权限被拒绝，也尝试初始化 WebView
                        initializeWebView();
                    }
                }
        );
    }

    /**
     * 注册文件选择器启动器
     */
    private void registerFileChooserLauncher() {
        fileChooserLauncher = registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    if (fileUploadCallback == null) return;
                    
                    Uri[] results = null;
                    if (result.getResultCode() == RESULT_OK && result.getData() != null) {
                        String dataString = result.getData().getDataString();
                        if (dataString != null) {
                            results = new Uri[]{Uri.parse(dataString)};
                        }
                    }
                    
                    fileUploadCallback.onReceiveValue(results);
                    fileUploadCallback = null;
                }
        );
    }

    /**
     * 初始化 WebView 设置 - Chromium 内核核心配置
     * 【修复：现在确保在所有设置完成后，才加载 initialLoadUrl】
     */
    @SuppressLint("SetJavaScriptEnabled")
    private void initializeWebView() {
        Log.d(TAG, "初始化 Chromium WebView...");
        
        WebSettings webSettings = webView.getSettings();
        webView.setBackgroundColor(Color.TRANSPARENT); // 强制使用透明背景
        
        // ===== JavaScript 支持 =====
        webSettings.setJavaScriptEnabled(true);
        webSettings.setJavaScriptCanOpenWindowsAutomatically(true);
        
        // ===== DOM 存储和数据库 =====
        webSettings.setDomStorageEnabled(true);
        webSettings.setDatabaseEnabled(true);
        
        // ===== 文件访问 =====
        webSettings.setAllowFileAccess(true);
        webSettings.setAllowContentAccess(true);
        
        // ===== 缓存策略 =====
        webSettings.setCacheMode(WebSettings.LOAD_DEFAULT);
        
        // ===== 视口和缩放 =====
        webSettings.setLoadWithOverviewMode(true);
        webSettings.setUseWideViewPort(true);
        webSettings.setSupportZoom(true);
        webSettings.setBuiltInZoomControls(true);
        webSettings.setDisplayZoomControls(false);
        
        // ===== 媒体播放 =====
        webSettings.setMediaPlaybackRequiresUserGesture(false);
        
        // ===== 文本缩放 =====
        webSettings.setTextZoom(100);
        webView.setInitialScale(0);
        
        // ===== 混合内容模式 =====
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            webSettings.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);
        }
        
        // ===== 安全浏览 =====
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            webSettings.setSafeBrowsingEnabled(true);
        }
        
        // ===== 深色模式支持 =====
        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
            int nightMode = getResources().getConfiguration().uiMode 
                    & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
            if (nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES) {
                WebSettingsCompat.setForceDark(webSettings, WebSettingsCompat.FORCE_DARK_ON);
            } else {
                WebSettingsCompat.setForceDark(webSettings, WebSettingsCompat.FORCE_DARK_OFF);
            }
        }
        
        // ===== 深色模式策略 =====
        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK_STRATEGY)) {
            WebSettingsCompat.setForceDarkStrategy(webSettings, 
                    WebSettingsCompat.DARK_STRATEGY_WEB_THEME_DARKENING_ONLY);
        }
        
        // ===== User-Agent =====
        setupCustomUserAgent(webSettings);
        
        // ===== Cookie 管理 =====
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        cookieManager.setAcceptThirdPartyCookies(webView, true);
        
        // ===== JavaScript 接口 =====
        webView.addJavascriptInterface(new WebAppInterface(this), "Android");
        
        // ===== 设置客户端 =====
        setupWebViewClient();
        setupWebChromeClient();
        
        // ===== 下载监听器 =====
        setupDownloadListener();
        
        // ===== 底部导航栏 =====
        setupBottomNavigation();
        
        // ===== 加载主页 - 确保在所有设置完成后加载 initialLoadUrl =====
        webView.loadUrl(initialLoadUrl); // 【使用在 onCreate 中确定的 initialLoadUrl】
        Log.d(TAG, "加载 URL: " + initialLoadUrl);
        
        // ===== 版本检查 =====
        checkWebViewVersion();
    }

    /**
     * 设置自定义 User-Agent
     */
    private void setupCustomUserAgent(WebSettings webSettings) {
        try {
            String originalUserAgent = webSettings.getUserAgentString();
            PackageInfo pInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
            String versionName = pInfo.versionName;
            String customUserAgent = originalUserAgent + " MoelyMobile/" + versionName;
            webSettings.setUserAgentString(customUserAgent);
            Log.d(TAG, "User-Agent: " + customUserAgent);
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "无法获取版本号", e);
        }
    }

    /**
     * 设置 WebViewClient
     */
    private void setupWebViewClient() {
        webView.setWebViewClient(new WebViewClient() {
            
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                String url = request.getUrl().toString();
                Log.d(TAG, "加载 URL: " + url);
                
                // Google 登录特殊处理
                if (url.contains("google.com")) {
                    view.getSettings().setUserAgentString(System.getProperty("http.agent"));
                } else {
                    setupCustomUserAgent(view.getSettings());
                }
                
                if (url.startsWith("http://") || url.startsWith("https://")) {
                    view.loadUrl(url);
                    return true;
                } else {
                    try {
                        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                        startActivity(intent);
                    } catch (Exception e) {
                        runOnUiThread(() -> 
                            Toast.makeText(MainActivity.this, 
                                "无法打开: " + url, Toast.LENGTH_SHORT).show()
                        );
                        Log.e(TAG, "打开链接失败", e);
                    }
                    return true;
                }
            }

            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                Log.d(TAG, "页面开始加载: " + url);
                progressBar.setVisibility(View.VISIBLE);
                progressBar.setProgress(0);
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                Log.d(TAG, "页面加载完成: " + url);
                progressBar.setVisibility(View.GONE);
                injectDownloadInterceptor(view);
                updateNavigationButtons();
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, 
                    WebResourceError error) {
                super.onReceivedError(view, request, error);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Log.e(TAG, "错误: " + error.getErrorCode() + " - " + error.getDescription());
                }
                if (request.isForMainFrame()) {
                    runOnUiThread(() -> 
                        Toast.makeText(MainActivity.this, 
                            "页面加载失败", Toast.LENGTH_LONG).show()
                    );
                }
            }
        });
    }

    /**
     * 设置 WebChromeClient
     */
    private void setupWebChromeClient() {
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
                
                updateNavigationButtons();
                Log.d(TAG, "进度: " + newProgress + "%");
            }
            
            @Override
            public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback,
                    FileChooserParams fileChooserParams) {
                
                if (fileUploadCallback != null) {
                    fileUploadCallback.onReceiveValue(null);
                }
                
                fileUploadCallback = filePathCallback;
                
                Intent intent = fileChooserParams.createIntent();
                try {
                    fileChooserLauncher.launch(intent);
                } catch (Exception e) {
                    Log.e(TAG, "文件选择失败", e);
                    fileUploadCallback = null;
                    return false;
                }
                
                return true;
            }
            
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin,
                    GeolocationPermissions.Callback callback) {
                
                if (ContextCompat.checkSelfPermission(MainActivity.this,
                        Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    callback.invoke(origin, true, false);
                } else {
                    new AlertDialog.Builder(MainActivity.this)
                        .setTitle("位置权限")
                        .setMessage(origin + " 请求访问位置")
                        .setPositiveButton("允许", (dialog, which) -> {
                            requestPermissionLauncher.launch(new String[]{
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            });
                            callback.invoke(origin, true, false);
                        })
                        .setNegativeButton("拒绝", (dialog, which) -> 
                            callback.invoke(origin, false, false))
                        .show();
                }
            }
            
            @Override
            public void onPermissionRequest(PermissionRequest request) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    runOnUiThread(() -> {
                        new AlertDialog.Builder(MainActivity.this)
                            .setTitle("权限请求")
                            .setMessage("网页请求使用相机或麦克风")
                            .setPositiveButton("允许", (dialog, which) -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                    request.grant(request.getResources());
                                }
                            })
                            .setNegativeButton("拒绝", (dialog, which) -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                    request.deny();
                                }
                            })
                            .show();
                    });
                }
            }
            
            @Override
            public void onShowCustomView(View view, CustomViewCallback callback) {
                if (customView != null) {
                    onHideCustomView();
                    return;
                }
                
                customView = view;
                customViewCallback = callback;
                
                webView.setVisibility(View.GONE);
                bottomNavigationView.setVisibility(View.GONE);
                
                fullscreenContainer.setVisibility(View.VISIBLE);
                fullscreenContainer.addView(customView);
                
                getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_FULLSCREEN |
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                );
                
                Log.d(TAG, "进入全屏");
            }
            
            @Override
            public void onHideCustomView() {
                if (customView == null) return;
                
                webView.setVisibility(View.VISIBLE);
                bottomNavigationView.setVisibility(View.VISIBLE);
                
                fullscreenContainer.setVisibility(View.GONE);
                fullscreenContainer.removeView(customView);
                
                customView = null;
                if (customViewCallback != null) {
                    customViewCallback.onCustomViewHidden();
                    customViewCallback = null;
                }
                
                getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
                
                Log.d(TAG, "退出全屏");
            }
        });
    }

    /**
     * 设置下载监听器
     */
    private void setupDownloadListener() {
        webView.setDownloadListener((url, userAgent, contentDisposition, mimetype, contentLength) -> {
            Log.d(TAG, "下载: " + url);
            
            try {
                DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                
                String cookies = CookieManager.getInstance().getCookie(url);
                if (cookies != null && !cookies.isEmpty()) {
                    request.addRequestHeader("cookie", cookies);
                }
                
                request.addRequestHeader("User-Agent", userAgent);
                request.setDescription("下载中...");
                
                String fileName = URLUtil.guessFileName(url, contentDisposition, mimetype);
                request.setTitle(fileName);
                request.allowScanningByMediaScanner();
                request.setNotificationVisibility(
                        DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                
                // 下载路径解析
                String downloadSubPath = getDownloadDestinationSubPath(
                        prefs.getString(PREF_DOWNLOAD_DIRECTORY, null));
                request.setDestinationInExternalPublicDir(
                        Environment.DIRECTORY_DOWNLOADS, 
                        downloadSubPath + File.separator + fileName);
                
                DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                if (dm != null) {
                    long downloadId = dm.enqueue(request);
                    runOnUiThread(() -> 
                        Toast.makeText(getApplicationContext(), 
                            "开始下载: " + fileName, Toast.LENGTH_LONG).show()
                    );
                    Log.d(TAG, "下载 ID: " + downloadId);
                } else {
                    runOnUiThread(() -> 
                        Toast.makeText(getApplicationContext(), 
                            "下载服务不可用", Toast.LENGTH_LONG).show()
                    );
                }
            } catch (Exception e) {
                runOnUiThread(() -> 
                    Toast.makeText(getApplicationContext(), 
                        "下载失败: " + e.getMessage(), Toast.LENGTH_LONG).show()
                );
                Log.e(TAG, "下载错误", e);
            }
        });
    }

    /**
     * 设置底部导航栏
     */
    private void setupBottomNavigation() {
        bottomNavigationView.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            
            if (id == R.id.navigation_back) {
                if (webView.canGoBack()) {
                    webView.goBack();
                } else {
                    Toast.makeText(this, "已是第一页", Toast.LENGTH_SHORT).show();
                }
                return false;
            } else if (id == R.id.navigation_forward) {
                if (webView.canGoForward()) {
                    webView.goForward();
                } else {
                    Toast.makeText(this, "已是最后一页", Toast.LENGTH_SHORT).show();
                }
                return false;
            } else if (id == R.id.navigation_refresh) {
                webView.reload();
                return false;
            } else if (id == R.id.navigation_download) {
                // 假设 DownloadsActivity 存在
                startActivity(new Intent(this, DownloadsActivity.class));
                return false;
            } else if (id == R.id.navigation_settings) {
                // 假设 SettingsActivity 存在
                startActivity(new Intent(this, SettingsActivity.class));
                return false;
            }
            
            return false;
        });
        
        updateNavigationButtons();
        bottomNavigationView.setSelectedItemId(View.NO_ID);
    }

    /**
     * 更新导航按钮状态
     */
    private void updateNavigationButtons() {
        boolean canGoBack = webView.canGoBack();
        boolean canGoForward = webView.canGoForward();
        
        bottomNavigationView.getMenu().findItem(R.id.navigation_back).setEnabled(canGoBack);
        bottomNavigationView.getMenu().findItem(R.id.navigation_forward).setEnabled(canGoForward);
    }

    /**
     * 注入下载拦截器
     */
    private void injectDownloadInterceptor(WebView webView) {
        // ... (脚本逻辑与原版一致，没有改动)
        String script = "javascript:(" +
                "function() { " +
                "    if (typeof window.downloadImg_original === 'undefined') { " +
                "        window.downloadImg_original = window.downloadImg;" +
                "        window.downloadImg = function(textId, imgId, url) { " +
                "            console.log('拦截下载: ' + url);" +
                "            if (window.Android && typeof window.Android.startDownload === 'function') { " +
                "                window.Android.startDownload(url, '', '');" +
                "            } else { " +
                "                window.downloadImg_original(textId, imgId, url);" +
                "            } " +
                "        }; " +
                "    } " +
                "})();";
        
        webView.evaluateJavascript(script, null);
        Log.d(TAG, "注入下载拦截器");
    }

    /**
     * 获取下载目标路径
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

    /**
     * JavaScript 接口
     */
    public class WebAppInterface {
        Context mContext;

        WebAppInterface(Context c) {
            mContext = c;
        }

        @JavascriptInterface
        public void startDownload(String url, String contentDisposition, String mimetype) {
            Log.d(TAG, "JS 下载: " + url);
            runOnUiThread(() -> {
                try {
                    DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                    String cookies = CookieManager.getInstance().getCookie(url);
                    if (cookies != null && !cookies.isEmpty()) {
                        request.addRequestHeader("cookie", cookies);
                    }
                    request.addRequestHeader("User-Agent", webView.getSettings().getUserAgentString());
                    request.setDescription("下载中...");
                    String fileName = URLUtil.guessFileName(url, contentDisposition, mimetype);
                    request.setTitle(fileName);
                    request.allowScanningByMediaScanner();
                    request.setNotificationVisibility(
                            DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);

                    // 下载路径解析
                    String finalDestinationSubPath = getDownloadDestinationSubPath(
                            prefs.getString(PREF_DOWNLOAD_DIRECTORY, null));
                    request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, 
                            finalDestinationSubPath + File.separator + fileName);

                    DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                    if (dm != null) {
                        dm.enqueue(request);
                        Toast.makeText(getApplicationContext(), 
                                "开始下载: " + fileName, Toast.LENGTH_LONG).show();
                    } else {
                        Toast.makeText(getApplicationContext(), 
                                "下载服务不可用", Toast.LENGTH_LONG).show();
                    }
                } catch (Exception e) {
                    Toast.makeText(getApplicationContext(), 
                            "下载失败: " + e.getMessage(), Toast.LENGTH_LONG).show();
                    Log.e(TAG, "JS 下载错误", e);
                }
            });
        }

        @JavascriptInterface
        public void logError(String message) {
            Log.e(TAG, "JS 错误: " + message);
        }
    }
    
    /**
     * 为 BottomNavigationView 和 ProgressBar 应用主题色，并设置 Ripple 颜色
     */
    private void applyThemeToBottomNavigation() {
        ThemeManager themeManager = ThemeManager.getInstance(this);
        int primaryColor = themeManager.getPrimaryColor();
        
        // 创建颜色状态列表用于图标着色，区分可用和不可用状态
        int[][] states = new int[][] {
            new int[] { android.R.attr.state_enabled}, // enabled
            new int[] {-android.R.attr.state_enabled}  // disabled
        };
        int[] colors = new int[] {
            primaryColor, // enabled color
            ContextCompat.getColor(this, android.R.color.darker_gray) // disabled color
        };
        android.content.res.ColorStateList colorStateList = new android.content.res.ColorStateList(states, colors);
        bottomNavigationView.setItemIconTintList(colorStateList);
        bottomNavigationView.setItemTextColor(colorStateList);
        
        // 确定当前模式并设置 Ripple 效果颜色 (Hover/Click)
        int nightMode = getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
        int rippleColor;

        if (nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES) {
            // 深色模式: 调用 ThemeUtils 获取标准深色背景
            rippleColor = android.graphics.Color.parseColor("#424242");
            bottomNavigationView.setBackgroundColor(
                    ThemeUtils.getThemeAttrColor(this, com.google.android.material.R.attr.colorSurfaceContainer)
            );
        } else {
            // 浅色模式: 调用 ThemeUtils 获取浅色化的主题色作为背景
            rippleColor = android.graphics.Color.parseColor("#D3D3D3");
            int lightenedColor = ThemeUtils.getLightenedColor(primaryColor, 0.9f);
            bottomNavigationView.setBackgroundColor(lightenedColor);
        }

        // 应用 Ripple 颜色
        ColorStateList rippleColorStateList = ColorStateList.valueOf(rippleColor);
        bottomNavigationView.setItemRippleColor(rippleColorStateList);

        // 3. 为 ProgressBar 应用主题色
        if (progressBar != null) {
            // 使用 setTint (需要 API 21+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                progressBar.getProgressDrawable().setTint(primaryColor);
            } else {
                // 兼容旧版，使用 ColorFilter
                progressBar.getProgressDrawable().setColorFilter(primaryColor, android.graphics.PorterDuff.Mode.SRC_IN);
            }
        }
        Log.d(TAG, "主题色应用于导航栏和进度条。Ripple 颜色已根据模式设置。");
    }

    /**
     * 检查 WebView 版本
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
            Log.d(TAG, "WebView 版本: " + webViewPackageInfo.versionName 
                    + " (" + currentWebViewVersionCode + ")");

            if (currentWebViewVersionCode < MIN_WEBVIEW_VERSION_CODE) {
                new AlertDialog.Builder(this)
                        .setTitle(R.string.webview_version_warning_title)
                        .setMessage(getString(R.string.webview_version_warning_message, 
                                webViewPackageInfo.versionName))
                        .setPositiveButton(R.string.update_webview, (dialog, which) -> {
                            try {
                                startActivity(new Intent(Intent.ACTION_VIEW, 
                                        Uri.parse("market://details?id=com.google.android.webview")));
                            } catch (android.content.ActivityNotFoundException anfe) {
                                startActivity(new Intent(Intent.ACTION_VIEW, 
                                        Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.webview")));
                            }
                        })
                        .setNegativeButton(R.string.dismiss, (dialog, which) -> dialog.dismiss())
                        .show();
                Log.w(TAG, "WebView 版本过低");
            }
        } else {
            runOnUiThread(() -> 
                    Toast.makeText(this, "无法检测 WebView", Toast.LENGTH_LONG).show());
            Log.e(TAG, "无法检测 WebView 包");
        }
    }

    /**
     * 请求存储权限
     */
    private void requestStoragePermissions() {
        String[] permissionsToRequest;

        Log.d(TAG, "检查权限 (Android " + Build.VERSION.SDK_INT + ")");

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO,
                    Manifest.permission.READ_MEDIA_AUDIO
            };
        } else {
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
            };
        }
        
        boolean allGranted = true;
        for (String permission : permissionsToRequest) {
            if (ContextCompat.checkSelfPermission(this, permission) 
                    != PackageManager.PERMISSION_GRANTED) {
                allGranted = false;
                break;
            }
        }

        if (allGranted) {
            Log.d(TAG, "权限已授予");
            initializeWebView();
        } else {
            Log.d(TAG, "请求权限");
            requestPermissionLauncher.launch(permissionsToRequest);
        }
    }

    /**
     * 处理深度链接
     */
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleDeepLink(intent);
    }
    
    /**
     * 【新增】仅用于首次启动时确定 URL
     */
    private String determineInitialUrl(Intent intent) {
        Uri data = intent.getData();
        if (data == null) return null;

        String scheme = data.getScheme();
        String host = data.getHost();
        String path = data.getPath() != null ? data.getPath() : "";

        String urlToLoad = null;

        if (("https".equals(scheme) || "http".equals(scheme)) 
                && ("www.moely.link".equals(host) || "mobile.moely.link".equals(host))) {
            urlToLoad = data.toString();
        } else if ("moely".equalsIgnoreCase(scheme)) {
            if (host != null) {
                urlToLoad = "https://www.moely.link/" + host + path;
            } else {
                urlToLoad = "https://www.moely.link" + path;
            }
        }
        
        return urlToLoad;
    }

    /**
     * 处理深度链接
     * 【修改：仅处理 onNewIntent 调用的后续深度链接】
     */
    private void handleDeepLink(Intent intent) {
        Uri data = intent.getData();
        if (data == null || webView == null) return;

        String scheme = data.getScheme();
        String host = data.getHost();
        String path = data.getPath() != null ? data.getPath() : "";

        String urlToLoad = null;

        if (("https".equals(scheme) || "http".equals(scheme)) 
                && ("www.moely.link".equals(host) || "mobile.moely.link".equals(host))) {
            urlToLoad = data.toString();
        } else if ("moely".equalsIgnoreCase(scheme)) {
            if (host != null) {
                urlToLoad = "https://www.moely.link/" + host + path;
            } else {
                urlToLoad = "https://www.moely.link" + path;
            }
        }
        
        if (urlToLoad != null) {
            // 在 onNewIntent 中，WebView 已经初始化完成，可以直接 loadUrl
            webView.loadUrl(urlToLoad); 
        }
    }

    /**
     * Activity 恢复时
     */
    @Override
    protected void onResume() {
        super.onResume();

        // 重新应用主题色和 Ripple 颜色
        applyThemeToBottomNavigation();
        
        // WebView 恢复
        if (webView != null) {
            webView.onResume();
        }
        
        // 如果 WebView 未加载，重新请求权限
        if (webView != null && webView.getUrl() == null) {
            Log.d(TAG, "WebView 未初始化，重新请求权限");
            requestStoragePermissions();
        }
    }

    /**
     * Activity 暂停时
     */
    @Override
    protected void onPause() {
        super.onPause();
        if (webView != null) {
            webView.onPause();
        }
    }

    /**
     * Activity 销毁时
     */
    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.clearHistory();
            webView.clearCache(true);
            webView.loadUrl("about:blank");
            webView.pauseTimers();
            
            ViewGroup parent = (ViewGroup) webView.getParent();
            if (parent != null) {
                parent.removeView(webView);
            }
            
            webView.removeAllViews();
            webView.destroy();
            webView = null;
        }
        
        super.onDestroy();
    }

    /**
     * 检查并请求存储权限（供其他功能调用）
     */
    public void checkAndRequestStoragePermission() {
        String[] permissionsToRequest;
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_MEDIA_IMAGES
            };
        } else {
            permissionsToRequest = new String[]{
                    Manifest.permission.READ_EXTERNAL_STORAGE
            };
        }
        
        boolean allGranted = true;
        for (String permission : permissionsToRequest) {
            if (ContextCompat.checkSelfPermission(this, permission) 
                    != PackageManager.PERMISSION_GRANTED) {
                allGranted = false;
                break;
            }
        }
        
        if (!allGranted) {
            requestPermissionLauncher.launch(permissionsToRequest);
            Log.d(TAG, "请求媒体权限");
        } else {
            Log.i(TAG, "媒体权限已授予");
        }
    }
}
