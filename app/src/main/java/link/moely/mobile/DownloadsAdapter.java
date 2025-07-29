package link.moely.mobile;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import java.util.List;

public class DownloadsAdapter extends RecyclerView.Adapter<DownloadsAdapter.DownloadViewHolder> {

    private List<DownloadItem> downloadList;
    private OnItemClickListener listener;
    private Context context;

    public interface OnItemClickListener {
        void onItemClick(DownloadItem item);
    }

    public DownloadsAdapter(Context context, List<DownloadItem> downloadList, OnItemClickListener listener) {
        this.context = context;
        this.downloadList = downloadList;
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
        DownloadItem item = downloadList.get(position);
        holder.fileNameTextView.setText(item.getFileName());
        holder.fileSizeTextView.setText(String.format("大小: %s", item.getFormattedFileSize()));
        holder.fileStatusTextView.setText(String.format("状态: %s", item.getStatusString(context)));

        holder.itemView.setOnClickListener(v -> listener.onItemClick(item));
    }

    @Override
    public int getItemCount() {
        return downloadList.size();
    }

    public void updateData(List<DownloadItem> newDownloadList) {
        this.downloadList.clear();
        this.downloadList.addAll(newDownloadList);
        notifyDataSetChanged();
    }

    static class DownloadViewHolder extends RecyclerView.ViewHolder {
        TextView fileNameTextView;
        TextView fileSizeTextView;
        TextView fileStatusTextView;

        DownloadViewHolder(@NonNull View itemView) {
            super(itemView);
            fileNameTextView = itemView.findViewById(R.id.fileNameTextView);
            fileSizeTextView = itemView.findViewById(R.id.fileSizeTextView);
            fileStatusTextView = itemView.findViewById(R.id.fileStatusTextView);
        }
    }
}
