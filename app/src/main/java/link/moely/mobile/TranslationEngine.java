package link.moely.mobile;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import android.util.Base64;

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
    // 有道翻译 (逆向版本)
    // ==========================================
    
    public static class YoudaoTranslator implements Translator {

        // 使用Python脚本中的UA
        private static final String USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";
        private static final String COOKIE = "OUTFOX_SEARCH_USER_ID=1145141919@114.51.41.91; _uetsid=faadcbd1145141810a082c1e8b007b95c; _uetvid=faadcbd1145141810a082c1e8b007b95c; OUTFOX_SEARCH_USER_ID_NCOO=1145141919.8109926; DICT_DOCTRANS_SESSION_ID=MTE0NTE0MTkxOTgxMGFiY2RlZmc=";

        // Cached Key Data
        private static class KeyCache {
            String keyid;
            String constSign;
            String aesKey;
            String aesIv;
            String secretKey;
            long expireTime;
        }

        private KeyCache keyCache = null;

        /**
         * Convert to Youdao language codes
         */
        private String convertToYoudaoLangCode(String langCode) {
            if (langCode.equals("zh-CN")) return "zh-CHS";
            if (langCode.equals("zh-TW")) return "zh-CHT";
            return langCode;
        }

        /**
         * Extract product keys from JS file
         */
        private JSONObject getProductKeys() throws Exception {
            String jsUrl = "https://shared.ydstatic.com/dict/translation-website/0.7.8/js/app.3b32dc21.js";

            try {
                URL url = new URL(jsUrl);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                conn.setRequestProperty("User-Agent", USER_AGENT);
                conn.setConnectTimeout(10000);
                conn.setReadTimeout(10000);

                BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                StringBuilder jsContent = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    jsContent.append(line);
                }
                reader.close();
                conn.disconnect();

                String pattern = "async\\(\\{commit:e\\},t\\)=>\\{const\\s+a=\"webfanyi([^\"]+)\",n=\"([^\"]+)\"";
                Pattern p = Pattern.compile(pattern);
                Matcher m = p.matcher(jsContent.toString());

                JSONObject result = new JSONObject();
                if (m.find()) {
                    result.put("keyid", "webfanyi" + m.group(1));
                    result.put("constSign", m.group(2));
                    android.util.Log.d("YoudaoTranslator", "Keys generated from JS");
                } else {
                    result.put("keyid", "webfanyi-key-getter-2025");
                    result.put("constSign", "yU5nT5dK3eZ1pI4j");
                    android.util.Log.d("YoudaoTranslator", "Using fallback keys");
                }
                return result;
            } catch (Exception e) {
                JSONObject result = new JSONObject();
                result.put("keyid", "webfanyi-key-getter-2025");
                result.put("constSign", "yU5nT5dK3eZ1pI4j");
                return result;
            }
        }

        /**
         * Generate MD5 Sign
         */
        private String getSign(String key, String mysticTime) throws Exception {
            String signStr = "client=fanyideskweb&mysticTime=" + mysticTime + "&product=webfanyi&key=" + key;
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] bytes = md.digest(signStr.getBytes("UTF-8"));
            StringBuilder sb = new StringBuilder();
            for (byte b : bytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        }

        /**
         * Fetch AES Keys - 接受动态 yduuid
         */
        private void fetchKeys(String yduuid) throws Exception {
            // 检查缓存是否有效(5分钟有效期)
            if (keyCache != null && System.currentTimeMillis() < keyCache.expireTime) {
                return;
            }

            JSONObject productKeys = getProductKeys();
            String keyid = productKeys.getString("keyid");
            String constSign = productKeys.getString("constSign");
            String mysticTime = String.valueOf(System.currentTimeMillis());
            String sign = getSign(constSign, mysticTime);

            StringBuilder urlBuilder = new StringBuilder("https://dict.youdao.com/webtranslate/key?");
            urlBuilder.append("keyid=").append(URLEncoder.encode(keyid, "UTF-8"));
            urlBuilder.append("&sign=").append(sign);
            urlBuilder.append("&client=fanyideskweb");
            urlBuilder.append("&product=webfanyi");
            urlBuilder.append("&appVersion=1.0.0");
            urlBuilder.append("&vendor=web");
            urlBuilder.append("&pointParam=client,mysticTime,product");
            urlBuilder.append("&mysticTime=").append(mysticTime);
            urlBuilder.append("&keyfrom=fanyi.web");
            urlBuilder.append("&mid=1");
            urlBuilder.append("&screen=1");
            urlBuilder.append("&model=1");
            urlBuilder.append("&network=wifi");
            urlBuilder.append("&abtest=0");
            urlBuilder.append("&yduuid=").append(yduuid); // 使用同步的 yduuid

            URL url = new URL(urlBuilder.toString());
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            
            // Headers
            conn.setRequestProperty("User-Agent", USER_AGENT);
            conn.setRequestProperty("Referer", "https://fanyi.youdao.com/");
            conn.setRequestProperty("Cookie", COOKIE);
            conn.setRequestProperty("Accept", "application/json, text/plain, */*");
            conn.setRequestProperty("Accept-Language", "zh-CN,zh;q=0.9");
            conn.setRequestProperty("Origin", "https://fanyi.youdao.com");
            
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

            JSONObject result = new JSONObject(response.toString());
            JSONObject data = result.getJSONObject("data");

            keyCache = new KeyCache();
            keyCache.keyid = keyid;
            keyCache.constSign = constSign;
            keyCache.aesKey = data.getString("aesKey");
            keyCache.aesIv = data.getString("aesIv");
            keyCache.secretKey = data.getString("secretKey");
            keyCache.expireTime = System.currentTimeMillis() + 5 * 60 * 1000;
        }

        /**
         * AES Decryption
         */
        private String decryptAES(String encryptedBase64, String key, String iv) throws Exception {
            // 1. MD5 Hash the raw Key and IV strings (Matching Python logic)
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] keyBytes = md.digest(key.getBytes("UTF-8"));
            byte[] ivBytes = md.digest(iv.getBytes("UTF-8"));

            // 2. Base64 Decode
            byte[] encryptedBytes = android.util.Base64.decode(encryptedBase64, android.util.Base64.URL_SAFE);

            // 3. AES Decrypt
            SecretKeySpec secretKeySpec = new SecretKeySpec(keyBytes, "AES");
            IvParameterSpec ivSpec = new IvParameterSpec(ivBytes);
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
            cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, ivSpec);

            byte[] decrypted = cipher.doFinal(encryptedBytes);
            return new String(decrypted, "UTF-8");
        }

        @Override
        public String translate(String text, String fromLang, String toLang) throws Exception {
            
            // 1. 随机生成 yduuid (必须是第一步)
            String yduuid = UUID.randomUUID().toString().replaceAll("-", "").substring(0, 15);

            // 2. Fetch Keys (传递 yduuid)
            fetchKeys(yduuid);

            // 3. Generate Params
            String lts = String.valueOf(System.currentTimeMillis());
            String salt = lts + (int) (Math.random() * 10);
            String sign = getSign(keyCache.secretKey, lts);
            String youdaoTo = convertToYoudaoLangCode(toLang);

            // 4. Build POST Data
            StringBuilder postData = new StringBuilder();
            postData.append("i=").append(URLEncoder.encode(text, "UTF-8"));
            postData.append("&from=auto");
            postData.append("&to=").append(youdaoTo);
            
            // Standard params
            postData.append("&domain=0");
            postData.append("&dictResult=true");
            postData.append("&keyid=").append(keyCache.keyid);
            postData.append("&sign=").append(sign);
            postData.append("&client=fanyideskweb");
            postData.append("&product=webfanyi");
            postData.append("&appVersion=1.0.0");
            postData.append("&vendor=web");
            postData.append("&pointParam=client,mysticTime,product");
            postData.append("&mysticTime=").append(lts);
            postData.append("&keyfrom=fanyi.web");
            postData.append("&mid=1");
            postData.append("&screen=1");
            postData.append("&model=1");
            postData.append("&network=wifi");
            postData.append("&abtest=0");
            postData.append("&yduuid=").append(yduuid); // 使用同步的 yduuid
            postData.append("&salt=").append(salt);
            
            // 5. Send Request
            URL url = new URL("https://dict.youdao.com/webtranslate");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");

            // --- FULL HEADERS ---
            conn.setRequestProperty("X-Requested-With", "XMLHttpRequest"); 
            conn.setRequestProperty("Accept", "application/json, text/plain, */*");
            // !!! 关键修复点：移除 Accept-Encoding !!!
            // conn.setRequestProperty("Accept-Encoding", "gzip, deflate, br"); 
            conn.setRequestProperty("Accept-Language", "zh-CN,zh;q=0.9");
            conn.setRequestProperty("Connection", "keep-alive");
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
            conn.setRequestProperty("Origin", "https://fanyi.youdao.com");
            conn.setRequestProperty("Referer", "https://fanyi.youdao.com/");
            conn.setRequestProperty("Sec-Fetch-Dest", "empty");
            conn.setRequestProperty("Sec-Fetch-Mode", "cors");
            conn.setRequestProperty("Sec-Fetch-Site", "same-site");
            conn.setRequestProperty("User-Agent", USER_AGENT);
            conn.setRequestProperty("sec-ch-ua", "\"Google Chrome\";v=\"131\", \"Chromium\";v=\"131\", \"Not_A Brand\";v=\"24\"");
            conn.setRequestProperty("sec-ch-ua-mobile", "?0");
            conn.setRequestProperty("sec-ch-ua-platform", "\"Windows\"");
            conn.setRequestProperty("Cookie", COOKIE); // 请务必更新此值

            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);

            OutputStream os = conn.getOutputStream();
            os.write(postData.toString().getBytes("UTF-8"));
            os.close();

            // 6. Read Response (简化：不再处理 GZIP)
            int responseCode = conn.getResponseCode();
            if (responseCode != 200) {
                throw new Exception("Youdao translation failed: " + responseCode);
            }

            // 直接从输入流读取，因为它现在应该是纯文本或未压缩的
            InputStream rawStream = conn.getInputStream();
            BufferedReader reader = new BufferedReader(new InputStreamReader(rawStream, "UTF-8"));

            StringBuilder encryptedResponse = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                encryptedResponse.append(line);
            }
            reader.close();
            conn.disconnect();

            String rawBase64 = encryptedResponse.toString();
            
            // 7. Decrypt
            String decrypted = decryptAES(rawBase64, keyCache.aesKey, keyCache.aesIv);

            android.util.Log.d("YoudaoTranslator", "Decrypted: " + decrypted);

            // 8. Parse Result
            JSONObject result = new JSONObject(decrypted);
            if (result.has("translateResult")) {
                JSONArray translateResult = result.getJSONArray("translateResult");
                if (translateResult.length() > 0) {
                    Object first = translateResult.get(0);
                    if (first instanceof JSONObject) {
                        return ((JSONObject) first).getString("tgt");
                    } else if (first instanceof JSONArray) {
                        return ((JSONArray) first).getJSONObject(0).getString("tgt");
                    }
                }
            }
            throw new Exception("Translation result not found");
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
