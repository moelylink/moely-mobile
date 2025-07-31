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
import android.widget.CheckBox;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.FileProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.appbar.MaterialToolbar; // 导入 MaterialToolbar

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import android.os.Handler;
import android.os.Looper;

public class DownloadsActivity extends AppCompatActivity implements DownloadsAdapter.OnItemClickListener {

    private RecyclerView downloadsRecyclerView;
    private TextView noDownloadsText;
    private DownloadsAdapter downloadsAdapter;
    private DownloadManager downloadManager;
    private MaterialToolbar toolbar; // 声明 MaterialToolbar
    private static final String TAG = "MoelyMobileDownloads"; // 用于 Logcat 的标签
    private Handler refreshHandler;
    private Runnable refreshRunnable;
    private static final int REFRESH_INTERVAL = 1000; // 1秒刷新一次
    
    // 常量定义
    private static final String UNKNOWN_FILE_NAME = "未知文件";
    private static final String PROVIDER_AUTHORITY_SUFFIX = ".fileprovider";

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
        
        // 应用主题
        ThemeUtils.applyTheme(this);
        ThemeUtils.applyThemeToToolbar(toolbar);


        downloadManager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
        downloadsAdapter = new DownloadsAdapter(this, this);

        downloadsRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        downloadsRecyclerView.setAdapter(downloadsAdapter);

        loadDownloads();
    }

    /**
     * Loads completed downloads from the DownloadManager.
     */
    private void loadDownloads() {
        Log.d(TAG, "Starting to load downloads...");
        List<DownloadItem> downloadItems = new ArrayList<>();

        DownloadManager.Query query = new DownloadManager.Query();
        query.setFilterByStatus(DownloadManager.STATUS_SUCCESSFUL |
                DownloadManager.STATUS_FAILED |
                DownloadManager.STATUS_PENDING |
                DownloadManager.STATUS_RUNNING |
                DownloadManager.STATUS_PAUSED);

        try (Cursor cursor = downloadManager.query(query)) {
            if (cursor == null) {
                Log.e(TAG, "DownloadManager query returned null cursor.");
                Toast.makeText(this, "无法获取下载列表。", Toast.LENGTH_SHORT).show();
                updateUI(downloadItems);
                return;
            }

            if (cursor.getCount() == 0) {
                Log.d(TAG, "No downloads found in DownloadManager for the current query.");
                updateUI(downloadItems);
                return;
            }
            
            int fileNameColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TITLE);
            int fileSizeColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES);
            int filePathColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI);
            int statusColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS);
            int idColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_ID);
            int bytesDownloadedColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR);
            int reasonColIdx = cursor.getColumnIndex(DownloadManager.COLUMN_REASON);

            Log.d(TAG, "Found " + cursor.getCount() + " downloads.");

            while (cursor.moveToNext()) {
                long downloadId = (idColIdx != -1) ? cursor.getLong(idColIdx) : -1;
                String fileName = (fileNameColIdx != -1) ? cursor.getString(fileNameColIdx) : UNKNOWN_FILE_NAME;
                long fileSize = (fileSizeColIdx != -1) ? cursor.getLong(fileSizeColIdx) : 0;
                String localUriString = (filePathColIdx != -1) ? cursor.getString(filePathColIdx) : null;
                int status = (statusColIdx != -1) ? cursor.getInt(statusColIdx) : DownloadManager.STATUS_FAILED;
                long bytesDownloaded = (bytesDownloadedColIdx != -1) ? cursor.getLong(bytesDownloadedColIdx) : 0;
                int reason = (reasonColIdx != -1) ? cursor.getInt(reasonColIdx) : 0;

                Log.d(TAG, "Processing Download ID: " + downloadId + ", Name: " + fileName + ", Progress: " + bytesDownloaded + "/" + fileSize);

                if (localUriString != null) {
                    Uri localUri = Uri.parse(localUriString);
                    File file = new File(localUri.getPath());

                    // 直接使用 content URI，不依赖 file.exists()
                    Uri contentUri = FileProvider.getUriForFile(this, getApplicationContext().getPackageName() + PROVIDER_AUTHORITY_SUFFIX, file);
                    downloadItems.add(new DownloadItem(fileName, fileSize, file.getAbsolutePath(), status, contentUri, downloadId, bytesDownloaded, reason));
                    Log.d(TAG, "Added download item: " + fileName);
                } else {
                    Log.w(TAG, "Download URI string is null for ID: " + downloadId);
                }
            }
        }
        updateUI(downloadItems);
    }

    /**
     * 更新UI显示下载列表
     */
    private void updateUI(List<DownloadItem> downloadItems) {
        if (downloadItems.isEmpty()) {
            noDownloadsText.setVisibility(View.VISIBLE);
            downloadsRecyclerView.setVisibility(View.GONE);
            Log.d(TAG, "No downloads to display, showing 'no downloads' text.");
        } else {
            noDownloadsText.setVisibility(View.GONE);
            downloadsRecyclerView.setVisibility(View.VISIBLE);
            downloadsAdapter.updateData(downloadItems);
            Log.d(TAG, "Displaying " + downloadItems.size() + " download items.");
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
    public void onDeleteClick(DownloadItem item) {
        showDeleteConfirmationDialog(item);
    }

    /**
     * 显示删除确认对话框
     */
    private void showDeleteConfirmationDialog(DownloadItem item) {
        File file = new File(item.getFilePath());
        boolean fileExists = file.exists();

        // Inflate custom layout for dialog
        View dialogView = getLayoutInflater().inflate(R.layout.dialog_delete_confirmation, null);
        TextView messageTextView = dialogView.findViewById(R.id.delete_message);
        CheckBox deleteFileCheckBox = dialogView.findViewById(R.id.delete_file_checkbox);

        // Always show the same confirmation message
        messageTextView.setText(getString(R.string.delete_download_message, item.getFileName()));
        
        if (fileExists) {
            deleteFileCheckBox.setVisibility(View.VISIBLE);
            deleteFileCheckBox.setChecked(true); // Default to deleting the file
        } else {
            deleteFileCheckBox.setVisibility(View.GONE);
        }

        AlertDialog dialog = new AlertDialog.Builder(this)
            .setView(dialogView)
            .create();

        // 设置对话框背景为透明，使用我们自定义的背景
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        }

        dialog.show();
        
        // 在对话框显示后设置自定义按钮的点击事件
        dialog.findViewById(R.id.delete_button_dialog).setOnClickListener(v -> {
            boolean shouldDeleteFile = fileExists && deleteFileCheckBox.isChecked();
            deleteDownload(item, shouldDeleteFile);
            dialog.dismiss();
        });

        dialog.findViewById(R.id.cancel_button).setOnClickListener(v -> dialog.dismiss());
    }

    /**
     * 删除下载项和文件
     */
    private void deleteDownload(DownloadItem item, boolean deleteFile) {
        try {
            // 从 DownloadManager 中删除记录
            if (item.getDownloadId() != -1) {
                int removed = downloadManager.remove(item.getDownloadId());
                Log.d(TAG, "Removed " + removed + " download record(s) for ID: " + item.getDownloadId());
            }
            
            // 删除文件（如果实际存在）
            boolean fileDeleted = false;
            if (deleteFile) {
                File file = new File(item.getFilePath());
                if (file.exists()) {
                    fileDeleted = file.delete();
                    Log.d(TAG, "File deletion result: " + fileDeleted + " for file: " + item.getFilePath());
                }
            }
            
            // 显示结果消息
            if (deleteFile && fileDeleted) {
                Toast.makeText(this, R.string.download_deleted, Toast.LENGTH_SHORT).show();
            } else if (!deleteFile) {
                Toast.makeText(this, R.string.download_record_deleted, Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, R.string.delete_failed, Toast.LENGTH_SHORT).show();
            }
            
            // 重新加载下载列表
            loadDownloads();
            
        } catch (Exception e) {
            Log.e(TAG, "Error deleting download: " + item.getFileName(), e);
            Toast.makeText(this, R.string.delete_failed, Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        startRefreshing();
    }

    @Override
    protected void onPause() {
        super.onPause();
        stopRefreshing();
    }

    /**
     * 开始实时刷新下载列表
     */
    private void startRefreshing() {
        refreshHandler = new Handler(Looper.getMainLooper());
        refreshRunnable = new Runnable() {
            @Override
            public void run() {
                loadDownloads();
                refreshHandler.postDelayed(this, REFRESH_INTERVAL);
            }
        };
        refreshHandler.post(refreshRunnable);
    }

    /**
     * 停止实时刷新下载列表
     */
    private void stopRefreshing() {
        if (refreshHandler != null && refreshRunnable != null) {
            refreshHandler.removeCallbacks(refreshRunnable);
        }
    }
}
