# Update WELCOME_TYPST templates with proper Typst syntax

$file = "src\lib\components\MainEditor.svelte"
$content = Get-Content $file -Raw

# Create proper Chinese Typst template
$zhTemplate = @'
#import "styles/modern-tech.typ": article

#show: article.with(
  title: "MDXport 功能演示",
  authors: ("MDXport Team",),
  lang: "zh",
  date: "
'@ + '${new Date().toISOString().split(''T'')[0]}' + @'
",
)

= 将原始 Typst 代码转化为专业级 PDF

== 您 LLM 输出与专业报告之间更近的一步

MDXport 旨在提供稳定的分页、尝试自动修复常见的格式错误并为品牌规范提供支持——100% 在您的浏览器本地运行。

- *工程级分页*：表格表头尝试自动重复、处理标题孤行、智能换页建议。
- *主动预检*：检测并提示损坏的数学块、溢出的代码块和常见的嵌套问题。
- *确定性构建*：相同的输入 + 锁定的模板/引擎版本 = 每次都是完全相同的 PDF。
- *本地优先安全*：您的商业机密永远不会离开您的设备。

#link("https://mdxport.com")[立即尝试 →] #h(1em) #link("https://github.com/cosformula/mdxport")[查看工作区 · GitHub]

_由 WASM 驱动。可验证、可重现。_

#line(length: 100%)

== 排版功能演示

=== 文本格式

这是一段普通段落，包含 *加粗*、_斜体_、`行内代码`、以及一个 #link("https://example.com")[内联链接]。

=== 嵌套列表

- 产品特性
  - 客户端运行
  - 隐私保护
- 技术架构
  + Typst 排版引擎
  + WebAssembly 编译
  + PDF.js 预览

=== 代码块
```typescript
const pdf = await compile(typst);
```

=== 数学公式

行内公式：$ E = m c^2 $

块级公式：
$ a^2 + b^2 = c^2 $

#block(
  fill: rgb("#f0f0f0"),
  inset: 1em,
  radius: 4pt,
  [*提示*：你可以拖放 `.typ` 文件到编辑器直接导入，或使用顶部的模板快速开始。]
)
'@

# Find and replace the Chinese template (it starts with "zh: `" and ends before ", en:")
$pattern = '(?s)(zh: `).*?(?=`,\s*en:)'
$content = $content -replace $pattern, "zh: ``$zhTemplate"

$content | Set-Content $file -NoNewline

Write-Host "Updated Chinese Typst template"
