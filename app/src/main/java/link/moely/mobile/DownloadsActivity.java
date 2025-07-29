package link.moely.mobile;

import android.app.DownloadManager;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.util.Log; // 导入 Log 类
import android.view.View;
import android.webkit.MimeTypeMap;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.FileProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.appbar.MaterialToolbar; // 导入 MaterialToolbar

import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class DownloadsActivity extends AppCompatActivity implements DownloadsAdapter.OnItemClickListener {

    private RecyclerView downloadsRecyclerView;
    private TextView noDownloadsText;
    private DownloadsAdapter downloadsAdapter;
    private List<DownloadItem> downloadItemList;
    private DownloadManager downloadManager;
    private MaterialToolbar toolbar; // 声明 MaterialToolbar
    private static final String TAG = "MoelyMobileDownloads"; // 用于 Logcat 的标签

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_downloads);

        downloadsRecyclerView = findViewById(R.id.downloadsRecyclerView);
        noDownloadsText = findViewById(R.id.no_downloads_text);
        toolbar = findViewById(R.id.toolbar_downloads); // 初始化 toolbar

        // 设置工具栏为 Activity 的 ActionBar
        setSupportActionBar(toolbar);

        // 启用向上按钮（返回按钮）
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setDisplayShowHomeEnabled(true);
        }

        // 设置返回按钮的点击监听器
        toolbar.setNavigationOnClickListener(v -> onBackPressed());


        downloadManager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
        downloadItemList = new ArrayList<>();
        downloadsAdapter = new DownloadsAdapter(this, downloadItemList, this);

        downloadsRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        downloadsRecyclerView.setAdapter(downloadsAdapter);

        loadDownloads();
    }

    /**
     * Loads completed downloads from the DownloadManager.
     */
    private void loadDownloads() {
        Log.d(TAG, "Starting to load downloads...");
        downloadItemList.clear();
        DownloadManager.Query query = new DownloadManager.Query();
        // Filter for completed downloads
        query.setFilterByStatus(DownloadManager.STATUS_SUCCESSFUL
                | DownloadManager.STATUS_FAILED
                | DownloadManager.STATUS_PENDING
                | DownloadManager.STATUS_RUNNING
                | DownloadManager.STATUS_PAUSED);

        Cursor cursor = downloadManager.query(query);

        if (cursor == null) {
            Log.e(TAG, "DownloadManager query returned null cursor.");
            Toast.makeText(this, "无法获取下载列表。", Toast.LENGTH_SHORT).show();
            updateUI();
            return;
        }

        if (cursor.getCount() == 0) {
            Log.d(TAG, "No downloads found in DownloadManager for the current query.");
            cursor.close();
            updateUI();
            return;
        }

        try {
            int fileNameColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TITLE);
            int fileSizeColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES);
            int filePathColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI); // This is usually a content:// or file:// URI
            int statusColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS);
            int idColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_ID); // Get download ID for logging

            Log.d(TAG, "Found " + cursor.getCount() + " downloads.");

            while (cursor.moveToNext()) {
                long downloadId = (idColIdx != -1) ? cursor.getLong(idColIdx) : -1;
                String fileName = (fileNameColIdx != -1) ? cursor.getString(fileNameColIdx) : "未知文件";
                long fileSize = (fileSizeColIdx != -1) ? cursor.getLong(fileSizeColIdx) : 0;
                String fileUriString = (filePathColIdx != -1) ? cursor.getString(filePathColIdx) : null;
                int status = (statusColIdx != -1) ? cursor.getInt(statusColIdx) : DownloadManager.STATUS_FAILED;

                Log.d(TAG, "Processing Download ID: " + downloadId + ", Name: " + fileName + ", Status: " + status + ", URI String: " + fileUriString);

                if (fileUriString != null) {
                    Uri downloadUri = Uri.parse(fileUriString);
                    String actualFilePath = getPathFromUri(downloadUri); // Get actual file path from URI

                    if (actualFilePath != null) {
                        File file = new File(actualFilePath);
                        if (file.exists()) {
                            // Use FileProvider for the file URI
                            Uri contentUri = FileProvider.getUriForFile(this, getApplicationContext().getPackageName() + ".fileprovider", file);
                            downloadItemList.add(new DownloadItem(fileName, fileSize, actualFilePath, status, contentUri));
                            Log.d(TAG, "Added download item: " + fileName + ", Path: " + actualFilePath + ", Content URI: " + contentUri);
                        } else {
                            Log.w(TAG, "Downloaded file NOT found at path: " + actualFilePath + " (ID: " + downloadId + ")");
                        }
                    } else {
                        Log.e(TAG, "Could not resolve actual file path for URI: " + downloadUri + " (ID: " + downloadId + ")");
                    }
                } else {
                    Log.w(TAG, "Download URI string is null for ID: " + downloadId);
                }
            }
        } finally {
            cursor.close();
        }
        updateUI();
    }

    /**
     * Attempts to get the actual file path from a given URI.
     * Handles both file:// and content:// URIs.
     */
    private String getPathFromUri(Uri uri) {
        Log.d(TAG, "getPathFromUri called for URI: " + uri);
        String path = null;
        if (uri == null) {
            Log.w(TAG, "Input URI to getPathFromUri is null.");
            return null;
        }

        if ("file".equalsIgnoreCase(uri.getScheme())) {
            path = uri.getPath();
            Log.d(TAG, "URI scheme is 'file', path: " + path);
        } else if ("content".equalsIgnoreCase(uri.getScheme())) {
            Cursor cursor = null;
            try {
                // Query the content resolver for the _data column (actual file path)
                String[] projection = { "_data", OpenableColumns.DISPLAY_NAME }; // Also get display name for debugging
                cursor = getContentResolver().query(uri, projection, null, null, null);
                if (cursor != null && cursor.moveToFirst()) {
                    int dataColumnIndex = cursor.getColumnIndex("_data");
                    if (dataColumnIndex != -1) {
                        path = cursor.getString(dataColumnIndex);
                        Log.d(TAG, "URI scheme is 'content', resolved path using _data: " + path);
                    } else {
                        Log.w(TAG, "Content URI does not have _data column. Trying DISPLAY_NAME.");
                        int nameColumnIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                        if (nameColumnIndex != -1) {
                            String displayName = cursor.getString(nameColumnIndex);
                            Log.w(TAG, "Content URI has no _data, but found DISPLAY_NAME: " + displayName);
                            // For content URIs without _data, it's harder to get a direct file path.
                            // This might indicate the file is not directly accessible via File API.
                            // For DownloadManager, COLUMN_LOCAL_URI should ideally provide a file path or a resolvable content URI.
                        }
                    }
                } else {
                    Log.w(TAG, "ContentResolver query returned null or empty cursor for URI: " + uri);
                }
            } catch (Exception e) {
                Log.e(TAG, "Error getting path from content URI: " + uri + ", Error: " + e.getMessage(), e);
            } finally {
                if (cursor != null) {
                    cursor.close();
                }
            }
        } else {
            Log.w(TAG, "Unsupported URI scheme for path resolution: " + uri.getScheme() + " for URI: " + uri);
        }
        return path;
    }

    /**
     * Updates the UI based on whether there are downloads to display.
     */
    private void updateUI() {
        if (downloadItemList.isEmpty()) {
            noDownloadsText.setVisibility(View.VISIBLE);
            downloadsRecyclerView.setVisibility(View.GONE);
            Log.d(TAG, "No downloads to display, showing 'no downloads' text.");
        } else {
            noDownloadsText.setVisibility(View.GONE);
            downloadsRecyclerView.setVisibility(View.VISIBLE);
            downloadsAdapter.updateData(downloadItemList);
            Log.d(TAG, "Displaying " + downloadItemList.size() + " download items.");
        }
    }


    @Override
    public void onItemClick(DownloadItem item) {
        // Handle opening the downloaded file
        File file = new File(item.getFilePath());
        if (file.exists()) {
            Uri fileUri = item.getFileUri(); // Use the FileProvider URI

            String mimeType = getContentResolver().getType(fileUri);
            if (mimeType == null) {
                // Try to guess mime type based on file extension
                mimeType = getMimeType(file.getAbsolutePath());
            }

            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(fileUri, mimeType);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION); // Grant temporary read permission to the receiving app
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); // Required if starting activity outside of an Activity context

            try {
                startActivity(intent);
            } catch (Exception e) {
                Toast.makeText(this, R.string.no_app_to_open_file, Toast.LENGTH_SHORT).show();
                Log.e(TAG, "Failed to open file: " + item.getFilePath(), e);
            }
        } else {
            Toast.makeText(this, R.string.file_not_found, Toast.LENGTH_SHORT).show();
            Log.e(TAG, "File not found when trying to open: " + item.getFilePath());
        }
    }

    /**
     * Guesses the MIME type from a file path.
     */
    private String getMimeType(String url) {
        String type = null;
        String extension = MimeTypeMap.getFileExtensionFromUrl(url);
        if (extension != null) {
            type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
        }
        return type;
    }

    @Override
    protected void onResume() {
        super.onResume();
        loadDownloads(); // Refresh download list when returning to this activity
    }
}
