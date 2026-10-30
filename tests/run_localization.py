"""Exercise the shipped manual catalog and pure formatter, without cloud translation."""
from pathlib import Path
import re,subprocess,sys,tempfile,json
root=Path(__file__).resolve().parents[1]
parts=['local Rules=(function()\n'+(root/'src/shared/LocalizationRules.luau').read_text()+'\nend)()','local groups={}']
entries=[]
for p in sorted((root/'src/shared/Locales').glob('*.luau')):
 source=p.read_text();parts.append('table.insert(groups,(function()\n'+source+'\nend)())')
 for line in source.splitlines():
  if not line.startswith(' {'):continue
  fields=re.findall(r'"(?:\\.|[^"\\])*"',line)
  if len(fields)>=3:entries.append(tuple(json.loads(x) for x in fields[:3]))
# Every explicitly formatted translation retains each variable; literals/IDs
# cannot silently disappear when an English UI template gains a new argument.
for source,uk,ru in entries:
 fmt=re.sub('%%','',source)
 slots=re.findall(r'%[+\- #0]*\d*\.?\d*[sdifg]',fmt)
 if slots and (re.search(r'{\d+}',uk) or re.search(r'{\d+}',ru)):
  for text in [uk,ru]:
   indices={int(x) for x in re.findall(r'{(\d+)}',text)}
   assert indices==set(range(1,len(slots)+1)),(source,text,indices,len(slots))
parts.append('local dictionary=Rules.New(groups)')
for text in re.findall(r'Text=\[\[(.*?)\]\]',(root/'src/client/HowToPlay.client.luau').read_text(),re.S):
 parts.append('assert(dictionary.Exact['+json.dumps(text)+'],"Missing help-page translation")')
for module in ['ItemConfig','CraftConfig','ProgressionRules']:
 parts.append('local data=(function()\n'+(root/f'src/shared/{module}.luau').read_text()+'\nend)()')
 parts.append('''for id,item in pairs(data.Items or data.Recipes or data.Perks or data) do
 if type(item)=="table" then for _,key in ipairs({"Name","Description"}) do
  local text=item[key]
  if text then assert(dictionary.Exact[text],"Missing exact catalog entry: "..id.." / "..key.." / "..text) end
 end end
end''')
parts.append('''
assert(Rules.Normalize("uk-UA")=="uk" and Rules.Normalize("ru-ru")=="ru" and Rules.Normalize("fr-fr")=="en")
assert(dictionary.Translate("Take all","uk")=="Взяти все")
assert(dictionary.Translate("Requires Strength 4","uk")=="Потрібно: Сила 4")
assert(dictionary.Translate("Requires Strength 4","ru")=="Требуется: Сила 4")
assert(dictionary.Translate("Take all","ru")=="Взять всё")
assert(dictionary.Translate("HP 040","uk")=="ОЗ 040","numeric formatting survives capture")
assert(dictionary.Translate("Level 12 · XP 45 / 300","ru")=="Уровень 12 · Опыт 45 / 300")
assert(dictionary.Translate("Received 5 x Tree log.","uk")=="Отримано: Колода ×5.","argument order and item names")
local arbitrary="Doctor Repair 100% <b>Tree log</b>"
for _,locale in ipairs({"en","uk","ru"}) do
 local result=dictionary.Translate("Mayor: "..Rules.Protect(arbitrary),locale)
 assert(result:find(arbitrary,1,true),"opaque player/town names are byte-identical")
 assert(not result:find("[\\1-\\4]"),"internal markers never render")
end
assert(dictionary.Translate("You restored 12 HP to Doctor.","ru")=="Вы восстановили 12 ОЗ для Doctor.","unannotated player parameter also stays opaque")
assert(dictionary.Translate("Set price","en")=="Set price")
assert(dictionary.Translate("Unknown future message","uk")=="Unknown future message","English fallback")
assert(dictionary.Translate("A future Repair notification","uk")=="A future Repair notification","no half-translated unknown sentences")
assert(dictionary.Translate("You restored 12 HP to yourself.","uk")=="Ви відновили собі 12 ОЗ.")
assert(dictionary.Translate("Food 10\\nWater 20","uk")=="Ситість 10\\nВода 20")
assert(dictionary.Translate("Repairman","uk")=="Repairman","word boundary prevents partial IDs")
for i=1,900 do dictionary.Translate("Unknown "..i,"uk") end
assert(dictionary.CacheCount.uk<=512,"bounded cache")
print("PASS: complete item/recipe/perk catalog, locales, variables, numbers, protected names, English fallback and bounded cache")
''')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'locale.luau';p.write_text('\n'.join(parts));subprocess.run([sys.argv[1],str(p)],check=True)
print(f'PASS: {len(entries)} hand-authored source entries preserve all format arguments in both languages')
