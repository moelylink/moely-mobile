package link.moely.mobile;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.View;
import android.widget.ArrayAdapter;
// import android.widget.ListView; // 移除
import android.widget.LinearLayout; // 新增
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.Switch;
import android.widget.TextView;

import com.google.android.material.appbar.MaterialToolbar;

public class TranslationSettingsActivity extends BaseActivity {
    
    private MaterialToolbar toolbar;
    private Switch switchEnabled;
    private Switch switchAutoTranslate;
    private RadioGroup targetLanguageGroup;
    private LinearLayout layoutEngineSelector; 
    private TextView tvCurrentEngine; 
    private TextView tvEngineTitle;
    private LinearLayout layoutEnableTranslation;
    private LinearLayout layoutAutoTranslate;
    
    private TranslationEngine.TranslationManager translationManager;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_translation_settings);
        
        toolbar = findViewById(R.id.toolbar_translation);
        ThemeUtils.applyThemeToToolbar(toolbar);
        
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setDisplayShowHomeEnabled(true);
        }
        toolbar.setNavigationOnClickListener(v -> onBackPressed());
        
        translationManager = TranslationEngine.TranslationManager.getInstance(this);
        
        // 初始化视图
        switchEnabled = findViewById(R.id.switch_translation_enabled);
        switchAutoTranslate = findViewById(R.id.switch_auto_translate);
        targetLanguageGroup = findViewById(R.id.target_language_group);
        
        layoutEngineSelector = findViewById(R.id.layout_engine_selector); 
        tvCurrentEngine = findViewById(R.id.tv_current_engine); 
        
        tvEngineTitle = findViewById(R.id.tv_engine_title);
        
        // 【新增】初始化 LinearLayout 引用
        layoutEnableTranslation = findViewById(R.id.layout_enable_translation);
        layoutAutoTranslate = findViewById(R.id.layout_auto_translate);
        
        // 设置启用开关的初始状态
        switchEnabled.setChecked(translationManager.isEnabled());
        switchAutoTranslate.setChecked(translationManager.isAutoTranslateEnabled());

        // 设置点击监听器
        setupToggleListeners();
        
        // 设置目标语言选择
        setupTargetLanguage();
        
        // 设置引擎列表（改为下拉选择模拟）
        setupEngineSelector(); 
        
        // 初始化UI状态
        updateUIState(translationManager.isEnabled());
    }

    /**
     * 设置开关条目的点击监听器，实现点击整个条目切换 Switch 状态
     */
    private void setupToggleListeners() {
        
        // 1. 启用翻译功能
        layoutEnableTranslation.setOnClickListener(v -> {
            // 切换 Switch 状态
            switchEnabled.toggle(); 
            // 手动调用 OnCheckedChangeListener 的逻辑
            boolean isChecked = switchEnabled.isChecked();
            translationManager.setEnabled(isChecked);
            updateUIState(isChecked);
        });

        // 2. 自动翻译页面
        layoutAutoTranslate.setOnClickListener(v -> {
            // 只有在启用翻译功能时才允许切换自动翻译
            if (translationManager.isEnabled()) {
                // 切换 Switch 状态
                switchAutoTranslate.toggle(); 
                // 手动调用 OnCheckedChangeListener 的逻辑
                boolean isChecked = switchAutoTranslate.isChecked();
                translationManager.setAutoTranslateEnabled(isChecked);
            }
        });
    }
    
    /**
     * 设置目标语言选择
     */
    private void setupTargetLanguage() {
        String currentLang = translationManager.getTargetLanguage();
        
        // 根据当前语言设置选中状态
        switch (currentLang) {
            case "zh-CN":
                ((RadioButton) findViewById(R.id.radio_zh_cn)).setChecked(true);
                break;
            case "zh-TW":
                ((RadioButton) findViewById(R.id.radio_zh_tw)).setChecked(true);
                break;
            case "en":
                ((RadioButton) findViewById(R.id.radio_en)).setChecked(true);
                break;
            case "ja":
                ((RadioButton) findViewById(R.id.radio_ja)).setChecked(true);
                break;
            case "ko":
                ((RadioButton) findViewById(R.id.radio_ko)).setChecked(true);
                break;
        }
        
        // 设置监听器
        targetLanguageGroup.setOnCheckedChangeListener((group, checkedId) -> {
            String language = "zh-CN";
            if (checkedId == R.id.radio_zh_cn) {
                language = "zh-CN";
            } else if (checkedId == R.id.radio_zh_tw) {
                language = "zh-TW";
            } else if (checkedId == R.id.radio_en) {
                language = "en";
            } else if (checkedId == R.id.radio_ja) {
                language = "ja";
            } else if (checkedId == R.id.radio_ko) {
                language = "ko";
            }
            translationManager.setTargetLanguage(language);
        });
    }
    
    /**
     * 设置翻译引擎选择器（使用点击弹出对话框模拟下拉）
     * 修复：将选中项索引的计算逻辑移入点击监听器中。
     */
    private void setupEngineSelector() {
        final String[] engines = translationManager.getAvailableEngines();
        
        // 设置初始显示的文本（从Manager获取当前值）
        tvCurrentEngine.setText(translationManager.getCurrentEngine());
        
        // 设置点击监听器，弹出单选对话框
        layoutEngineSelector.setOnClickListener(v -> {
            // 【修正：每次点击时重新计算当前选中的引擎索引】
            String currentEngine = translationManager.getCurrentEngine();
            int checkedItem = -1;
            for (int i = 0; i < engines.length; i++) {
                if (engines[i].equals(currentEngine)) {
                    checkedItem = i;
                    break;
                }
            }
            
            // 使用最新的 checkedItem 来设置对话框的选中项
            new AlertDialog.Builder(this)
                .setTitle("选择翻译引擎")
                .setSingleChoiceItems(engines, checkedItem, (dialog, which) -> {
                    // 选择了新的引擎
                    String selectedEngine = engines[which];
                    translationManager.setCurrentEngine(selectedEngine);
                    tvCurrentEngine.setText(selectedEngine); // 更新显示文本
                    dialog.dismiss(); // 关闭对话框
                })
                .setNegativeButton("取消", null)
                .show();
        });
    }
    
    /**
     * 更新UI状态
     */
    private void updateUIState(boolean enabled) {
        switchAutoTranslate.setEnabled(enabled);
        targetLanguageGroup.setEnabled(enabled);
        
        layoutEngineSelector.setEnabled(enabled); 
        
        tvEngineTitle.setEnabled(enabled);
        
        // 禁用状态时将所有子RadioButton也禁用
        for (int i = 0; i < targetLanguageGroup.getChildCount(); i++) {
            targetLanguageGroup.getChildAt(i).setEnabled(enabled);
        }
        
        // 更新当前选择文本的颜色来表示启用/禁用状态（可选）
        tvCurrentEngine.setEnabled(enabled);
    }
}
