package link.moely.mobile;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.progressindicator.LinearProgressIndicator;

import java.util.List;

public class DownloadsAdapter extends ListAdapter<DownloadItem, DownloadsAdapter.DownloadViewHolder> {

    private OnItemClickListener listener;
    private Context context;

    // 列表更新
    private static final DiffUtil.ItemCallback<DownloadItem> DIFF_CALLBACK = new DiffUtil.ItemCallback<DownloadItem>() {
        @Override
        public boolean areItemsTheSame(@NonNull DownloadItem oldItem, @NonNull DownloadItem newItem) {
            // 根据文件路径和下载ID判断是否为同一项
            return oldItem.getFilePath().equals(newItem.getFilePath()) && 
                   oldItem.getDownloadId() == newItem.getDownloadId();
        }

        @Override
        public boolean areContentsTheSame(@NonNull DownloadItem oldItem, @NonNull DownloadItem newItem) {
            // 使用 equals 方法比较内容是否相同
            return oldItem.equals(newItem);
        }
    };

    public interface OnItemClickListener {
        void onItemClick(DownloadItem item);
        void onDeleteClick(DownloadItem item);
    }

    public DownloadsAdapter(Context context, OnItemClickListener listener) {
        super(DIFF_CALLBACK);
        this.context = context;
        this.listener = listener;
    }

    @NonNull
    @Override
    public DownloadViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_download, parent, false);
        return new DownloadViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull DownloadViewHolder holder, int position) {
        DownloadItem item = getItem(position); // 使用 getItem() 从 ListAdapter 获取项
        holder.bind(item, context, listener);
    }

    /**
     * 更新数据列表
     */
    public void updateData(List<DownloadItem> newDownloadList) {
        submitList(newDownloadList);
    }

    static class DownloadViewHolder extends RecyclerView.ViewHolder {
        private final TextView fileNameTextView;
        private final TextView fileSizeTextView;
        private final TextView fileStatusTextView;
        private final MaterialButton deleteButton;
        private final View downloadItemContainer;
        private final LinearProgressIndicator downloadProgressBar;
        private final TextView downloadProgressText;

        DownloadViewHolder(@NonNull View itemView) {
            super(itemView);
            fileNameTextView = itemView.findViewById(R.id.fileNameTextView);
            fileSizeTextView = itemView.findViewById(R.id.fileSizeTextView);
            fileStatusTextView = itemView.findViewById(R.id.fileStatusTextView);
            deleteButton = itemView.findViewById(R.id.deleteButton);
            downloadItemContainer = itemView.findViewById(R.id.download_item_container);
            downloadProgressBar = itemView.findViewById(R.id.downloadProgressBar);
            downloadProgressText = itemView.findViewById(R.id.downloadProgressText);
        }

        void bind(DownloadItem item, Context context, OnItemClickListener listener) {
            fileNameTextView.setText(item.getFileName());
            fileSizeTextView.setText(String.format("大小: %s", item.getFormattedFileSize()));
            fileStatusTextView.setText(String.format("状态: %s", item.getStatusString(context)));

            if (item.shouldShowProgress()) {
                downloadProgressBar.setVisibility(View.VISIBLE);
                downloadProgressText.setVisibility(View.VISIBLE);
                downloadProgressBar.setProgress(item.getProgressPercentage());
                downloadProgressText.setText(item.getProgressText());
            } else {
                downloadProgressBar.setVisibility(View.GONE);
                downloadProgressText.setVisibility(View.GONE);
            }

            // 点击下载项打开文件
            downloadItemContainer.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onItemClick(item);
                }
            });

            // 点击删除按钮
            deleteButton.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onDeleteClick(item);
                }
            });
        }
    }
}
