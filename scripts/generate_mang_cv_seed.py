"""
Đọc trực tiếp qlnb.xlsx "chuẩn" (sheet Mảng công việc / Công việc / Cán bộ) và
sinh sql/09-seed-danh-muc-chuan.sql — nhân sự mới (Huỳnh Thị Bắc), phân công
mảng cho 13 người, và 444 đầu việc thật (loại 9 dòng demo "Việc khác X.Y",
sửa 6 dòng Tạp vụ bị lệch cột Mảng CV/Cán bộ).

Chạy: python scripts/generate_mang_cv_seed.py "<đường dẫn qlnb.xlsx chuẩn>"
"""
import sys, os, io, re
import openpyxl

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

TAPVU_FIX_MANG = 6  # Tạp vụ — 6 dòng TAP VU bị lệch cột, ép về đúng mảng này
DEMO_ROW_PATTERN = re.compile(r'^Việc khác \d\.\d$')

def esc(v):
    if v is None:
        return "NULL"
    s = str(v).strip()
    if s == "":
        return "NULL"
    return "'" + s.replace("'", "''") + "'"

def esc_num(v):
    # Luôn ép kiểu ::numeric rõ ràng — nếu để NULL trần, Postgres suy luận kiểu
    # cột trong VALUES (...) theo dòng đầu tiên; cột nào toàn NULL/phần lớn NULL
    # dễ bị suy ra kiểu 'text' rồi báo lỗi "is of type numeric but expression
    # is of type text" khi insert vào cột numeric thật.
    if v is None:
        return "NULL::numeric"
    try:
        f = float(v)
    except (TypeError, ValueError):
        return "NULL::numeric"
    return f"{round(f, 2)}::numeric"

def main(path):
    wb = openpyxl.load_workbook(path, data_only=True)

    # ---- Cán bộ (nhân sự mới + phân công mảng) ----
    ws_cb = wb['Cán bộ']
    cb_rows = []
    for row in ws_cb.iter_rows(min_row=2, max_col=4, values_only=True):
        ma_cb, ten, muc, mang_str = row
        if not ten:
            continue
        mang_list = [int(x.strip()) for x in str(mang_str).split(',') if x.strip()]
        cb_rows.append((ma_cb, ten.strip(), (muc or '').strip(), mang_list))
    print(f"-- Cán bộ: {len(cb_rows)} người")
    for r in cb_rows:
        print(f"--   {r}")

    # ---- Công việc (danh mục chuẩn) ----
    ws_cv = wb['Công việc']
    group_seq = {}
    job_rows = []
    skipped_demo = 0
    fixed_tapvu = 0
    for row in ws_cv.iter_rows(min_row=2, max_col=8, values_only=True):
        macv_group, ten_cv, mang, cb, ks, tp, pgd, gd = row
        if not ten_cv:
            continue
        if DEMO_ROW_PATTERN.match(ten_cv.strip()):
            skipped_demo += 1
            continue
        if macv_group == 'TAP VU' and mang in (10, 20, 30):
            # 6 dòng bị lệch cột: số ở cột Mảng CV thực ra là điểm Cán bộ.
            cb = mang
            mang = TAPVU_FIX_MANG
            fixed_tapvu += 1

        group_key = (macv_group or 'KHAC').strip().upper().replace(' ', '')
        group_seq[group_key] = group_seq.get(group_key, 0) + 1
        ma_cv = f"{group_key}-{group_seq[group_key]:03d}"

        job_rows.append((ma_cv, ten_cv.strip(), int(mang), cb, ks, tp, pgd, gd))

    print(f"-- Công việc: {len(job_rows)} dòng hợp lệ (bỏ {skipped_demo} dòng demo, sửa {fixed_tapvu} dòng Tạp vụ lệch cột)")

    out_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'sql', '09-seed-danh-muc-chuan.sql'))
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write("-- ============================================================================\n")
        f.write("-- SEED DANH MỤC CÔNG VIỆC CHUẨN — sinh tự động từ qlnb.xlsx (sheet Mảng công\n")
        f.write(f"-- việc / Công việc / Cán bộ). {len(job_rows)} đầu việc, {len(cb_rows)} cán bộ.\n")
        f.write("-- Chạy sau 08-mang-cv-va-danh-muc-chuan.sql. Chạy lại an toàn (on conflict).\n")
        f.write("-- ============================================================================\n\n")

        # 1) Huỳnh Thị Bắc — nhân sự mới, chưa có mã CBNV/tài khoản đăng nhập.
        f.write("-- Nhân sự mới: Huỳnh Thị Bắc (Khoán gọn) — mã CBNV tạm thời, CHƯA có tài khoản\n")
        f.write("-- đăng nhập (accounts) cho tới khi có mã CBNV thật.\n")
        f.write("insert into employees (ma_cbnv, ho_ten, chuc_danh, department_id, nhom_nghiep_vu, app_role, kpi_phu_luc, quan_ly_truc_tiep_id)\n")
        f.write("select 'TAMTHOI-BACHT', 'Huỳnh Thị Bắc', 'Khoán gọn (nhân viên hợp đồng khoán)', d.id, 'TCHC', 'canbo',\n")
        f.write("  'Chưa có phụ lục KPI riêng', (select id from employees where ma_cbnv = '00169422')\n")
        f.write("from departments d where d.ma_phong = 'QLNB'\n")
        f.write("on conflict (ma_cbnv) do nothing;\n\n")

        # 2) employee_mang_cv — phân công mảng cho toàn bộ 13 người.
        f.write("-- Phân công mảng cho từng cán bộ (1 người có thể thuộc nhiều mảng).\n")
        f.write("insert into employee_mang_cv (employee_id, mang_cv_id)\n")
        f.write("select e.id, m.id\n")
        f.write("from (values\n")
        lines = []
        for ma_cb, ten, muc, mang_list in cb_rows:
            macbnv_lookup = esc(ma_cb) if ma_cb else "'TAMTHOI-BACHT'"
            for mang_so in mang_list:
                lines.append(f"  ({macbnv_lookup}, {mang_so})")
        f.write(",\n".join(lines))
        f.write("\n) as v(ma_cbnv, ma_mang)\n")
        f.write("join employees e on e.ma_cbnv = v.ma_cbnv\n")
        f.write("join mang_cv m on m.ma_mang = v.ma_mang\n")
        f.write("on conflict (employee_id, mang_cv_id) do nothing;\n\n")

        # 3) job_catalog — 444 đầu việc thật.
        f.write("-- Danh mục công việc chuẩn — điểm riêng từng cấp, NULL = cấp đó không tham gia.\n")
        f.write("insert into job_catalog (ma_cv, ten_cong_viec, mang_cv_id, diem_can_bo, diem_kiem_soat, diem_truong_phong, diem_pgd, diem_gd)\n")
        f.write("select v.ma_cv, v.ten_cong_viec, m.id, v.diem_can_bo, v.diem_kiem_soat, v.diem_truong_phong, v.diem_pgd, v.diem_gd\n")
        f.write("from (values\n")
        lines = []
        for ma_cv, ten_cv, mang, cb, ks, tp, pgd, gd in job_rows:
            lines.append(
                f"  ({esc(ma_cv)},{esc(ten_cv)},{mang},{esc_num(cb)},{esc_num(ks)},{esc_num(tp)},{esc_num(pgd)},{esc_num(gd)})"
            )
        f.write(",\n".join(lines))
        f.write("\n) as v(ma_cv, ten_cong_viec, ma_mang, diem_can_bo, diem_kiem_soat, diem_truong_phong, diem_pgd, diem_gd)\n")
        f.write("join mang_cv m on m.ma_mang = v.ma_mang\n")
        f.write("on conflict (ma_cv) do nothing;\n")

    print(f"\n-- Đã ghi {out_path}")

if __name__ == "__main__":
    main(sys.argv[1])
