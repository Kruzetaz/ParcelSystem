#!/usr/bin/env python3
"""
merge_runs.py — Pre-process a .docx template: merge Word's split {{placeholder}} runs
=======================================================================================

ปัญหา: เวลาพิมพ์ {{placeholder}} ใน Word แล้วเปิด save/autocorrect/spellcheck ทำงาน
Word มักตัดข้อความออกเป็นหลาย <w:r> (text run) โดยแทรก <w:proofErr> คั่นกลาง เช่น:

    <w:r><w:t>{{</w:t></w:r>
    <w:proofErr w:type="spellStart"/>
    <w:r><w:t>item_name</w:t></w:r>
    <w:proofErr w:type="spellEnd"/>
    <w:r><w:t>}}</w:t></w:r>

โค้ด Flutter (docx_template_service.dart) มี merge logic รันตอน runtime อยู่แล้วทุกครั้งที่
generate เอกสาร แต่การรัน script นี้ "ครั้งเดียว" กับ master_template.docx ต้นฉบับ แล้วบันทึก
เป็นเวอร์ชัน merged-runs ไว้ใช้ตรงๆ จะช่วยให้:
  - เปิดไฟล์ผลลัพธ์ตรวจสอบด้วยตาก่อนได้ (grep หา {{...}} เจอครบ ไม่กระจายไป)
  - runtime ไม่ต้องเสียเวลา merge ซ้ำทุกครั้งที่ generate เอกสาร (เร็วขึ้นเล็กน้อย)
  - ลดความเสี่ยงถ้า merge logic version ใน Flutter เปลี่ยนไปในอนาคต ไฟล์ template ที่ merge
    ไว้แล้วยังใช้ได้ปกติ ไม่ต้อง rely on runtime merge อีกต่อไป

วิธีใช้:
    python3 merge_runs.py master_template.docx master_template_merged.docx

ถ้าไม่ระบุ output จะสร้างไฟล์ใหม่ชื่อ <ชื่อเดิม>_merged.docx ในโฟลเดอร์เดียวกัน

หลังรันเสร็จ ควรเปิดไฟล์ output ด้วย Word/LibreOffice ตรวจว่าหน้าตาเอกสารเหมือนเดิมทุกอย่าง
(merge run จะทำให้ format ย่อยๆ กลางคำ {{...}} หายไปบ้าง แต่ปกติไม่มีผลเพราะ placeholder
ไม่ค่อยมีการไฮไลต์ครึ่งคำอยู่แล้ว) แล้วค่อยเอาไฟล์นี้ไปแทนที่ assets/templates/master_template.docx
"""

import argparse
import re
import shutil
import sys
import zipfile
from pathlib import Path

DOCUMENT_XML_PATH = "word/document.xml"


def merge_split_placeholder_runs(xml: str) -> str:
    """รวม <w:r> ที่ถูกตัดขาดกลาง {{placeholder}} ให้กลับเป็น run เดียว
    ต่อ 1 ย่อหน้า (<w:p>...</w:p>) — logic เดียวกับ docx_template_service.dart
    เพื่อให้ผลลัพธ์ตรงกันกับตอน runtime merge ทุกประการ
    """
    para_pattern = re.compile(r"<w:p\b[^>]*>.*?</w:p>", re.DOTALL)

    def repl(match: re.Match) -> str:
        para = match.group(0)
        if "{{" not in para:
            return para

        t_pattern = re.compile(r"<w:t\b[^>]*>(.*?)</w:t>", re.DOTALL)
        texts = t_pattern.findall(para)
        combined = "".join(texts)

        # ถ้ารวมข้อความทั้งย่อหน้าแล้วไม่มี {{...}} ที่สมบูรณ์ ก็ไม่ต้องทำอะไร
        if not re.search(r"\{\{[^{}]+\}\}", combined):
            return para

        # heuristic ตรวจว่า {{ หรือ }} ถูกตัดขาดคนละ <w:t> จริงไหม
        joined = "\u0001".join(texts)
        looks_split = "{{" in joined and (
            re.search(r"\{\{[^\u0001]*\u0001", joined)
            or re.search(r"\u0001[^\u0001]*\}\}", joined)
        )
        if not looks_split:
            return para

        # ใช้ rPr (format) ของ run แรกในย่อหน้าเป็นแม่แบบของ run ที่ merge แล้ว
        run_pattern = re.compile(r"<w:r\b[^>]*>.*?</w:r>", re.DOTALL)
        first_run = run_pattern.search(para)
        rpr = ""
        if first_run:
            rpr_match = re.search(r"<w:rPr>.*?</w:rPr>", first_run.group(0), re.DOTALL)
            if rpr_match:
                rpr = rpr_match.group(0)

        escaped = (
            combined.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        )
        merged_run = f'<w:r>{rpr}<w:t xml:space="preserve">{escaped}</w:t></w:r>'

        without_runs = run_pattern.sub("", para)
        return without_runs.replace("</w:p>", merged_run + "</w:p>", 1)

    return para_pattern.sub(repl, xml)


def process_docx(input_path: Path, output_path: Path) -> dict:
    """แกะ .docx (zip) → merge run ใน word/document.xml → บีบอัดกลับเป็นไฟล์ใหม่
    ไฟล์อื่นๆ ใน zip (media, styles, fontTable ฯลฯ) คัดลอกผ่านตรงๆ ไม่แตะต้อง
    """
    with zipfile.ZipFile(input_path, "r") as zin:
        names = zin.namelist()
        if DOCUMENT_XML_PATH not in names:
            raise ValueError(
                f"ไม่พบ {DOCUMENT_XML_PATH} ในไฟล์ — {input_path} อาจไม่ใช่ .docx ที่ถูกต้อง"
            )

        original_xml = zin.read(DOCUMENT_XML_PATH).decode("utf-8")

        before_open = original_xml.count("{{")
        before_intact = len(re.findall(r"\{\{[a-zA-Z_0-9]+\}\}", original_xml))

        merged_xml = merge_split_placeholder_runs(original_xml)

        after_intact = len(re.findall(r"\{\{[a-zA-Z_0-9]+\}\}", merged_xml))

        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename == DOCUMENT_XML_PATH:
                    data = merged_xml.encode("utf-8")
                zout.writestr(item, data)

    return {
        "raw_double_brace_count": before_open,
        "intact_placeholders_before": before_intact,
        "intact_placeholders_after": after_intact,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Merge Word's split {{placeholder}} runs in a .docx template (one-time preprocessing)."
    )
    parser.add_argument("input", type=Path, help="ไฟล์ .docx ต้นฉบับ (master template)")
    parser.add_argument(
        "output",
        type=Path,
        nargs="?",
        default=None,
        help="ไฟล์ผลลัพธ์ (ถ้าไม่ระบุ จะสร้าง <ชื่อเดิม>_merged.docx)",
    )
    args = parser.parse_args()

    input_path: Path = args.input
    if not input_path.exists():
        print(f"❌ ไม่พบไฟล์: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path: Path = args.output or input_path.with_name(
        input_path.stem + "_merged" + input_path.suffix
    )

    if output_path.resolve() == input_path.resolve():
        print("❌ output ต้องไม่ใช่ไฟล์เดียวกับ input (จะทับต้นฉบับ)", file=sys.stderr)
        sys.exit(1)

    stats = process_docx(input_path, output_path)

    print(f"✅ เขียนไฟล์ผลลัพธ์แล้ว: {output_path}")
    print(f"   จำนวน '{{{{' ที่พบทั้งหมดในเอกสาร: {stats['raw_double_brace_count']}")
    print(f"   placeholder ที่สมบูรณ์ (ก่อน merge): {stats['intact_placeholders_before']}")
    print(f"   placeholder ที่สมบูรณ์ (หลัง merge): {stats['intact_placeholders_after']}")

    if stats["intact_placeholders_after"] < stats["raw_double_brace_count"]:
        print(
            "   ⚠️  ยังมีบางจุดที่ merge ไม่ครบ (อาจมี placeholder ข้ามย่อหน้า/ตาราง "
            "หรือรูปแบบ XML ที่ซับซ้อนกว่าเดิม) — เปิดไฟล์ output ตรวจสอบด้วยตาก่อนใช้งานจริง"
        )


if __name__ == "__main__":
    main()