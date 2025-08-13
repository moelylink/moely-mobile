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
import android.os.Build;
public class ThemeUtils {
    
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

    public static void applyThemeToStatusBar(Activity activity) {
        if (activity == null) return;

        Window window = activity.getWindow();
        ThemeManager themeManager = ThemeManager.getInstance(activity);
        int primaryColor = themeManager.getPrimaryColor();

        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.setStatusBarColor(primaryColor);

        // Set status bar icon colors based on background color
        View decorView = window.getDecorView();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (isLightColor(primaryColor)) {
                decorView.setSystemUiVisibility(decorView.getSystemUiVisibility() | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
            } else {
                decorView.setSystemUiVisibility(decorView.getSystemUiVisibility() & ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
            }
        }
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
