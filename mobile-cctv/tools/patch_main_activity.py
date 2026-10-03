import glob
import re

files = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
if files:
    path = files[0]
    pkg = re.search(r"^package\s+(\S+)", open(path).read(), re.M).group(1)
    code = (
        "package " + pkg + "\n\n"
        "import android.os.Bundle\n"
        "import android.view.WindowManager\n"
        "import io.flutter.embedding.android.FlutterActivity\n\n"
        "class MainActivity : FlutterActivity() {\n"
        "    override fun onCreate(savedInstanceState: Bundle?) {\n"
        "        super.onCreate(savedInstanceState)\n"
        "        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n"
        "    }\n"
        "}\n"
    )
    open(path, "w").write(code)
    print("patched", path)
else:
    print("MainActivity.kt not found, skipping keep-screen-on patch")
