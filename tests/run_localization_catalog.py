"""Initialize the complete production catalog used by all startup menus."""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
catalog=(root/'src/shared/LocalizationCatalog.luau').read_text()
names=re.findall(r'Locales\.(\w+)',catalog)
assert names and 'Admin' in names and 'Interface' in names
source='local Rules=(function()\n'+(root/'src/shared/LocalizationRules.luau').read_text()+'\nend)()\nlocal groups={}\n'
for name in names:
 source+='table.insert(groups,(function()\n'+(root/f'src/shared/Locales/{name}.luau').read_text()+'\nend)())\n'
source+='''
local catalog=Rules.New(groups)
assert(catalog.Translate("Crafting","uk")=="Виготовлення","existing shared translation remains canonical")
assert(catalog.Translate("Diagnostics","uk")=="Діагностика")
assert(catalog.Translate("Instant crafting","uk")=="Моментальний крафт")
assert(catalog.Translate("Diagnostics","en")=="Diagnostics")
print("PASS: every production locale loads together without conflicts; existing crafting and new admin menus translate")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'locales.luau';p.write_text(source);subprocess.run([sys.argv[1],str(p)],check=True)
