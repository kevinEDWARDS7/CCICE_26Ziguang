from pathlib import Path
import shutil

root = Path("code_26_2/fpga/template_projects/DL_HDMI40IN_PCIE_RK3568")

pds = root / "project/dl_prj.pds"
active_top = root / "source/dl_fpga_prj.v"
fixed_top = root / "project/source/dl_fpga_prj.v"

if not pds.exists():
    raise FileNotFoundError(pds)
if not active_top.exists():
    raise FileNotFoundError(active_top)
if not fixed_top.exists():
    raise FileNotFoundError(fixed_top)

# 1. 备份
shutil.copy2(pds, pds.with_suffix(".pds.bak"))
shutil.copy2(active_top, active_top.with_suffix(".v.bak"))

# 2. 用较新的正常顶层覆盖 PDS 实际读取的顶层文件
active_top.write_bytes(fixed_top.read_bytes())

# 3. 修正 PDS 顶层
text = pds.read_text(encoding="utf-8", errors="ignore")

text = text.replace(
    '(_file "../source/cmos_8_16bit.v" + "cmos_pixel_width_adapter"',
    '(_file "../source/cmos_8_16bit.v"'
)

text = text.replace(
    '(_file "../source/dl_fpga_prj.v"\n',
    '(_file "../source/dl_fpga_prj.v" + "dl_fpga_prj"\n'
)

pds.write_text(text, encoding="utf-8", newline="\n")

# 4. 清理旧 PDS 产物
for d in [
    root / "project/compile",
    root / "project/synthesize",
    root / "project/constraint_check",
]:
    if d.exists():
        shutil.rmtree(d)

print("[OK] source/dl_fpga_prj.v 已由 project/source/dl_fpga_prj.v 覆盖")
print("[OK] dl_prj.pds 顶层已切换为 dl_fpga_prj")
print("[OK] 已删除旧 compile/synthesize/constraint_check 产物")