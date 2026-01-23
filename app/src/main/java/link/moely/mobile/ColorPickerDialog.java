package link.moely.mobile;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.View;
import android.view.ViewGroup;
import android.widget.GridLayout;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;

import com.google.android.material.card.MaterialCardView;

// 【修改点1】删除了这里原本冲突的 import com.skydoves.colorpickerview.ColorPickerDialog;
import com.skydoves.colorpickerview.listeners.ColorEnvelopeListener;

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
        boolean found = false;
        for (ColorItem item : PREDEFINED_COLORS) {
            if (item.color == currentColor) {
                selectedColorName = item.name;
                found = true;
                break;
            }
        }
        if (!found) {
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
        // 计算行数
        colorGrid.setRowCount((PREDEFINED_COLORS.length + 3) / 4);
        
        for (ColorItem item : PREDEFINED_COLORS) {
            SquareMaterialCardView colorCard = createColorCard(item, selectedColorText);
            colorGrid.addView(colorCard);
        }
        
        // 添加自定义/调色板卡片
        SquareMaterialCardView customCard = createCustomColorCard(selectedColorText);
        colorGrid.addView(customCard);
    }

    private SquareMaterialCardView createColorCard(ColorItem colorItem, TextView selectedColorText) {
        SquareMaterialCardView card = new SquareMaterialCardView(context);
        
        // 设置卡片布局参数
        GridLayout.LayoutParams params = new GridLayout.LayoutParams();
        params.width = 0; 
        params.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f); 
        params.height = ViewGroup.LayoutParams.WRAP_CONTENT; 
        params.setMargins(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8));
        card.setLayoutParams(params);
        
        card.setCardElevation(dpToPx(4));
        card.setRadius(dpToPx(8));
        card.setClickable(true);
        card.setFocusable(true);
        
        View colorView = new View(context);
        ViewGroup.LayoutParams colorParams = new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        );
        colorView.setLayoutParams(colorParams);
        
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
        
        card.setOnClickListener(v -> {
            selectedColor = colorItem.color;
            selectedColorName = colorItem.name;
            updateSelectedColorDisplay(selectedColorText);
            updateCardSelection((GridLayout) card.getParent(), card);
        });
        
        return card;
    }
    
    private void updateCardSelection(GridLayout parent, SquareMaterialCardView selectedCard) {
        // 重置所有卡片的边框
        for (int i = 0; i < parent.getChildCount(); i++) {
            View child = parent.getChildAt(i);
            if (child instanceof SquareMaterialCardView) {
                ((SquareMaterialCardView) child).setStrokeWidth(0);
            }
        }
        
        // 为选中的卡片添加边框
        selectedCard.setStrokeColor(Color.WHITE);
        selectedCard.setStrokeWidth(dpToPx(3));
    }
    
    private void updateSelectedColorDisplay(TextView textView) {
        textView.setText(String.format("已选择：%s (%s)", 
            selectedColorName, String.format("#%06X", (0xFFFFFF & selectedColor))));
        textView.setTextColor(selectedColor);
    }
    
    /**
     * 创建自定义颜色卡片（点击打开调色板）
     */
    private SquareMaterialCardView createCustomColorCard(TextView selectedColorText) {
        SquareMaterialCardView card = new SquareMaterialCardView(context);
        
        GridLayout.LayoutParams params = new GridLayout.LayoutParams();
        params.width = 0;
        params.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
        params.height = ViewGroup.LayoutParams.WRAP_CONTENT;
        params.setMargins(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8));
        card.setLayoutParams(params);
        
        card.setCardElevation(dpToPx(4));
        card.setRadius(dpToPx(8));
        card.setClickable(true);
        card.setFocusable(true);
        
        // 创建颜色显示 View
        View colorView = new View(context);
        ViewGroup.LayoutParams colorParams = new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        );
        colorView.setLayoutParams(colorParams);
        
        // 定义最终要设置的 Drawable
        android.graphics.drawable.Drawable finalDrawable;

        // 判断当前选中的颜色是否是预定义颜色列表之外的“自定义颜色”
        // 如果是，直接显示该颜色；如果不是，显示一个调色板图案代表“点击自定义”
        boolean isPredefined = false;
        for (ColorItem item : PREDEFINED_COLORS) {
            if (item.color == selectedColor) {
                isPredefined = true;
                break;
            }
        }

        if (!isPredefined) {
            // 当前已经是自定义颜色，显示该颜色
            GradientDrawable background = new GradientDrawable();
            background.setCornerRadius(dpToPx(8));
            background.setColor(selectedColor);
            finalDrawable = background;

            // 同时给这个卡片加上选中框
            card.setStrokeColor(Color.WHITE);
            card.setStrokeWidth(dpToPx(3));
        } else {
            // 当前选中的是预定义颜色，这里显示一个调色板图案作为“入口”指示

            // 1. 创建底层的彩虹渐变背景
            GradientDrawable rainbowBackground = new GradientDrawable();
            rainbowBackground.setCornerRadius(dpToPx(8));
            int[] rainbowColors = {
                Color.parseColor("#FF0000"), // 红
                Color.parseColor("#FFFF00"), // 黄
                Color.parseColor("#00FF00"), // 绿
                Color.parseColor("#00FFFF"), // 青
                Color.parseColor("#0000FF"), // 蓝
                Color.parseColor("#FF00FF")  // 紫
            };
            rainbowBackground.setColors(rainbowColors);
            rainbowBackground.setGradientType(GradientDrawable.SWEEP_GRADIENT);

            // 2. 创建一个前景图标来表示“调色板”
            // 【建议】为了获得更好的视觉效果，请准备一个调色板图标资源(例如 R.drawable.ic_palette)，
            // 然后在这里使用: Drawable paletteIcon = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_palette);
            // 这里为了代码可以直接运行且不依赖新资源，我们用一个简单的半透明白色圆圈作为示意图案。
            GradientDrawable paletteIcon = new GradientDrawable();
            paletteIcon.setColor(Color.parseColor("#80FFFFFF")); // 半透明白色
            paletteIcon.setShape(GradientDrawable.OVAL);
            int iconSize = dpToPx(20); // 图标大小
            paletteIcon.setSize(iconSize, iconSize);

            // 3. 使用 LayerDrawable 将背景和图标叠加，形成图案
            android.graphics.drawable.LayerDrawable layerDrawable = new android.graphics.drawable.LayerDrawable(new android.graphics.drawable.Drawable[]{rainbowBackground, paletteIcon});
            
            // 4. 设置图标在中间显示
            layerDrawable.setLayerGravity(1, android.view.Gravity.CENTER);
            
            finalDrawable = layerDrawable;
        }
        
        colorView.setBackground(finalDrawable);
        card.addView(colorView);
        
        // 点击事件：打开调色板
        card.setOnClickListener(v -> {
            showColorPickerWheel(card, colorView, selectedColorText);
        });
        
        return card;
    }

    /**
     * 显示圆形调色板对话框
     */
    private void showColorPickerWheel(SquareMaterialCardView customCard, View colorView, TextView selectedColorText) {
        // 【修改点2】这里使用 com.skydoves.colorpickerview.ColorPickerDialog 全名
        // 这样编译器就能区分“你的类”和“第三方库的类”了
        new com.skydoves.colorpickerview.ColorPickerDialog.Builder(context)
                .setTitle("自定义颜色")
                .setPreferenceName("MoelyColorPicker") // 保存上次选择
                .setPositiveButton("确定",
                        (ColorEnvelopeListener) (envelope, fromUser) -> {
                            // 获取用户选择的颜色
                            int color = envelope.getColor();
                            String hex = "#" + envelope.getHexCode();
                            
                            // 1. 更新内部状态
                            selectedColor = color;
                            selectedColorName = hex; // 名称直接显示 HEX 代码
                            
                            // 2. 更新顶部文字显示
                            updateSelectedColorDisplay(selectedColorText);
                            
                            // 3. 更新选中框（高亮这个自定义卡片）
                            updateCardSelection((GridLayout) customCard.getParent(), customCard);
                            
                            // 4. 【重要】将自定义卡片的调色板图案背景变为选中的纯色
                            GradientDrawable newBg = new GradientDrawable();
                            newBg.setColor(color);
                            newBg.setCornerRadius(dpToPx(8));
                            colorView.setBackground(newBg);
                        })
                .setNegativeButton("取消", (dialogInterface, i) -> dialogInterface.dismiss())
                .attachAlphaSlideBar(false) // 不需要透明度
                .attachBrightnessSlideBar(true) // 添加亮度条
                .setBottomSpace(12) 
                .show();
    }
    
    private int dpToPx(int dp) {
        float density = context.getResources().getDisplayMetrics().density;
        return Math.round(dp * density);
    }
}
