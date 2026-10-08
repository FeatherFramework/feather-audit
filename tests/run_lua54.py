"""Optional offline runner using Lupa's explicit Lua 5.4 backend."""
from pathlib import Path
import os
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-runtime'))
from lupa.lua54 import LuaRuntime

os.chdir(root)
runtime = LuaRuntime()
print(runtime.eval('_VERSION'), flush=True)
runtime.execute("dofile('tests/run.lua')")
