package link.moely.mobile;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;

public class ThemeManager {
    private static final String PREFS_NAME = "MoelyThemePrefs";
    private static final String KEY_PRIMARY_COLOR = "primary_color";
    private static final String KEY_COLOR_NAME = "color_name";
    
    // 默认主题色
    private static final int DEFAULT_PRIMARY_COLOR = Color.parseColor("#6200EE");
    private static final String DEFAULT_COLOR_NAME = "深紫";
    
    private static ThemeManager instance;
    private SharedPreferences prefs;
    private Context context;
    
    private ThemeManager(Context context) {
        this.context = context.getApplicationContext();
        this.prefs = this.context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }
    
    public static synchronized ThemeManager getInstance(Context context) {
        if (instance == null) {
            instance = new ThemeManager(context);
        }
        return instance;
    }
    
    /**
     * 设置主题色
     */
    public void setPrimaryColor(int color, String colorName) {
        prefs.edit()
            .putInt(KEY_PRIMARY_COLOR, color)
            .putString(KEY_COLOR_NAME, colorName)
            .apply();
    }
    
    /**
     * 获取当前主题色
     */
    public int getPrimaryColor() {
        return prefs.getInt(KEY_PRIMARY_COLOR, DEFAULT_PRIMARY_COLOR);
    }
    
    /**
     * 获取当前主题色名称
     */
    public String getColorName() {
        return prefs.getString(KEY_COLOR_NAME, DEFAULT_COLOR_NAME);
    }
    
    /**
     * 生成主题色的变体（用于不同的UI元素）
     */
    public int getPrimaryDarkColor() {
        int primaryColor = getPrimaryColor();
        return darkenColor(primaryColor, 0.8f);
    }
    
    public int getPrimaryLightColor() {
        int primaryColor = getPrimaryColor();
        return lightenColor(primaryColor, 0.3f);
    }
    
    public int getAccentColor() {
        int primaryColor = getPrimaryColor();
        // 生成一个互补色作为强调色
        return adjustHue(primaryColor, 180);
    }
    
    /**
     * 加深颜色
     */
    private int darkenColor(int color, float factor) {
        int red = (int) (Color.red(color) * factor);
        int green = (int) (Color.green(color) * factor);
        int blue = (int) (Color.blue(color) * factor);
        return Color.rgb(red, green, blue);
    }
    
    /**
     * 变浅颜色
     */
    private int lightenColor(int color, float factor) {
        int red = (int) (Color.red(color) + (255 - Color.red(color)) * factor);
        int green = (int) (Color.green(color) + (255 - Color.green(color)) * factor);
        int blue = (int) (Color.blue(color) + (255 - Color.blue(color)) * factor);
        return Color.rgb(red, green, blue);
    }
    
    /**
     * 调整色相
     */
    private int adjustHue(int color, float hueShift) {
        float[] hsv = new float[3];
        Color.colorToHSV(color, hsv);
        hsv[0] = (hsv[0] + hueShift) % 360;
        return Color.HSVToColor(hsv);
    }
    
    /**
     * 重置为默认主题
     */
    public void resetToDefault() {
        setPrimaryColor(DEFAULT_PRIMARY_COLOR, DEFAULT_COLOR_NAME);
    }
    
    /**
     * 获取文本颜色（基于主题色亮度自动选择黑色或白色）
     */
    public int getTextColorOnPrimary() {
        int primaryColor = getPrimaryColor();
        return isLightColor(primaryColor) ? Color.BLACK : Color.WHITE;
    }
    
    /**
     * 判断颜色是否为浅色
     */
    private boolean isLightColor(int color) {
        double darkness = 1 - (0.299 * Color.red(color) + 0.587 * Color.green(color) + 0.114 * Color.blue(color)) / 255;
        return darkness < 0.5;
    }
}
