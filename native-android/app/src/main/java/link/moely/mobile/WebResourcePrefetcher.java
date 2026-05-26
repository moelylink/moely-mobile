package link.moely.mobile;

import android.util.Log;
import android.webkit.MimeTypeMap;
import android.webkit.WebResourceResponse;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * WebResourcePrefetcher
 * 用于预加载 H5 静态资源（CSS, JS, 图片, 字体），加速 WebView 首屏渲染。
 * 改进点：
 * 1. 增加了 HTTP 响应头处理，解决 CORS 跨域问题（如字体文件）。
 * 2. 优化了 MIME Type 识别逻辑，支持带参数的 URL。
 * 3. 提供了 clearCache 方法用于释放内存。
 */
public class WebResourcePrefetcher {
    private static final String TAG = "WebResourcePrefetcher";
    
    // 使用 volatile 确保多线程下的可见性
    private static volatile WebResourcePrefetcher instance;
    
    private final OkHttpClient client;
    
    // 使用 ConcurrentHashMap 保证多线程读写安全
    private final Map<String, byte[]> resourceCache = new ConcurrentHashMap<>();

    private WebResourcePrefetcher() {
        this.client = new OkHttpClient();
    }

    public static WebResourcePrefetcher getInstance() {
        if (instance == null) {
            synchronized (WebResourcePrefetcher.class) {
                if (instance == null) {
                    instance = new WebResourcePrefetcher();
                }
            }
        }
        return instance;
    }

    /**
     * 启动预加载
     * @param urls 需要预加载的 CSS 或 JS 文件的完整 URL
     */
    public void prefetch(String... urls) {
        for (String url : urls) {
            if (resourceCache.containsKey(url)) continue; // 避免重复下载

            Request request = new Request.Builder().url(url).build();
            client.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    Log.e(TAG, "预加载失败: " + url, e);
                }

                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    if (response.isSuccessful() && response.body() != null) {
                        // 将数据存入内存
                        byte[] bytes = response.body().bytes();
                        resourceCache.put(url, bytes);
                        Log.d(TAG, "预加载成功 (" + bytes.length + " bytes): " + url);
                    } else {
                        Log.w(TAG, "预加载响应错误: " + response.code() + " - " + url);
                    }
                    response.close();
                }
            });
        }
    }

    /**
     * 获取缓存的资源响应，供 WebView 使用
     */
    public WebResourceResponse getCachedResponse(String url) {
        // 检查内存中是否有该 URL 的数据
        if (resourceCache.containsKey(url)) {
            byte[] data = resourceCache.get(url);
            if (data != null) {
                String mimeType = determineMimeType(url);
                Log.d(TAG, "WebView 命中内存缓存: " + url + " [" + mimeType + "]");

                // 【关键改进】构建响应头
                // 尤其是 Access-Control-Allow-Origin，缺少它会导致字体文件 (.woff2) 跨域报错
                Map<String, String> headers = new HashMap<>();
                headers.put("Access-Control-Allow-Origin", "*");
                headers.put("Cache-Control", "max-age=31536000, immutable");

                try {
                    // 使用带 header 的构造函数 (API 21+)
                    return new WebResourceResponse(
                            mimeType,
                            "UTF-8",
                            200,
                            "OK",
                            headers,
                            new ByteArrayInputStream(data)
                    );
                } catch (Exception e) {
                    // 极低版本兼容回退
                    return new WebResourceResponse(
                            mimeType, 
                            "UTF-8", 
                            new ByteArrayInputStream(data)
                    );
                }
            }
        }
        return null; // 没有缓存，让 WebView 自己去网络加载
    }

    /**
     * 【关键改进】更健壮的 MIME Type 获取逻辑
     * 能够处理类似 style.css?v=1.0 这样的带参数 URL
     */
    private String determineMimeType(String url) {
        String cleanUrl = url;
        
        // 去除 URL 参数（例如 ?v=123）以便正确判断后缀
        if (url.contains("?")) {
            cleanUrl = url.split("\\?")[0];
        }
        cleanUrl = cleanUrl.toLowerCase();

        // 1. 尝试使用系统 MimeTypeMap
        String extension = MimeTypeMap.getFileExtensionFromUrl(cleanUrl);
        String mimeType = null;
        if (extension != null) {
            mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
        }

        // 2. 如果系统识别失败，使用手动后备列表
        if (mimeType == null) {
            if (cleanUrl.endsWith(".css")) return "text/css";
            if (cleanUrl.endsWith(".js")) return "application/javascript";
            if (cleanUrl.endsWith(".json")) return "application/json";
            if (cleanUrl.endsWith(".jpg") || cleanUrl.endsWith(".jpeg")) return "image/jpeg";
            if (cleanUrl.endsWith(".png")) return "image/png";
            if (cleanUrl.endsWith(".gif")) return "image/gif";
            if (cleanUrl.endsWith(".svg")) return "image/svg+xml";
            if (cleanUrl.endsWith(".woff")) return "font/woff";
            if (cleanUrl.endsWith(".woff2")) return "font/woff2"; // 常见字体
            if (cleanUrl.endsWith(".ttf")) return "font/ttf";
            return "text/plain"; // 默认兜底
        }
        
        return mimeType;
    }

    /**
     * 【新增】清空缓存
     * 建议在 Activity onDestroy 时调用，防止内存泄漏
     */
    public void clearCache() {
        resourceCache.clear();
        Log.d(TAG, "内存缓存已手动清空");
    }
}
