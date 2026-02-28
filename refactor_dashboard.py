import re

with open("lib/screens/dashboard_screen.dart", "r") as f:
    content = f.read()

# backgroundColor: const Color(0xFF0D0D0D) -> backgroundColor: AppColors.background
content = content.replace("backgroundColor: const Color(0xFF0D0D0D)", "backgroundColor: AppColors.background")
content = content.replace("color: Colors.black.withValues(alpha: 0.5)", "color: AppColors.background.withValues(alpha: 0.5)")
content = content.replace("BorderSide(color: Colors.white.withValues(alpha: 0.1))", "BorderSide(color: AppColors.divider)")
content = content.replace("selectedItemColor: Colors.white", "selectedItemColor: AppColors.textPrimary")
content = content.replace("unselectedItemColor: Colors.white38", "unselectedItemColor: AppColors.textSecondary")

# TextStyles
content = re.sub(
    r'const TextStyle\(\s*color:\s*Colors.white,\s*fontSize:\s*32,\s*fontWeight:\s*FontWeight.bold,\s*letterSpacing:\s*-1,\s*\)',
    r'Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: -1)',
    content
)

content = re.sub(
    r'const TextStyle\(\s*color:\s*Colors\.white70,\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight.w600,\s*letterSpacing:\s*1\.2,\s*\)',
    r'Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 1.2)',
    content
)

content = content.replace("color: Colors.white38", "color: AppColors.textSecondary")
content = content.replace("color: Colors.white70", "color: AppColors.textSecondary")
content = content.replace("color: Colors.white", "color: AppColors.textPrimary")
content = content.replace("color: Colors.white12", "color: AppColors.divider")
content = content.replace("color: const Color(0xFF1E1E1E)", "color: AppColors.surface")
content = content.replace("color: Colors.redAccent", "color: AppColors.error")
content = content.replace("Colors.grey[800]!", "AppColors.surfaceHigh")
content = content.replace("Colors.green", "AppColors.accent") # Assuming accent is used instead of green for active
# We should probably keep Colors.green and Colors.redAccent for specific statuses, or use AppColors.error / accent
content = content.replace("color: Colors.blueAccent.withValues(alpha: 0.1)", "color: AppColors.accentFaint")
content = content.replace("color: Colors.blueAccent", "color: AppColors.accent")

# TextStyles replacements
content = re.sub(r'const TextStyle\(\s*color:\s*AppColors.textSecondary\)', r'TextStyle(color: AppColors.textSecondary)', content)
content = re.sub(r'const TextStyle\(\s*color:\s*AppColors.textPrimary\)', r'TextStyle(color: AppColors.textPrimary)', content)
content = re.sub(r'const TextStyle\(\s*color:\s*AppColors.error\)', r'TextStyle(color: AppColors.error)', content)

# Remove const from Theme.of(context) if it was inside a const widget tree
content = content.replace("const Text(\n              \"Command Center\",", "Text(\n              \"Command Center\",")
content = content.replace("const Text(\n              \"Connected Apps\",", "Text(\n              \"Connected Apps\",")
content = content.replace("const Text(\n                  \"Recent Uploads\",", "Text(\n                  \"Recent Uploads\",")


with open("lib/screens/dashboard_screen.dart", "w") as f:
    f.write(content)
