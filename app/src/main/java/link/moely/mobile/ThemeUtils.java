package link.moely.mobile;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.drawable.ColorDrawable;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AppCompatActivity;
import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;

public class ThemeUtils {
    
    /**
     * 应用主题色到Activity
     */
    public static void applyTheme(Activity activity) {
        ThemeManager themeManager = ThemeManager.getInstance(activity);
        int primaryColor = themeManager.getPrimaryColor();
        int primaryDarkColor = themeManager.getPrimaryDarkColor();
        
        // 设置状态栏颜色
        Window window = activity.getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
        window.setStatusBarColor(primaryDarkColor);
        
        // 根据状态栏颜色亮度设置状态栏图标颜色
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            View decorView = window.getDecorView();
            int flags = decorView.getSystemUiVisibility();
            if (isLightColor(primaryDarkColor)) {
                // 深色状态栏图标（用于浅色背景）
                flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            } else {
                // 浅色状态栏图标（用于深色背景）
                flags &= ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            }
            decorView.setSystemUiVisibility(flags);
        }
        
        // 设置ActionBar颜色（如果存在）
        if (activity instanceof AppCompatActivity) {
            AppCompatActivity appCompatActivity = (AppCompatActivity) activity;
            ActionBar actionBar = appCompatActivity.getSupportActionBar();
            if (actionBar != null) {
                actionBar.setBackgroundDrawable(new ColorDrawable(primaryColor));
            }
        }
    }
    
    /**
     * 应用主题色到MaterialToolbar
     */
    public static void applyThemeToToolbar(MaterialToolbar toolbar) {
        if (toolbar == null) return;
        
        ThemeManager themeManager = ThemeManager.getInstance(toolbar.getContext());
        int primaryColor = themeManager.getPrimaryColor();
        int textColor = themeManager.getTextColorOnPrimary();
        
        toolbar.setBackgroundColor(primaryColor);
        toolbar.setTitleTextColor(textColor);
        
        // 确保导航图标着色
        if (toolbar.getNavigationIcon() != null) {
            toolbar.getNavigationIcon().setTint(textColor);
        }
        toolbar.setNavigationIconTint(textColor);
        
        // 设置菜单图标颜色
        if (toolbar.getMenu() != null && toolbar.getMenu().size() > 0) {
            for (int i = 0; i < toolbar.getMenu().size(); i++) {
                if (toolbar.getMenu().getItem(i).getIcon() != null) {
                    toolbar.getMenu().getItem(i).getIcon().setTint(textColor);
                }
            }
        }
        
        // 设置溢出菜单图标颜色
        if (toolbar.getOverflowIcon() != null) {
            toolbar.getOverflowIcon().setTint(textColor);
        }
    }
    
    /**
     * 应用主题色到MaterialButton
     */
    public static void applyThemeToButton(MaterialButton button, boolean isAccent) {
        if (button == null) return;
        
        ThemeManager themeManager = ThemeManager.getInstance(button.getContext());
        int color = isAccent ? themeManager.getAccentColor() : themeManager.getPrimaryColor();
        
        button.setBackgroundTintList(ColorStateList.valueOf(color));
    }
    
    /**
     * 应用主题色到MaterialCardView
     */
    public static void applyThemeToCard(MaterialCardView card) {
        if (card == null) return;
        
        ThemeManager themeManager = ThemeManager.getInstance(card.getContext());
        int primaryColor = themeManager.getPrimaryColor();
        
        card.setStrokeColor(primaryColor);
    }
    
    /**
     * 获取当前主题的主要颜色
     */
    public static int getPrimaryColor(View view) {
        return ThemeManager.getInstance(view.getContext()).getPrimaryColor();
    }
    
    /**
     * 获取当前主题的强调色
     */
    public static int getAccentColor(View view) {
        return ThemeManager.getInstance(view.getContext()).getAccentColor();
    }
    
    /**
     * 获取适合在主题色上显示的文本颜色
     */
    public static int getTextColorOnPrimary(View view) {
        return ThemeManager.getInstance(view.getContext()).getTextColorOnPrimary();
    }
    
    /**
     * 判断颜色是否为浅色（用于状态栏图标颜色判断）
     */
    private static boolean isLightColor(int color) {
        double darkness = 1 - (0.299 * android.graphics.Color.red(color) + 0.587 * android.graphics.Color.green(color) + 0.114 * android.graphics.Color.blue(color)) / 255;
        return darkness < 0.5;
    }
}
