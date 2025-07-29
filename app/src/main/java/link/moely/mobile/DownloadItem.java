package link.moely.mobile;

import android.net.Uri;
import android.app.DownloadManager;
import android.content.Context;

/**
 * 用于表示下载文件项的数据类。
 */
public class DownloadItem {
    private String fileName;
    private long fileSize; // 字节数
    private String filePath; // 文件的完整路径
    private int status; // DownloadManager.STATUS_SUCCESSFUL, STATUS_FAILED 等。
    private Uri fileUri; // FileProvider 的 Uri

    public DownloadItem(String fileName, long fileSize, String filePath, int status, Uri fileUri) {
        this.fileName = fileName;
        this.fileSize = fileSize;
        this.filePath = filePath;
        this.status = status;
        this.fileUri = fileUri;
    }

    public String getFileName() {
        return fileName;
    }

    public long getFileSize() {
        return fileSize;
    }

    public String getFilePath() {
        return filePath;
    }

    public int getStatus() {
        return status;
    }

    public Uri getFileUri() {
        return fileUri;
    }

    // 辅助方法，将字节转换为人类可读的大小
    public String getFormattedFileSize() {
        if (fileSize <= 0) return "0 B";
        final String[] units = new String[] { "B", "KB", "MB", "GB", "TB" };
        int digitGroups = (int) (Math.log10(fileSize) / Math.log10(1024));
        return String.format("%.2f %s", (double)fileSize / Math.pow(1024, digitGroups), units[digitGroups]);
    }

    // 辅助方法，获取状态字符串
    public String getStatusString(Context context) {
        switch (status) {
            case DownloadManager.STATUS_SUCCESSFUL:
                return context.getString(R.string.download_completed);
            case DownloadManager.STATUS_FAILED:
                return context.getString(R.string.download_failed);
            case DownloadManager.STATUS_PENDING:
                return context.getString(R.string.download_pending);
            case DownloadManager.STATUS_RUNNING:
                return context.getString(R.string.download_running);
            case DownloadManager.STATUS_PAUSED:
                return context.getString(R.string.download_paused);
            default:
                return "未知状态";
        }
    }
}
