"""Normal shell generation verifies offline fonts without fontTools installed."""
import importlib.util
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare_web_shell', root / 'tools/prepare_web_shell.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
fresh = "<html><head><style>body{font-family: 'Noto Sans', 'Droid Sans', Arial, sans-serif}</style></head><body><div id='status-brand'>Protos Harvest <span>Restoring the clearing</span></div></body></html>"
once = module.install_font_styles(fresh)
assert module.install_font_styles(once) == once, 'Repeated postprocessing duplicates font blocks'
assert 'Restoring the clearing' in once and not any(text in once for text in module.CJK_COMPATIBILITY_COPY)
assert 'font-family:ManusCC0,ManusCC0CJKSC,sans-serif' in once
assert 'font-family: \'Noto Sans\'' not in once
assert len(re.findall('data:font/ttf;base64,', once)) == 3
assert len(re.findall('data:font/woff2;base64,', once)) == 1
assert all('font-weight:%d' % weight in once for weight in (400, 500, 700))
manifest = json.loads((root / 'tools/loader-fonts/manifest.json').read_text())
assert {ord(c) for c in ''.join(module.CJK_COMPATIBILITY_COPY)} <= set(manifest['codepoints']) | set(manifest['primaryCodepoints'])
module.CJK_COMPATIBILITY_COPY = [*module.CJK_COMPATIBILITY_COPY, 'new corpus']
try:
    module.font_styles()
except AssertionError:
    pass
else:
    raise AssertionError('Changed compatibility corpus was accepted without regeneration')
print('PASS: offline font integrity, three primary weights, coverage metadata, unchanged English copy and repeatable shell font installation')
