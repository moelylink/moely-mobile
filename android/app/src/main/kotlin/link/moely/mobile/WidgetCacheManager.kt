package link.moely.mobile

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

object WidgetCacheManager {
    private const val TAG = "WidgetCacheManager"
    private const val PREFS_NAME = "widget_cache_prefs"
    private const val KEY_LANDSCAPE_CACHE = "landscape_cache_v2"
    private const val KEY_PORTRAIT_CACHE = "portrait_cache_v2"
    private const val KEY_CURRENT_LANDSCAPE = "current_landscape_path"
    private const val KEY_CURRENT_PORTRAIT = "current_portrait_path"
    private const val CACHE_DIR_NAME = "widget_cache"
    private const val MAX_CACHE_SIZE = 3

    data class CachedImage(
        val id: String,
        val localPath: String,
        val author: String,
        val url: String
    ) {
        fun toJson(): JSONObject {
            return JSONObject().apply {
                put("id", id)
                put("localPath", localPath)
                put("author", author)
                put("url", url)
            }
        }

        companion object {
            fun fromJson(json: JSONObject): CachedImage {
                return CachedImage(
                    json.getString("id"),
                    json.getString("localPath"),
                    json.getString("author"),
                    json.getString("url")
                )
            }
        }
    }

    private fun getPrefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun getCacheDir(context: Context): File {
        val dir = File(context.cacheDir, CACHE_DIR_NAME)
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    @Synchronized
    private fun getCacheQueue(context: Context, isLandscape: Boolean): MutableList<CachedImage> {
        val prefs = getPrefs(context)
        val key = if (isLandscape) KEY_LANDSCAPE_CACHE else KEY_PORTRAIT_CACHE
        val jsonStr = prefs.getString(key, null) ?: return mutableListOf()
        val list = mutableListOf<CachedImage>()
        try {
            val jsonArray = JSONArray(jsonStr)
            for (i in 0 until jsonArray.length()) {
                list.add(CachedImage.fromJson(jsonArray.getJSONObject(i)))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing cache queue", e)
        }
        return list
    }

    @Synchronized
    private fun saveCacheQueue(context: Context, isLandscape: Boolean, queue: List<CachedImage>) {
        val prefs = getPrefs(context)
        val key = if (isLandscape) KEY_LANDSCAPE_CACHE else KEY_PORTRAIT_CACHE
        val jsonArray = JSONArray()
        for (item in queue) {
            jsonArray.put(item.toJson())
        }
        prefs.edit().putString(key, jsonArray.toString()).apply()
    }

    @Synchronized
    fun getAndPopCachedImage(context: Context, isLandscape: Boolean): CachedImage? {
        val queue = getCacheQueue(context, isLandscape)
        while (queue.isNotEmpty()) {
            val item = queue.removeAt(0)
            saveCacheQueue(context, isLandscape, queue)
            
            // Verify file exists and is valid
            val file = File(item.localPath)
            if (file.exists() && file.length() > 0) {
                // Record currently displayed path for garbage collection exclusion
                val currentKey = if (isLandscape) KEY_CURRENT_LANDSCAPE else KEY_CURRENT_PORTRAIT
                getPrefs(context).edit().putString(currentKey, item.localPath).apply()
                
                // Trigger prefetch asynchronously to refill the queue
                triggerPrefetch(context, isLandscape)
                
                // Run garbage collection
                runGarbageCollection(context)
                
                return item
            } else {
                // If file doesn't exist, remove it from queue and try next one
                if (file.exists()) file.delete()
            }
        }
        
        // Queue was empty, trigger prefetch asynchronously
        triggerPrefetch(context, isLandscape)
        return null
    }

    fun triggerPrefetch(context: Context, isLandscape: Boolean) {
        thread {
            try {
                prefetchInternal(context, isLandscape)
            } catch (e: Exception) {
                Log.e(TAG, "Prefetch failed", e)
            }
        }
    }

    private fun prefetchInternal(context: Context, isLandscape: Boolean) {
        val queue = getCacheQueue(context, isLandscape)
        if (queue.size >= MAX_CACHE_SIZE) {
            return
        }

        // Fetch index JSON
        val url = URL("https://www.moely.link/index.json")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 10000
        conn.readTimeout = 10000
        conn.requestMethod = "GET"
        conn.setRequestProperty("User-Agent", getUserAgent(context))

        if (conn.responseCode != 200) {
            return
        }

        val reader = BufferedReader(InputStreamReader(conn.inputStream))
        val response = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            response.append(line)
        }
        reader.close()

        val jsonArray = JSONArray(response.toString())
        if (jsonArray.length() == 0) return

        // Create a list of items and shuffle them for random picking
        val indices = (0 until jsonArray.length()).toList().shuffled()
        var indexOffset = 0

        val currentQueueUrls = queue.map { it.url }.toSet()

        while (getCacheQueue(context, isLandscape).size < MAX_CACHE_SIZE && indexOffset < indices.size) {
            val randomIndex = indices[indexOffset++]
            val imgObject = jsonArray.getJSONObject(randomIndex)
            val imageUrl = imgObject.getString("urls")
            val id = imgObject.getString("id")
            val author = imgObject.getString("user")

            if (currentQueueUrls.contains(imageUrl)) {
                continue
            }

            // Check dimensions using inJustDecodeBounds
            val isMatching = checkImageOrientation(context, imageUrl, isLandscape)
            if (isMatching) {
                // Download image
                val destFile = File(getCacheDir(context), "${if (isLandscape) "land" else "port"}_${id}_${System.currentTimeMillis()}.webp")
                if (downloadFile(context, imageUrl, destFile)) {
                    val newQueue = getCacheQueue(context, isLandscape)
                    if (newQueue.size < MAX_CACHE_SIZE) {
                        newQueue.add(CachedImage(id, destFile.absolutePath, author, imageUrl))
                        saveCacheQueue(context, isLandscape, newQueue)
                    } else {
                        // Queue got filled in parallel, delete downloaded file
                        if (destFile.exists()) destFile.delete()
                    }
                }
            }
        }
    }

    private fun checkImageOrientation(context: Context, imageUrl: String, requireLandscape: Boolean): Boolean {
        var connection: HttpURLConnection? = null
        try {
            val url = URL(imageUrl)
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 8000
            connection.readTimeout = 8000
            connection.setRequestProperty("User-Agent", getUserAgent(context))
            connection.setRequestProperty("Accept", "image/webp,image/apng,image/*,*/*;q=0.8")

            if (connection.responseCode == 200) {
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeStream(connection.inputStream, null, options)
                val width = options.outWidth
                val height = options.outHeight
                if (width > 0 && height > 0) {
                    val isLandscape = width >= height
                    return isLandscape == requireLandscape
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking orientation for $imageUrl", e)
        } finally {
            connection?.disconnect()
        }
        return false
    }

    private fun downloadFile(context: Context, fileUrl: String, destFile: File): Boolean {
        var connection: HttpURLConnection? = null
        var outputStream: FileOutputStream? = null
        try {
            val url = URL(fileUrl)
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.setRequestProperty("User-Agent", getUserAgent(context))
            
            if (connection.responseCode == 200) {
                val inputStream = connection.inputStream
                outputStream = FileOutputStream(destFile)
                val buffer = ByteArray(4096)
                var bytesRead: Int
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                outputStream.flush()
                return destFile.exists() && destFile.length() > 0
            }
        } catch (e: Exception) {
            Log.e(TAG, "Download failed: $fileUrl", e)
            if (destFile.exists()) destFile.delete()
        } finally {
            outputStream?.close()
            connection?.disconnect()
        }
        return false
    }

    @Synchronized
    fun runGarbageCollection(context: Context) {
        val prefs = getPrefs(context)
        val activeFiles = mutableSetOf<String>()
        
        // Collect files currently in queues
        getCacheQueue(context, true).forEach { activeFiles.add(it.localPath) }
        getCacheQueue(context, false).forEach { activeFiles.add(it.localPath) }
        
        // Collect currently displayed files
        prefs.getString(KEY_CURRENT_LANDSCAPE, null)?.let { activeFiles.add(it) }
        prefs.getString(KEY_CURRENT_PORTRAIT, null)?.let { activeFiles.add(it) }
        
        // List directory and delete unneeded files
        val dir = getCacheDir(context)
        val files = dir.listFiles() ?: return
        for (file in files) {
            if (!activeFiles.contains(file.absolutePath)) {
                try {
                    file.delete()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to delete old cached file: ${file.absolutePath}", e)
                }
            }
        }
    }
}
