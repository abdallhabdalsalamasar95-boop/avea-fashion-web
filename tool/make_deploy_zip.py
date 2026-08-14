from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

src = Path(r"D:\flutter_projects\CarmenKarla\build\web")
dst = Path(r"D:\flutter_projects\CarmenKarla\deploy_web.zip")

if dst.exists():
    dst.unlink()

with ZipFile(dst, "w", compression=ZIP_DEFLATED) as zf:
    for path in src.rglob("*"):
        if path.is_file():
            zf.write(path, path.relative_to(src).as_posix())

print(dst)