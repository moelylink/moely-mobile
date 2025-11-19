package link.moely.mobile;

import android.os.Bundle;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

/**
 * BaseActivity - 所有 Activity 的基类
 * 
 * 功能：
 * 1. 统一处理主题初始化和应用
 * 2. 统一处理状态栏主题颜色
 * 3. 为子类提供通用的生命周期管理
 * 
 * 所有应用中的 Activity 都应继承此类以保持主题的一致性
 */
public class BaseActivity extends AppCompatActivity {

    /**
     * Activity 创建时调用
     * 在 setContentView 之前初始化主题设置
     */
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // 初始化主题管理器（单例模式）
        ThemeManager.getInstance(this);
        
        // 初始化并应用主题模式（深色/浅色/跟随系统）
        ThemeModeManager.getInstance(this).initializeTheme();
        
        // 应用主题色到状态栏
        ThemeUtils.applyThemeToStatusBar(this);
    }

    /**
     * Activity 恢复时调用
     * 确保主题在返回时保持最新状态
     */
    @Override
    protected void onResume() {
        super.onResume();
        
        // 重新应用状态栏主题（防止从其他应用返回后状态栏颜色不一致）
        ThemeUtils.applyThemeToStatusBar(this);
    }

    /**
     * 获取当前主题管理器实例
     * 供子类使用
     */
    protected ThemeManager getThemeManager() {
        return ThemeManager.getInstance(this);
    }

    /**
     * 获取当前主题模式管理器实例
     * 供子类使用
     */
    protected ThemeModeManager getThemeModeManager() {
        return ThemeModeManager.getInstance(this);
    }
}
