<#
.SYNOPSIS
  交互式给个人主页添加功能按钮
.DESCRIPTION
  一步步引导用户输入功能名称、图标、参数和逻辑，
  自动生成代码插入到 index.html 并推送到 GitHub Pages。
#>

$ErrorActionPreference = "Stop"
$script:git = "C:\Users\weid\PortableGit\bin\git.exe"
$script:htmlFile = "C:\Users\weid\my-page\index.html"
$script:repoDir = "C:\Users\weid\my-page"

# ========================================
# 工具函数
# ========================================

function Write-Step($num, $title) {
  Write-Host ""
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
  Write-Host " 步骤 $num : $title" -ForegroundColor Cyan
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
}

function Write-Ask($text) {
  Write-Host "  $text" -ForegroundColor Yellow -NoNewline
  Write-Host " > " -NoNewline
}

function Ask-String($prompt, $default) {
  $d = if ($default) { " [$default]" } else { "" }
  Write-Host "  $prompt" -ForegroundColor Yellow -NoNewline
  Write-Host "${d}:" -ForegroundColor DarkGray
  Write-Host "  > " -ForegroundColor White -NoNewline
  $val = Read-Host
  if (-not $val -and $default) { $val = $default }
  return $val.Trim()
}

function Ask-YesNo($prompt, $defaultYes = $true) {
  $yn = if ($defaultYes) { "[Y/n]" } else { "[y/N]" }
  Write-Host "  $prompt $yn" -ForegroundColor Yellow
  Write-Host "  > " -ForegroundColor White -NoNewline
  $val = Read-Host
  $val = $val.Trim().ToLower()
  if (-not $val) { return $defaultYes }
  return $val -eq 'y' -or $val -eq 'yes'
}

function Ask-Int($prompt, $default) {
  $d = if ($default -ne $null) { " [$default]" } else { "" }
  while ($true) {
    Write-Host "  $prompt" -ForegroundColor Yellow -NoNewline
    Write-Host "${d}:" -ForegroundColor DarkGray
    Write-Host "  > " -ForegroundColor White -NoNewline
    $val = Read-Host
    if (-not $val -and $default -ne $null) { return $default }
    $num = 0
    if ([int]::TryParse($val, [ref]$num)) { return $num }
    Write-Host "  ⚠ 请输入数字" -ForegroundColor Red
  }
}

function Slug($name) {
  $s = $name -replace '[^\w一-鿿]+', '_' -replace '_+', '_' -replace '^_|_$', ''
  if ($s -match '^\d') { $s = "f_" + $s }
  if ($s.Length -gt 30) { $s = $s.Substring(0, 30) }
  return $s.ToLower()
}

function JsEscape($str) {
  return $str -replace '\\', '\\' -replace "'", "\'" -replace "`n", '\n' -replace "`r", ''
}

# ========================================
# 模板: Handler 代码生成
# ========================================

function Get-TemplateHandler {
  param($template, $inputs, $extra)

  switch ($template) {
    # ---- 1. 数学表达式 ----
    1 {
      $handler = @'
function(values) {
  var result;
  try { result = new Function("return (" + values.expr + ")")(); }
  catch(e) { return { type: "text", value: "表达式错误: " + e.message }; }
  return { type: "text", value: String(result) };
}
'@
      $inputs = @(
        @{ id='expr'; label='表达式'; type='text'; placeholder='例如 2+3*4 或 Math.sqrt(25)' }
      )
      return @{ handler = $handler; inputs = $inputs }
    }

    # ---- 2. 公式计算 ----
    2 {
      $formula = $extra  # already asked
      # Replace $varName with values.varName
      $jsFormula = [regex]::Replace($formula, '\$(\w+)', 'values.$1')
      $handler = @"
function(values) {
  var result;
  try { result = (function(){ return ($jsFormula); })(); }
  catch(e) { return { type: "text", value: "公式错误: " + e.message }; }
  return { type: "text", value: String(result) };
}
"@
      return @{ handler = $handler; inputs = $null }
    }

    # ---- 3. 倒计时 ----
    3 {
      $target = $extra  # "2026-12-31T23:59:59"
      $handler = @"
function(values) {
  var target = new Date(values.year, values.month - 1, values.day, values.hour || 0, values.minute || 0, 0);
  var resultEl = document.getElementById('modal-result');
  var overlay = document.getElementById('modal-overlay');

  function update() {
    var now = new Date();
    var diff = target - now;
    if (diff <= 0) {
      resultEl.innerHTML = '<div class="result-label">时间到！</div><div class="result-value">已结束</div>';
      if (overlay._intervals) { clearInterval(overlay._intervals[0]); overlay._intervals = null; }
      return;
    }
    var days = Math.floor(diff / 86400000);
    var hours = Math.floor((diff % 86400000) / 3600000);
    var mins = Math.floor((diff % 3600000) / 60000);
    var secs = Math.floor((diff % 60000) / 1000);
    resultEl.innerHTML = '<div class="result-label">倒计时</div><div class="result-value">' +
      days + '天 ' + hours + '时 ' + mins + '分 ' + secs + '秒</div>';
  }

  update();
  var intervalId = setInterval(update, 1000);
  if (!overlay._intervals) { overlay._intervals = []; }
  overlay._intervals.push(intervalId);
  return { type: "html", value: "正在倒数..." };
}
"@
      $inputs = @(
        @{ id='year';  label='目标年'; type='number'; placeholder='2026' }
        @{ id='month'; label='目标月'; type='number'; placeholder='12' }
        @{ id='day';   label='目标日'; type='number'; placeholder='31' }
        @{ id='hour';  label='时(可选)'; type='number'; placeholder='23' }
        @{ id='minute'; label='分(可选)'; type='number'; placeholder='59' }
      )
      return @{ handler = $handler; inputs = $inputs }
    }

    # ---- 4. 随机数 ----
    4 {
      $handler = @'
function(values) {
  var min = values.min, max = values.max;
  if (min > max) { var t = min; min = max; max = t; }
  var result = Math.floor(Math.random() * (max - min + 1)) + min;
  return { type: "text", value: String(result) };
}
'@
      $inputs = @(
        @{ id='min'; label='最小值'; type='number'; placeholder='1' }
        @{ id='max'; label='最大值'; type='number'; placeholder='100' }
      )
      return @{ handler = $handler; inputs = $inputs }
    }

    # ---- 5. 文本处理 ----
    5 {
      $ops = "'大写','小写','反转','单词数','字符数'"
      $handler = @"
function(values) {
  var text = values.text || '';
  var op = values.operation || '大写';
  var result;
  switch (op) {
    case '大写': result = text.toUpperCase(); break;
    case '小写': result = text.toLowerCase(); break;
    case '反转': result = text.split('').reverse().join(''); break;
    case '单词数': result = text.trim() ? text.trim().split(/\s+/).length : 0; break;
    case '字符数': result = text.length; break;
    default: result = text;
  }
  return { type: "text", value: String(result) };
}
"@
      $inputs = @(
        @{ id='text'; label='文本内容'; type='textarea'; placeholder='输入要处理的文字...' }
        @{ id='operation'; label='操作'; type='select'; options=@('大写','小写','反转','单词数','字符数') }
      )
      return @{ handler = $handler; inputs = $inputs }
    }

    # ---- 6. 仅显示 ----
    6 {
      $handler = @'
function(values) {
  var html = '';
  for (var k in values) {
    if (values.hasOwnProperty(k)) {
      html += '<div style="margin-bottom:8px;"><span style="color:var(--muted);font-size:12px;">' + k + '</span><br><span>' + String(values[k]) + '</span></div>';
    }
  }
  return { type: "html", value: html || '(空)' };
}
'@
      return @{ handler = $handler; inputs = $null }
    }

    # ---- 7. 自定义 JS ----
    7 {
      $handler = "function(values) {`n$extra`n}"
      return @{ handler = $handler; inputs = $null }
    }

    default {
      throw "未知模板: $template"
    }
  }
}

# ========================================
# 主流程
# ========================================

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║    🧩 添加功能到我的主页   ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# --- 检查文件 ---
if (-not (Test-Path $htmlFile)) {
  Write-Host "  ✗ 找不到 $htmlFile" -ForegroundColor Red
  exit 1
}
$html = [System.IO.File]::ReadAllText($htmlFile, [System.Text.UTF8Encoding]::new($false))

# 检查基础设施
if ($html -notmatch '<<<FEATURES>>>') {
  Write-Host "  ✗ index.html 缺少功能系统框架，请先运行初始化" -ForegroundColor Red
  exit 1
}

Write-Host "  ✅ 已加载 index.html (功能系统已就绪)" -ForegroundColor Green

# ========================================
# 步骤 1: 功能元数据
# ========================================
Write-Step 1 "功能基本信息"

$featureName = Ask-String "功能名称（按钮上显示的文字）"
if (-not $featureName) {
  Write-Host "  ✗ 功能名称不能为空" -ForegroundColor Red
  exit 1
}

$featureIcon = Ask-String "图标 Emoji" "🔧"
$featureDesc = Ask-String "简短描述（可选）" ""

$featureId = Slug $featureName

# 检查 ID 冲突
if ($html -match "id:\s*'$featureId'") {
  Write-Host "  ⚠ 功能 '$featureId' 已存在！" -ForegroundColor Red
  $confirm = Ask-YesNo "是否覆盖？" $false
  if (-not $confirm) {
    $featureId = Ask-String "换一个 ID"
  }
}

Write-Host ""
Write-Host "  名称: $featureName" -ForegroundColor White
Write-Host "  图标: $featureIcon" -ForegroundColor White
Write-Host "  ID:   $featureId" -ForegroundColor DarkGray

# ========================================
# 步骤 2: 输入参数
# ========================================
Write-Step 2 "定义输入参数"

$userInputs = @()
$adding = $true
while ($adding) {
  Write-Host ""
  if ($userInputs.Count -gt 0) {
    Write-Host "  已添加的参数: $($userInputs.Count) 个" -ForegroundColor DarkGray
  }
  $adding = Ask-YesNo "添加一个输入参数？" $true
  if (-not $adding) { break }

  $paramName = Ask-String "  参数变量名（英文）" -replace '\s+', '_'
  if (-not $paramName) {
    Write-Host "  ⚠ 参数名不能为空，跳过" -ForegroundColor Red
    continue
  }
  if ($userInputs | Where-Object { $_.id -eq $paramName }) {
    Write-Host "  ⚠ 参数 '$paramName' 已存在" -ForegroundColor Red
    continue
  }

  $paramLabel = Ask-String "  参数显示标签（中文）" $paramName

  Write-Host "  参数类型: [1] text  [2] number  [3] textarea  [4] select" -ForegroundColor DarkGray
  $typeChoice = Ask-String "  选择 (1-4)" "1"
  switch ($typeChoice) {
    '1' { $paramType = 'text' }
    '2' { $paramType = 'number' }
    '3' { $paramType = 'textarea' }
    '4' { $paramType = 'select' }
    default { $paramType = 'text' }
  }

  $paramPlaceholder = Ask-String "  占位文字" "请输入$paramLabel"

  $paramOptions = @()
  if ($paramType -eq 'select') {
    Write-Host "  请输入下拉选项（一行一个，空行结束）:" -ForegroundColor DarkGray
    while ($true) {
      Write-Host "  选项 > " -ForegroundColor White -NoNewline
      $opt = Read-Host
      if (-not $opt.Trim()) { break }
      $paramOptions += $opt.Trim()
    }
  }

  $userInputs += @{
    id = $paramName
    label = $paramLabel
    type = $paramType
    placeholder = $paramPlaceholder
    options = $paramOptions
  }
}

# ========================================
# 步骤 3: 选择模板
# ========================================
Write-Step 3 "选择功能逻辑"

Write-Host ""
Write-Host "  [1] 🧮 数学表达式    — 输入算式，计算求值" -ForegroundColor White
Write-Host "  [2] 📐 公式计算      — 用输入变量套公式（如 BMI = 体重/身高²）" -ForegroundColor White
Write-Host "  [3] ⏱️ 倒计时        — 设定目标日期，实时倒数" -ForegroundColor White
Write-Host "  [4] 🎲 随机数        — 范围内随机生成" -ForegroundColor White
Write-Host "  [5] 📝 文本处理      — 大写/小写/反转/计数" -ForegroundColor White
Write-Host "  [6] 👁️ 仅显示        — 展示输入内容" -ForegroundColor White
Write-Host "  [7] ✏️ 自定义 JS     — 手写逻辑" -ForegroundColor White
Write-Host ""

$template = Ask-Int "选择模板 (1-7)" 1
if ($template -lt 1 -or $template -gt 7) {
  Write-Host "  ✗ 无效选择" -ForegroundColor Red
  exit 1
}

$extra = $null

switch ($template) {
  1 {
    Write-Host "  ✅ 数学表达式：已自动添加 '表达式' 输入框" -ForegroundColor Green
    Write-Host "  用户输入如 2+3*4 或 Math.sqrt(25) 即得结果" -ForegroundColor DarkGray
  }
  2 {
    Write-Host "  公式中使用 " -ForegroundColor Yellow -NoNewline
    Write-Host '$变量名' -ForegroundColor Cyan -NoNewline
    Write-Host " 引用参数" -ForegroundColor Yellow
    Write-Host "  示例: " -ForegroundColor DarkGray -NoNewline
    Write-Host '$weight / (($height/100) ** 2)' -ForegroundColor White
    $extra = Ask-String "请输入公式"
    if (-not $extra) {
      Write-Host "  ✗ 公式不能为空" -ForegroundColor Red
      exit 1
    }
  }
  3 {
    Write-Host "  ✅ 倒计时：已自动添加年/月/日/时/分输入框" -ForegroundColor Green
    Write-Host "  注意：倒计时会在弹窗中实时更新，关闭弹窗自动停止" -ForegroundColor DarkGray
  }
  4 {
    Write-Host "  ✅ 随机数：已自动添加最小/最大值输入框" -ForegroundColor Green
  }
  5 {
    Write-Host "  ✅ 文本处理：已自动添加文本输入框和操作选择" -ForegroundColor Green
  }
  6 {
    Write-Host "  ✅ 仅显示：将用户输入格式化展示" -ForegroundColor Green
  }
  7 {
    Write-Host "  请输入 JavaScript 函数体 (可使用 values.参数名 获取输入值)" -ForegroundColor Yellow
    Write-Host "  必须返回: { type: 'text'|'html', value: '结果字符串' }" -ForegroundColor DarkGray
    Write-Host "  输入你的代码（输入 END 结束）:" -ForegroundColor Yellow
    $lines = @()
    while ($true) {
      Write-Host "  JS > " -ForegroundColor White -NoNewline
      $line = Read-Host
      if ($line.Trim() -eq 'END') { break }
      $lines += $line
    }
    $extra = $lines -join "`n"
    if (-not $extra.Trim()) {
      Write-Host "  ✗ 代码不能为空" -ForegroundColor Red
      exit 1
    }
  }
}

# ========================================
# 步骤 4: 生成 handler
# ========================================
$result = Get-TemplateHandler -template $template -inputs $userInputs -extra $extra

# 模板可能覆盖 inputs
if ($result.inputs) { $userInputs = $result.inputs }
$handlerCode = $result.handler

# ========================================
# 步骤 5: 结果标签 & 插入文件
# ========================================
Write-Step 5 "生成代码并保存"

$resultLabel = Ask-String "结果标签（显示在结果上方）" "结果"

# --- 构建 inputs JS ---
$inputLines = @()
foreach ($inp in $userInputs) {
  $optStr = ""
  if ($inp.options -and $inp.options.Count -gt 0) {
    $optArr = ($inp.options | ForEach-Object { "'" + (JsEscape $_) + "'" }) -join ", "
    $optStr = ", options: [$optArr]"
  }
  $inputLines += "      { id: '" + (JsEscape $inp.id) + "', label: '" + (JsEscape $inp.label) +
    "', type: '" + $inp.type + "', placeholder: '" + (JsEscape $inp.placeholder) + "'$optStr }"
}
$inputsJs = $inputLines -join ",`n"

# --- 构建完整 feature ---
$handlerCompact = ($handlerCode -replace '\s+', ' ').Trim()

$featureCode = @"
  // $featureName
  {
    id: '$featureId',
    name: '$([regex]::Replace($featureName, "'", "\'"))',
    icon: '$([regex]::Replace($featureIcon, "'", "\'"))',
    description: '$([regex]::Replace($featureDesc, "'", "\'"))',
    inputs: [
$inputsJs
    ],
    handler: $handlerCompact,
    resultLabel: '$([regex]::Replace($resultLabel, "'", "\'"))'
  },
  // <<<FEATURES>>>
"@

# 替换标记
$html = $html -replace '// <<<FEATURES>>>', $featureCode

# 写入文件 (UTF-8 无 BOM)
[System.IO.File]::WriteAllText($htmlFile, $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "  ✅ 已写入 index.html" -ForegroundColor Green

# ========================================
# 步骤 6: Git 提交 & 推送
# ========================================
Write-Step 6 "推送到 GitHub Pages"

Set-Location $repoDir
$commitMsg = "add feature: $featureName"

try {
  & $git add index.html 2>&1 | Out-Null
  & $git commit -m $commitMsg 2>&1 | Out-Null
  Write-Host "  📦 已提交: $commitMsg" -ForegroundColor Green

  Write-Host "  🚀 推送中..." -ForegroundColor Yellow
  $pushResult = & $git push origin main 2>&1
  Write-Host "  ✅ 推送成功" -ForegroundColor Green
}
catch {
  Write-Host "  ✗ Git 操作失败: $_" -ForegroundColor Red
  Write-Host "  请手动运行: cd $repoDir; git push" -ForegroundColor Yellow
}

# ========================================
# 完成
# ========================================
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║  🎉 功能添加完成！                      ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  🔗 访问: " -ForegroundColor White -NoNewline
Write-Host "https://cpper2003.github.io/homepage/" -ForegroundColor Cyan
Write-Host "  🧩 功能: " -ForegroundColor White -NoNewline
Write-Host "$featureIcon $featureName" -ForegroundColor Yellow
Write-Host "  📱 手机打开试试吧！" -ForegroundColor DarkGray
Write-Host ""
