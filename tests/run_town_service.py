"""Run server workflows against a small engine mock; no Studio playtest is implied.
Usage: python tests/run_town_service.py /path/to/luau
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
service = (root / 'src/server/Services/TownService.luau').read_text()
service = service.replace('local Progression = require(script.Parent.ProgressionService)', '')
service = service.replace('local BuildingStorage = require(script.Parent.BuildingStorage)', '')
service = service.replace('local Inventory = require(script.Parent.InventoryService)', '')
for variable, module in [('Config', 'TownConfig'), ('Rules', 'TownRules'), ('Interaction', 'Interaction')]:
    service = service.replace(f'local {variable} = require(ReplicatedStorage.Shared.{module})', '')
parts = [(root / 'tests/fixtures/town_mock.luau').read_text(), 'local Progression={CanBuild=function() return true end}']
for variable, module in [('Config', 'TownConfig'), ('Rules', 'TownRules')]:
    parts.append(f'local {variable} = (function()\n' + (root / f'src/shared/{module}.luau').read_text() + '\nend)()')
parts.append('local BuildingStorage = (function()\n' + (root / 'src/server/Services/BuildingStorage.luau').read_text() + '\nend)()')
parts.extend(['local Service = (function()\n' + service + '\nend)()', (root / 'tests/fixtures/town_scenarios.luau').read_text(), (root / 'tests/fixtures/building_storage_scenarios.luau').read_text()])
with tempfile.TemporaryDirectory(prefix='decline-town-tests-') as directory:
    test = Path(directory) / 'town_service.luau'
    test.write_text('\n'.join(parts))
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(test)], check=True)
