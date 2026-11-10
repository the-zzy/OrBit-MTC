"""把各工厂全部功能的元对象索引导出到 library/<plant>/<command>/object.json。

可以重复执行：已有 object.json 里的表结构、存储过程、拉取时间会按元对象ID保留，
只刷新元对象名称、父子关系、中文名和顺序。
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from server import app

DEFAULT_ENVS = ("zongzhuang-mes-prod", "jiban-mes-prod")


def export_env(env: str) -> tuple[int, int]:
    plant = env.split("-")[0]
    connection = app.open_database(env)
    written = 0
    skipped = 0
    try:
        cursor = connection.cursor(as_dict=True)
        cursor.execute(
            "SELECT RTRIM(PluginCommand) AS PluginCommand, PluginName, PluginDescription, "
            "PluginFileName, RTRIM(MetadataId) AS MetadataId "
            "FROM dbo.SysPlugIn WITH (NOLOCK) "
            "WHERE RTRIM(MetadataId) <> '' "
            "ORDER BY RTRIM(PluginCommand)"
        )
        plugins = cursor.fetchall()
        for plugin in plugins:
            command = str(plugin.get("PluginCommand") or "").strip()
            rows = app.metadata_tree(cursor, str(plugin.get("MetadataId") or "").strip())
            if not command or not rows:
                skipped += 1
                continue

            folder = app.function_folder(plant, command)
            page = folder / "object.json"
            if page.is_file():
                data = json.loads(page.read_text(encoding="utf-8"))
            else:
                data = app.skeleton_pack(plant, command)
                folder.mkdir(parents=True, exist_ok=True)

            data["objects"] = app.merge_objects(folder, data, rows, plugin)
            app.sync_plugin(data, plant, command, env, plugin, str(rows[0].get("MetadataName") or ""))
            data.pop("table", None)
            data.pop("procedures", None)
            page.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            written += 1
    finally:
        connection.close()
    return written, skipped


def main() -> None:
    envs = tuple(sys.argv[1:]) or DEFAULT_ENVS
    for env in envs:
        written, skipped = export_env(env)
        print(f"{env}: 写入 {written} 个功能，跳过 {skipped} 个")


if __name__ == "__main__":
    main()
