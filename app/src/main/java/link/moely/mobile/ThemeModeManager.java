package link.moely.mobile;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.appcompat.app.AppCompatDelegate;

public class ThemeModeManager {
    private static final String PREFS_NAME = "MoelyThemeModePrefs";
    private static final String KEY_THEME_MODE = "theme_mode";
    
    // 主题模式常量
    public static final int MODE_LIGHT = 0;
    public static final int MODE_DARK = 1;
    public static final int MODE_SYSTEM = 2;
    
    private static ThemeModeManager instance;
    private SharedPreferences prefs;
    private Context context;
    
    private ThemeModeManager(Context context) {
        this.context = context.getApplicationContext();
        this.prefs = this.context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }
    
    public static synchronized ThemeModeManager getInstance(Context context) {
        if (instance == null) {
            instance = new ThemeModeManager(context);
        }
        return instance;
    }
    
    /**
     * 设置主题模式
     */
    public void setThemeMode(int mode) {
        prefs.edit().putInt(KEY_THEME_MODE, mode).apply();
        applyThemeMode(mode);
    }
    
    /**
     * 设置主题模式（不立即应用）
     */
    public void setThemeModeOnly(int mode) {
        prefs.edit().putInt(KEY_THEME_MODE, mode).apply();
    }
    
    /**
     * 获取当前主题模式
     */
    public int getThemeMode() {
        return prefs.getInt(KEY_THEME_MODE, MODE_SYSTEM); // 默认跟随系统
    }
    
    /**
     * 应用主题模式
     */
    public void applyThemeMode(int mode) {
        switch (mode) {
            case MODE_LIGHT:
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO);
                break;
            case MODE_DARK:
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES);
                break;
            case MODE_SYSTEM:
            default:
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
                break;
        }
    }
    
    /**
     * 初始化应用时应用保存的主题模式
     */
    public void initializeTheme() {
        int savedMode = getThemeMode();
        applyThemeMode(savedMode);
    }
    
    /**
     * 判断当前是否为深色模式
     */
    public boolean isDarkMode() {
        int mode = getThemeMode();
        if (mode == MODE_DARK) {
            return true;
        } else if (mode == MODE_LIGHT) {
            return false;
        } else {
            // 跟随系统时，检查系统当前模式
            int nightMode = context.getResources().getConfiguration().uiMode 
                    & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
            return nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES;
        }
    }
    
    /**
     * 获取主题模式的描述文本
     */
    public String getThemeModeDescription(int mode) {
        switch (mode) {
            case MODE_LIGHT:
                return "浅色";
            case MODE_DARK:
                return "深色";
            case MODE_SYSTEM:
            default:
                return "跟随系统";
        }
    }
}
