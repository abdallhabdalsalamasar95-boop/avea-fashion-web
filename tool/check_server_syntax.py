import ast
import sys

path = r"D:\flutter_projects\CarmenKarla\local_server_py\server.py"
src = open(path, encoding="utf-8").read()
try:
    ast.parse(src)
    print("SYNTAX OK")
except SyntaxError as ex:
    print("SYNTAX ERROR", ex.lineno, ex.msg)
    sys.exit(1)
