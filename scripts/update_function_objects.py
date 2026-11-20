"""把各功能的根元对象名称写入 web/src/function-data/<plant>.js 的 o 字段。"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from server import app


def main() -> None:
    rows = app.read_function_index()
    for plant, functions in rows.items():
        names = app.function_object_names(plant)["objects"]
        filled = 0
        for row in functions:
            name = names.get(str(row.get("c") or ""), "")
            row["o"] = name
            filled += bool(name)
        app.write_function_rows(plant, functions)
        print(f"{plant}: {filled}/{len(functions)} 个功能已写入元对象名称")


if __name__ == "__main__":
    main()
