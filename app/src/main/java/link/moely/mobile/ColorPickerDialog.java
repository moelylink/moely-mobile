package link.moely.mobile;

import android.app.Activity;
import android.app.WallpaperManager;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;
import android.view.View;
import android.view.ViewGroup;
import android.widget.GridLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;
import androidx.palette.graphics.Palette;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;

public class ColorPickerDialog {

    public interface OnColorSelectedListener {
        void onColorSelected(int color, String colorName);
    }

    private OnColorSelectedListener listener;
    private int selectedColor;
    private String selectedColorName;

    // 预定义颜色数组
    private static final ColorItem[] PREDEFINED_COLORS = {
        new ColorItem("淡紫", "#ba85fb"),
        new ColorItem("蓝紫", "#9C27B0"),
        new ColorItem("深蓝", "#3F51B5"),
        new ColorItem("蓝色", "#2196F3"),
        new ColorItem("天蓝", "#03DAC6"),
        new ColorItem("青色", "#00BCD4"),
        new ColorItem("绿色", "#4CAF50"),
        new ColorItem("浅绿", "#8BC34A"),
        new ColorItem("橙色", "#FF9800"),
        new ColorItem("深橙", "#FF5722"),
        new ColorItem("红色", "#F44336"),
        new ColorItem("粉红", "#E91E63"),
        new ColorItem("棕色", "#795548"),
        new ColorItem("灰色", "#607D8B"),
        new ColorItem("深灰", "#424242")
    };

    private static class ColorItem {
        String name;
        String hex;
        int color;

        ColorItem(String name, String hex) {
            this.name = name;
            this.hex = hex;
            this.color = Color.parseColor(hex);
        }
    }

    private Context context;
    private AlertDialog dialog;
    
    public ColorPickerDialog(@NonNull Context context, int currentColor) {
        this.context = context;
        this.selectedColor = currentColor;
        // 查找当前颜色对应的名称
        for (ColorItem item : PREDEFINED_COLORS) {
            if (item.color == currentColor) {
                selectedColorName = item.name;
                break;
            }
        }
        if (selectedColorName == null) {
            selectedColorName = "自定义";
        }
    }

    public void setOnColorSelectedListener(OnColorSelectedListener listener) {
        this.listener = listener;
    }

    public void show() {
        View view = ((Activity) context).getLayoutInflater().inflate(R.layout.dialog_color_picker, null);
        
        GridLayout colorGrid = view.findViewById(R.id.colorGrid);
        TextView selectedColorText = view.findViewById(R.id.selectedColorText);
        
        // 初始化颜色网格
        setupColorGrid(colorGrid, selectedColorText);
        
        // 更新选中颜色显示
        updateSelectedColorDisplay(selectedColorText);
        
        dialog = new AlertDialog.Builder(context)
                .setTitle("选择主题色")
                .setView(view)
                .setPositiveButton("确定", (d, which) -> {
                    if (listener != null) {
                        listener.onColorSelected(selectedColor, selectedColorName);
                    }
                })
                .setNegativeButton("取消", null)
                .create();
        
        dialog.show();
    }

    private void setupColorGrid(GridLayout colorGrid, TextView selectedColorText) {
        colorGrid.setColumnCount(4);
        colorGrid.setRowCount((PREDEFINED_COLORS.length + 3) / 4);
        
        for (ColorItem item : PREDEFINED_COLORS) {
            MaterialCardView colorCard = createColorCard(item, selectedColorText);
            colorGrid.addView(colorCard);
        }
        
        // 添加动态颜色提取卡片
        MaterialCardView dynamicCard = createDynamicColorCard(selectedColorText);
        colorGrid.addView(dynamicCard);
    }

    private MaterialCardView createColorCard(ColorItem colorItem, TextView selectedColorText) {
        MaterialCardView card = new MaterialCardView(context);
        
        // 设置卡片布局参数
        GridLayout.LayoutParams params = new GridLayout.LayoutParams();
        params.width = dpToPx(60);
        params.height = dpToPx(60);
        params.setMargins(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8));
        card.setLayoutParams(params);
        
        // 设置卡片样式
        card.setCardElevation(dpToPx(4));
        card.setRadius(dpToPx(8));
        card.setClickable(true);
        card.setFocusable(true);
        
        // 创建颜色显示View
        View colorView = new View(context);
        ViewGroup.LayoutParams colorParams = new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        );
        colorView.setLayoutParams(colorParams);
        
        // 设置背景颜色
        GradientDrawable background = new GradientDrawable();
        background.setColor(colorItem.color);
        background.setCornerRadius(dpToPx(8));
        colorView.setBackground(background);
        
        card.addView(colorView);
        
        // 如果是当前选中的颜色，添加边框
        if (colorItem.color == selectedColor) {
            card.setStrokeColor(Color.WHITE);
            card.setStrokeWidth(dpToPx(3));
        }
        
        // 设置点击事件
        card.setOnClickListener(v -> {
            selectedColor = colorItem.color;
            selectedColorName = colorItem.name;
            updateSelectedColorDisplay(selectedColorText);
            updateCardSelection((GridLayout) card.getParent(), card);
        });
        
        return card;
    }
    
    private void updateCardSelection(GridLayout parent, MaterialCardView selectedCard) {
        // 重置所有卡片的边框
        for (int i = 0; i < parent.getChildCount(); i++) {
            MaterialCardView card = (MaterialCardView) parent.getChildAt(i);
            card.setStrokeWidth(0);
        }
        
        // 为选中的卡片添加边框
        selectedCard.setStrokeColor(Color.WHITE);
        selectedCard.setStrokeWidth(dpToPx(3));
    }
    
    private void updateSelectedColorDisplay(TextView textView) {
        textView.setText(String.format("已选择：%s (%s)", 
            selectedColorName, String.format("#%06X", (0xFFFFFF & selectedColor))));
        
        // 设置文本颜色为选中的颜色
        textView.setTextColor(selectedColor);
    }
    
    private MaterialCardView createDynamicColorCard(TextView selectedColorText) {
        MaterialCardView card = new MaterialCardView(context);
        
        // 设置卡片布局参数
        GridLayout.LayoutParams params = new GridLayout.LayoutParams();
        params.width = dpToPx(60);
        params.height = dpToPx(60);
        params.setMargins(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8));
        card.setLayoutParams(params);
        
        // 设置卡片样式
        card.setCardElevation(dpToPx(4));
        card.setRadius(dpToPx(8));
        card.setClickable(true);
        card.setFocusable(true);
        
        // 创建渐变背景显示动态颜色
        View colorView = new View(context);
        ViewGroup.LayoutParams colorParams = new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        );
        colorView.setLayoutParams(colorParams);
        
        // 设置渐变背景 - 更舒适的渐变色彩
        GradientDrawable background = new GradientDrawable();
        // 使用更柔和的渐变色：紫色到蓝色到青色的线性渐变
        int[] colors = {
            Color.parseColor("#667eea"), // 柔和的紫蓝色
            Color.parseColor("#764ba2"), // 优雅的紫色
            Color.parseColor("#f093fb")  // 温和的粉紫色
        };
        background.setColors(colors);
        background.setGradientType(GradientDrawable.LINEAR_GRADIENT);
        background.setOrientation(GradientDrawable.Orientation.TL_BR); // 从左上到右下的线性渐变
        background.setCornerRadius(dpToPx(8));
        colorView.setBackground(background);
        
        card.addView(colorView);
        
        // 设置点击事件
        card.setOnClickListener(v -> {
            // 检查权限
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ 需要 MANAGE_EXTERNAL_STORAGE 权限来访问壁纸
                if (!Environment.isExternalStorageManager()) {
                    // 显示对话框引导用户授权
                    new androidx.appcompat.app.AlertDialog.Builder(context)
                        .setTitle("需要文件管理权限")
                        .setMessage("为了从壁纸提取主题色，需要授予文件管理权限。点击确定前往设置页面。")
                        .setPositiveButton("前往设置", (dialog, which) -> {
                            try {
                                Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                                intent.setData(Uri.parse("package:" + context.getPackageName()));
                                context.startActivity(intent);
                            } catch (Exception e) {
                                // 如果无法打开具体应用的设置页面，打开通用设置页面
                                Intent intent = new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
                                context.startActivity(intent);
                            }
                        })
                        .setNegativeButton("取消", null)
                        .show();
                    return;
                }
            } else {
                // Android 10 及以下版本的权限检查
                String permission;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    permission = android.Manifest.permission.READ_MEDIA_IMAGES;
                } else {
                    permission = android.Manifest.permission.READ_EXTERNAL_STORAGE;
                }
                
                if (ContextCompat.checkSelfPermission(context, permission)
                        != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    Toast.makeText(context, "需要存储权限才能从壁纸提取颜色", Toast.LENGTH_SHORT).show();
                    Log.w("ColorPickerDialog", "Permission not granted for dynamic color extraction");
                    return;
                }
            }
            
            // 有权限，直接提取颜色
            extractDynamicColor(selectedColorText, (GridLayout) card.getParent(), card);
        });
        
        return card;
    }
    
    private void extractDynamicColor(TextView selectedColorText, GridLayout parent, MaterialCardView dynamicCard) {
        try {
            Log.d("ColorPickerDialog", "Starting dynamic color extraction...");
            // 加载当前壁纸
            WallpaperManager wallpaperManager = WallpaperManager.getInstance(context);
            Log.d("ColorPickerDialog", "WallpaperManager instance obtained");
            Drawable wallpaperDrawable = wallpaperManager.getDrawable();
            Log.d("ColorPickerDialog", "Wallpaper drawable type: " + (wallpaperDrawable != null ? wallpaperDrawable.getClass().getSimpleName() : "null"));
            if (wallpaperDrawable instanceof BitmapDrawable) {
                Bitmap bitmap = ((BitmapDrawable) wallpaperDrawable).getBitmap();
                if (bitmap != null) {
                    Log.d("ColorPickerDialog", "Bitmap obtained from wallpaper");
                    // 使用Palette提取主色
                    Palette.from(bitmap).generate(palette -> {
                        if (palette != null) {
                            Log.d("ColorPickerDialog", "Palette generated");
                            // 获取鲜艳主色，如果没有则获取主色
                            int dominantColor = palette.getVibrantColor(palette.getDominantColor(Color.parseColor("#ba85fb")));
                            Log.d("ColorPickerDialog", "Dominant color extracted: " + String.format("#%06X", (0xFFFFFF & dominantColor)));
                            // 更新选中的颜色
                            selectedColor = dominantColor;
                            selectedColorName = "动态提取色";
                            
                            // 更新显示
                            updateSelectedColorDisplay(selectedColorText);
                            updateCardSelection(parent, dynamicCard);
                            
                            // 更新动态卡片的背景色
                            View colorView = dynamicCard.getChildAt(0);
                            GradientDrawable background = new GradientDrawable();
                            background.setColor(dominantColor);
                            background.setCornerRadius(dpToPx(8));
                            colorView.setBackground(background);
                        } else {
                            Log.w("ColorPickerDialog", "Palette is null");
                        }
                    });
                } else {
                    Log.w("ColorPickerDialog", "Bitmap is null");
                }
            } else {
                Log.w("ColorPickerDialog", "Wallpaper is not a BitmapDrawable");
                Toast.makeText(context, "无法提取壁纸主色", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception e) {
            Log.e("ColorPickerDialog", "Error extracting color", e);
            // 如果找不到图片或出现错误，使用默认颜色
            selectedColor = Color.parseColor("#ba85fb");
            selectedColorName = "动态提取色";
            updateSelectedColorDisplay(selectedColorText);
            updateCardSelection(parent, dynamicCard);
        }
    }
    
    private int dpToPx(int dp) {
        float density = context.getResources().getDisplayMetrics().density;
        return Math.round(dp * density);
    }
}
