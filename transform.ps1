# Transform MainEditor.svelte from Markdown to Typst editor

$file = "src\lib\components\MainEditor.svelte"
$content = Get-Content $file -Raw

# Replace WELCOME_MARKDOWN with WELCOME_TYPST
$content = $content -replace 'WELCOME_MARKDOWN','WELCOME_TYPST'

# Replace markdown variables with typst (but not function names)
$content = $content -replace '\bmarkdown\b(?!ToTypst|ToHtml)','typst'

# Replace file extensions
$content = $content -replace '\.md\b','.typ'

# Replace initialMarkdown with initialTypst
$content = $content -replace '\binitialMarkdown\b','initialTypst'

# Update placeholders
$content = $content -replace '在这里输入 Markdown\.\.\.','在这里输入 Typst 代码...'
$content = $content -replace 'Type Markdown here\.\.\.','Type Typst code here...'

# Save the file
$content | Set-Content $file -NoNewline

Write-Host "Transformation complete!"
