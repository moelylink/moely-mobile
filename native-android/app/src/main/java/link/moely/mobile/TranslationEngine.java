package link.moely.mobile;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.HashMap;
import java.util.Map;

/**
 * 翻译引擎 - 包含所有翻译相关类
 * 支持: Google, Microsoft
 */
public class TranslationEngine {

    // ==========================================
    // 翻译引擎接口
    // ==========================================
    
    public interface Translator {
        String translate(String text, String fromLang, String toLang) throws Exception;
        String getName();
    }

    // ==========================================
    // Google 翻译
    // ==========================================
    
    public static class GoogleTranslator implements Translator {
        
        @Override
        public String translate(String text, String fromLang, String toLang) throws Exception {
            String urlStr = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" 
                + fromLang + "&tl=" + toLang + "&dt=t&q=" + URLEncoder.encode(text, "UTF-8");
            
            URL url = new URL(urlStr);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("User-Agent", "Mozilla/5.0");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();
            conn.disconnect();
            
            JSONArray jsonArray = new JSONArray(response.toString());
            JSONArray translations = jsonArray.getJSONArray(0);
            StringBuilder result = new StringBuilder();
            
            for (int i = 0; i < translations.length(); i++) {
                result.append(translations.getJSONArray(i).getString(0));
            }
            
            return result.toString();
        }
        
        @Override
        public String getName() {
            return "Google";
        }
    }

    // ==========================================
    // Microsoft 翻译 (无需API key)
    // ==========================================
    
    public static class MicrosoftTranslator implements Translator {
        
        private String jwtToken = null;
        private long tokenExpireTime = 0;
        
        /**
         * 刷新或获取 JWT Token
         */
        private String refreshToken() throws Exception {
            long currentTime = System.currentTimeMillis() / 1000;
            
            // 检查现有 token 是否有效
            if (jwtToken != null && currentTime < tokenExpireTime) {
                return jwtToken;
            }
            
            // 获取新 token
            URL url = new URL("https://edge.microsoft.com/translate/auth");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            
            if (conn.getResponseCode() == 200) {
                BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                jwtToken = reader.readLine();
                reader.close();
                conn.disconnect();
                
                // 解析 token 过期时间
                tokenExpireTime = parseJwtExpireTime(jwtToken);
                
                return jwtToken;
            } else {
                throw new Exception("Failed to get Microsoft auth token: " + conn.getResponseCode());
            }
        }
        
        /**
         * 解析 JWT token 的过期时间
         */
        private long parseJwtExpireTime(String token) {
            try {
                String[] parts = token.split("\\.");
                if (parts.length < 2) return 0;
                
                // Base64 解码 payload
                String payload = parts[1];
                // 替换 URL safe 字符
                payload = payload.replace('-', '+').replace('_', '/');
                // 添加 padding
                while (payload.length() % 4 != 0) {
                    payload += "=";
                }
                
                byte[] decodedBytes = android.util.Base64.decode(payload, android.util.Base64.DEFAULT);
                String decodedPayload = new String(decodedBytes, "UTF-8");
                
                JSONObject json = new JSONObject(decodedPayload);
                return json.getLong("exp");
            } catch (Exception e) {
                // 如果解析失败,返回当前时间,这样下次会重新获取 token
                return System.currentTimeMillis() / 1000;
            }
        }
        
        @Override
        public String translate(String text, String fromLang, String toLang) throws Exception {
            // 获取或刷新 JWT token
            String token = refreshToken();
            
            // 构建请求 URL (from 参数为空表示自动检测)
            String fromParam = "auto".equals(fromLang) ? "" : fromLang;
            String urlStr = "https://api-edge.cognitive.microsofttranslator.com/translate?from=" 
                + fromParam + "&to=" + toLang + "&api-version=3.0&includeSentenceLength=true";
            
            URL url = new URL(urlStr);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("Authorization", "Bearer " + token);
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);
            
            // 构建请求体
            JSONArray jsonArray = new JSONArray();
            JSONObject jsonObject = new JSONObject();
            jsonObject.put("Text", text);
            jsonArray.put(jsonObject);
            
            OutputStream os = conn.getOutputStream();
            os.write(jsonArray.toString().getBytes("UTF-8"));
            os.close();
            
            // 读取响应
            int responseCode = conn.getResponseCode();
            if (responseCode == 200) {
                BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                StringBuilder response = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    response.append(line);
                }
                reader.close();
                conn.disconnect();
                
                JSONArray resultArray = new JSONArray(response.toString());
                return resultArray.getJSONObject(0)
                    .getJSONArray("translations")
                    .getJSONObject(0)
                    .getString("text");
            } else {
                // 读取错误信息
                BufferedReader errorReader = new BufferedReader(
                    new InputStreamReader(conn.getErrorStream()));
                StringBuilder errorResponse = new StringBuilder();
                String line;
                while ((line = errorReader.readLine()) != null) {
                    errorResponse.append(line);
                }
                errorReader.close();
                conn.disconnect();
                
                throw new Exception("Microsoft translation failed: " + responseCode + " " + errorResponse.toString());
            }
        }
        
        @Override
        public String getName() {
            return "Microsoft";
        }
    }

    // ==========================================
    // 翻译管理器
    // ==========================================
    
    public static class TranslationManager {
        private static TranslationManager instance;
        private Map<String, Translator> engines;
        private SharedPreferences prefs;
        private static final String PREF_NAME = "translation_settings";
        private static final String KEY_ENABLED = "translation_enabled";
        private static final String KEY_ENGINE = "translation_engine";
        private static final String KEY_AUTO_TRANSLATE = "auto_translate_enabled";
        private static final String KEY_TARGET_LANGUAGE = "target_language";
        
        private TranslationManager(Context context) {
            engines = new HashMap<>();
            engines.put("Google", new GoogleTranslator());
            engines.put("Microsoft", new MicrosoftTranslator());
            
            prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        }
        
        public static synchronized TranslationManager getInstance(Context context) {
            if (instance == null) {
                instance = new TranslationManager(context.getApplicationContext());
            }
            return instance;
        }
        
        public boolean isEnabled() {
            return prefs.getBoolean(KEY_ENABLED, false);
        }
        
        public void setEnabled(boolean enabled) {
            prefs.edit().putBoolean(KEY_ENABLED, enabled).apply();
        }
        
        public boolean isAutoTranslateEnabled() {
            return prefs.getBoolean(KEY_AUTO_TRANSLATE, false);
        }
        
        public void setAutoTranslateEnabled(boolean enabled) {
            prefs.edit().putBoolean(KEY_AUTO_TRANSLATE, enabled).apply();
        }
        
        public String getTargetLanguage() {
            return prefs.getString(KEY_TARGET_LANGUAGE, "zh-CN");
        }
        
        public void setTargetLanguage(String language) {
            prefs.edit().putString(KEY_TARGET_LANGUAGE, language).apply();
        }
        
        public String getCurrentEngine() {
            return prefs.getString(KEY_ENGINE, "Microsoft");
        }
        
        public void setCurrentEngine(String engineName) {
            prefs.edit().putString(KEY_ENGINE, engineName).apply();
        }
        
        public String[] getAvailableEngines() {
            return engines.keySet().toArray(new String[0]);
        }
        
        public void translateAsync(String text, String fromLang, String toLang, TranslationCallback callback) {
            if (!isEnabled()) {
                callback.onError("Translation is disabled");
                return;
            }
            
            new Thread(() -> {
                try {
                    Translator engine = engines.get(getCurrentEngine());
                    if (engine == null) {
                        callback.onError("Engine not found");
                        return;
                    }
                    
                    String result = engine.translate(text, fromLang, toLang);
                    callback.onSuccess(result);
                } catch (Exception e) {
                    callback.onError(e.getMessage() != null ? e.getMessage() : "Translation failed");
                }
            }).start();
        }
        
        public interface TranslationCallback {
            void onSuccess(String translatedText);
            void onError(String error);
        }
    }
}
