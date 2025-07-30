package link.moely.mobile;

import android.net.Uri;
import android.app.DownloadManager;
import android.content.Context;
import java.util.Objects;

/**
 * 用于表示下载文件项的数据类。
 */
public class DownloadItem {
    private final String fileName;
    private final long fileSize; // 字节数
    private final String filePath; // 文件的完整路径
    private final int status; // DownloadManager.STATUS_SUCCESSFUL, STATUS_FAILED 等。
    private final Uri fileUri; // FileProvider 的 Uri
    private final long downloadId; // DownloadManager ID
    private final long bytesDownloaded; // 已下载字节数
    private final int reason; // 失败或暂停原因
    
    // 常量定义
    private static final String[] SIZE_UNITS = {"B", "KB", "MB", "GB", "TB"};
    private static final int BYTES_PER_UNIT = 1024;
    private static final String UNKNOWN_STATUS = "未知状态";
    private static final String DEFAULT_FILE_NAME = "未知文件";

    public DownloadItem(String fileName, long fileSize, String filePath, int status, Uri fileUri) {
        this(fileName, fileSize, filePath, status, fileUri, -1L, 0L, 0);
    }

    public DownloadItem(String fileName, long fileSize, String filePath, int status, Uri fileUri, long downloadId) {
        this(fileName, fileSize, filePath, status, fileUri, downloadId, 0L, 0);
    }

    public DownloadItem(String fileName, long fileSize, String filePath, int status, Uri fileUri, 
                       long downloadId, long bytesDownloaded, int reason) {
        this.fileName = fileName != null ? fileName : DEFAULT_FILE_NAME;
        this.fileSize = Math.max(0, fileSize);
        this.filePath = filePath;
        this.status = status;
        this.fileUri = fileUri;
        this.downloadId = downloadId;
        this.bytesDownloaded = Math.max(0, bytesDownloaded);
        this.reason = reason;
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

    public long getDownloadId() {
        return downloadId;
    }
    
    public long getBytesDownloaded() {
        return bytesDownloaded;
    }

    public int getReason() {
        return reason;
    }

    // 将字节转换为可读数值
    public String getFormattedFileSize() {
        if (fileSize <= 0) return "0 B";
        int digitGroups = (int) (Math.log10(fileSize) / Math.log10(BYTES_PER_UNIT));
        digitGroups = Math.min(digitGroups, SIZE_UNITS.length - 1);
        return String.format("%.2f %s", (double)fileSize / Math.pow(BYTES_PER_UNIT, digitGroups), SIZE_UNITS[digitGroups]);
    }

    // 获取下载进度（0-100）
    public int getProgressPercentage() {
        if (fileSize <= 0) return 0;
        return (int) ((bytesDownloaded * 100) / fileSize);
    }

    // 获取进度文本
    public String getProgressText() {
        if (fileSize <= 0) return "0%";
        int percentage = getProgressPercentage();
        String downloadedFormatted = formatBytes(bytesDownloaded);
        String totalFormatted = getFormattedFileSize();
        return String.format("%d%% (%s / %s)", percentage, downloadedFormatted, totalFormatted);
    }

    // 格式化字节数
    private String formatBytes(long bytes) {
        if (bytes <= 0) return "0 B";
        int digitGroups = (int) (Math.log10(bytes) / Math.log10(BYTES_PER_UNIT));
        digitGroups = Math.min(digitGroups, SIZE_UNITS.length - 1);
        return String.format("%.2f %s", (double)bytes / Math.pow(BYTES_PER_UNIT, digitGroups), SIZE_UNITS[digitGroups]);
    }

    // 是否正在下载
    public boolean isDownloading() {
        return status == DownloadManager.STATUS_RUNNING;
    }

    // 是否需要显示进度
    public boolean shouldShowProgress() {
        return status == DownloadManager.STATUS_RUNNING || 
               status == DownloadManager.STATUS_PAUSED ||
               status == DownloadManager.STATUS_PENDING;
    }

    // 获取状态字符串
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
                return UNKNOWN_STATUS;
        }
    }

    // 用于 DiffUtil 比较的方法
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        DownloadItem that = (DownloadItem) o;
        return fileSize == that.fileSize &&
                status == that.status &&
                downloadId == that.downloadId &&
                bytesDownloaded == that.bytesDownloaded &&
                reason == that.reason &&
                Objects.equals(fileName, that.fileName) &&
                Objects.equals(filePath, that.filePath) &&
                Objects.equals(fileUri, that.fileUri);
    }

    @Override
    public int hashCode() {
        return Objects.hash(fileName, fileSize, filePath, status, fileUri, downloadId, bytesDownloaded, reason);
    }
}
