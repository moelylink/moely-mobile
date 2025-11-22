package link.moely.mobile;

import android.app.AlertDialog;
import android.os.Bundle;
import android.widget.ArrayAdapter;
import android.widget.LinearLayout; 
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
    
    // 声明布局变量，对应 XML 中的 ID
    private LinearLayout layoutEnableTranslation;
    private LinearLayout layoutAutoTranslate;
    
    private TranslationEngine.TranslationManager translationManager;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_translation_settings);
        
        toolbar = findViewById(R.id.toolbar_translation);
        // 假设 ThemeUtils 存在
        ThemeUtils.applyThemeToToolbar(toolbar);
        
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setDisplayShowHomeEnabled(true);
        }
        toolbar.setNavigationOnClickListener(v -> onBackPressed());
        
        // 初始化 TranslationManager 实例
        translationManager = TranslationEngine.TranslationManager.getInstance(this);
        
        // 1. 初始化 Switch 和 RadioGroup
        switchEnabled = findViewById(R.id.switch_translation_enabled);
        switchAutoTranslate = findViewById(R.id.switch_auto_translate);
        targetLanguageGroup = findViewById(R.id.target_language_group);
        
        // 2. 初始化引擎选择器相关视图
        layoutEngineSelector = findViewById(R.id.layout_engine_selector); 
        tvCurrentEngine = findViewById(R.id.tv_current_engine); 
        tvEngineTitle = findViewById(R.id.tv_engine_title);
        
        // 3. 初始化开关条目布局
        layoutEnableTranslation = findViewById(R.id.layout_enable_translation);
        layoutAutoTranslate = findViewById(R.id.layout_auto_translate);
        
        // 设置启用开关的初始状态
        switchEnabled.setChecked(translationManager.isEnabled());
        switchAutoTranslate.setChecked(translationManager.isAutoTranslateEnabled());
        
        // 设置开关的点击和切换逻辑
        setupToggleListeners();
        
        // 设置目标语言选择
        setupTargetLanguage();
        
        // 设置引擎选择器
        setupEngineSelector(); 
        
        // 初始化UI状态
        updateUIState(translationManager.isEnabled());
    }

    /**
     * 设置开关条目的点击和监听器，实现点击整个条目切换 Switch 状态，
     * 并确保业务逻辑只在 Switch 状态实际改变时执行。
     */
    private void setupToggleListeners() {
        
        // ------------------ 1. Switch 状态改变时执行业务逻辑 (核心逻辑) ------------------
        
        // 启用翻译功能的主开关
        switchEnabled.setOnCheckedChangeListener((buttonView, isChecked) -> {
             translationManager.setEnabled(isChecked);
             updateUIState(isChecked); // 主开关改变时，更新所有相关UI状态
        });
        
        // 自动翻译开关
        switchAutoTranslate.setOnCheckedChangeListener((buttonView, isChecked) -> {
            // 只有在翻译启用或用户尝试关闭时，才允许执行设置
            if (translationManager.isEnabled() || !isChecked) { 
                translationManager.setAutoTranslateEnabled(isChecked);
            } else {
                // 如果翻译未启用但用户尝试开启自动翻译，则阻止并恢复状态
                switchAutoTranslate.setChecked(false);
            }
        });

        // ------------------ 2. 条目点击只负责切换 Switch 状态 (用户体验) ------------------

        // 点击 "启用翻译功能" 条目
        layoutEnableTranslation.setOnClickListener(v -> {
            switchEnabled.toggle(); 
            // 业务逻辑在 switchEnabled.setOnCheckedChangeListener 中自动处理
        });
        
        // 点击 "自动翻译页面" 条目
        layoutAutoTranslate.setOnClickListener(v -> {
            // 只有当整个条目处于启用状态时才允许点击切换
            if (layoutAutoTranslate.isEnabled()) { 
                switchAutoTranslate.toggle(); 
                // 业务逻辑在 switchAutoTranslate.setOnCheckedChangeListener 中自动处理
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
     */
    private void setupEngineSelector() {
        final String[] engines = translationManager.getAvailableEngines();
        
        // 设置初始显示的文本（从Manager获取当前值）
        tvCurrentEngine.setText(translationManager.getCurrentEngine());
        
        // 设置点击监听器，弹出单选对话框
        layoutEngineSelector.setOnClickListener(v -> {
            // 每次点击时重新计算当前选中的引擎索引 (修复 bug)
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
     * 更新UI状态：根据主开关启用/禁用相关组件
     */
    private void updateUIState(boolean enabled) {
        // 自动翻译的 Switch 和条目是否启用取决于主开关
        switchAutoTranslate.setEnabled(enabled);
        layoutAutoTranslate.setEnabled(enabled); 
        
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
