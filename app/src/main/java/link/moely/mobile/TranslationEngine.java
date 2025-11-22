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
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.Map;

/**
 * 翻译引擎 - 包含所有翻译相关类
 * 支持: Google, Microsoft, DeepL, Youdao, Baidu
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
    // Microsoft 翻译
    // ==========================================
    
    public static class MicrosoftTranslator implements Translator {
        
        @Override
        public String translate(String text, String fromLang, String toLang) throws Exception {
            String urlStr = "https://api.translator.microsoft.com/translate?api-version=3.0&from=" 
                + fromLang + "&to=" + toLang;
            
            URL url = new URL(urlStr);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);
            
            JSONArray jsonArray = new JSONArray();
            JSONObject jsonObject = new JSONObject();
            jsonObject.put("Text", text);
            jsonArray.put(jsonObject);
            
            OutputStream os = conn.getOutputStream();
            os.write(jsonArray.toString().getBytes("UTF-8"));
            os.close();
            
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
        }
        
        @Override
        public String getName() {
            return "Microsoft";
        }
    }

    // ==========================================
    // DeepL 翻译
    // ==========================================
    
    public static class DeepLTranslator implements Translator {
        
        @Override
        public String translate(String text, String fromLang, String toLang) throws Exception {
            String urlStr = "https://www2.deepl.com/jsonrpc";
            
            URL url = new URL(urlStr);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);
            
            JSONObject jsonRequest = new JSONObject();
            jsonRequest.put("jsonrpc", "2.0");
            jsonRequest.put("method", "LMT_handle_texts");
            
            JSONObject params = new JSONObject();
            params.put("splitting", "newlines");
            params.put("lang", new JSONObject()
                .put("source_lang_user_selected", fromLang.toUpperCase())
                .put("target_lang", toLang.toUpperCase()));
            params.put("texts", new JSONArray().put(new JSONObject().put("text", text)));
            
            jsonRequest.put("params", params);
            jsonRequest.put("id", System.currentTimeMillis());
            
            OutputStream os = conn.getOutputStream();
            os.write(jsonRequest.toString().getBytes("UTF-8"));
            os.close();
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();
            conn.disconnect();
            
            JSONObject result = new JSONObject(response.toString());
            return result.getJSONObject("result")
                .getJSONArray("texts")
                .getJSONObject(0)
                .getString("text");
        }
        
        @Override
        public String getName() {
            return "DeepL";
        }
    }

    // ==========================================
    // 有道翻译
    // ==========================================
    
    public static class YoudaoTranslator implements Translator {
        
        @Override
        public String translate(String text, String fromLang, String toLang) throws Exception {
            String urlStr = "https://fanyi.youdao.com/translate?smartresult=dict&smartresult=rule";
            
            URL url = new URL(urlStr);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
            conn.setRequestProperty("User-Agent", "Mozilla/5.0");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);
            
            String postData = "i=" + URLEncoder.encode(text, "UTF-8") 
                + "&from=" + fromLang + "&to=" + toLang 
                + "&smartresult=dict&client=fanyideskweb&doctype=json&version=2.1&keyfrom=fanyi.web&action=FY_BY_REALTIME";
            
            conn.getOutputStream().write(postData.getBytes("UTF-8"));
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();
            conn.disconnect();
            
            JSONObject result = new JSONObject(response.toString());
            JSONArray translateResult = result.getJSONArray("translateResult");
            StringBuilder translatedText = new StringBuilder();
            
            for (int i = 0; i < translateResult.length(); i++) {
                JSONArray arr = translateResult.getJSONArray(i);
                for (int j = 0; j < arr.length(); j++) {
                    translatedText.append(arr.getJSONObject(j).getString("tgt"));
                }
            }
            
            return translatedText.toString();
        }
        
        @Override
        public String getName() {
            return "Youdao";
        }
    }

    // ==========================================
    // 百度翻译
    // ==========================================
    
    public static class BaiduTranslator implements Translator {
        
        private String generateSign(String query, String salt) {
            try {
                String src = "20220901000000000" + query + salt + "GU2zKZL0kL14TN91fzi8";
                MessageDigest md = MessageDigest.getInstance("MD5");
                byte[] bytes = md.digest(src.getBytes("UTF-8"));
                StringBuilder sb = new StringBuilder();
                for (byte b : bytes) {
                    sb.append(String.format("%02x", b));
                }
                return sb.toString();
            } catch (Exception e) {
                return "";
            }
        }
        
        @Override
        public String translate(String text, String fromLang, String toLang) throws Exception {
            String salt = String.valueOf(System.currentTimeMillis());
            String sign = generateSign(text, salt);
            
            String urlStr = "https://fanyi.baidu.com/v2transapi?from=" + fromLang 
                + "&to=" + toLang;
            
            URL url = new URL(urlStr);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
            conn.setRequestProperty("User-Agent", "Mozilla/5.0");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);
            
            String postData = "query=" + URLEncoder.encode(text, "UTF-8") 
                + "&from=" + fromLang + "&to=" + toLang + "&sign=" + sign + "&salt=" + salt;
            
            conn.getOutputStream().write(postData.getBytes("UTF-8"));
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();
            conn.disconnect();
            
            JSONObject result = new JSONObject(response.toString());
            return result.getJSONObject("trans_result")
                .getJSONArray("data")
                .getJSONObject(0)
                .getString("dst");
        }
        
        @Override
        public String getName() {
            return "Baidu";
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
            engines.put("DeepL", new DeepLTranslator());
            engines.put("Youdao", new YoudaoTranslator());
            engines.put("Baidu", new BaiduTranslator());
            
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
