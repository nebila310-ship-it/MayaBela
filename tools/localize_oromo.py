"""Convert isAmharic ? am : en patterns to t(en, am) in app_strings.dart."""
import re
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "lib" / "l10n" / "app_strings.dart"
text = path.read_text(encoding="utf-8")

# Multiline: isAmharic\n      ? 'am'\n      : 'en'
text = re.sub(
    r"isAmharic\s*\?\s*'((?:\\'|[^'])*)'\s*:\s*'((?:\\'|[^'])*)'",
    lambda m: f"t('{m.group(2)}', '{m.group(1)}')",
    text,
)

# Replace bool getter
text = text.replace(
    "  bool get isAmharic => languageCode == 'am';\n",
    "  bool get isAmharic => languageCode == 'am';\n"
    "  bool get isOromo => languageCode == 'om';\n\n"
    "  String t(String en, String am, [String? om]) {\n"
    "    switch (languageCode) {\n"
    "      case 'am':\n"
    "        return am;\n"
    "      case 'om':\n"
    "        return om ?? OromoCatalog.lookup(en) ?? en;\n"
    "      default:\n"
    "        return en;\n"
    "    }\n"
    "  }\n",
)

text = text.replace(
    "import 'package:eduaba/services/school_registry_service.dart';",
    "import 'package:eduaba/l10n/oromo_catalog.dart';\n"
    "import 'package:eduaba/services/school_registry_service.dart';",
)

path.write_text(text, encoding="utf-8")
print("Updated", path)
