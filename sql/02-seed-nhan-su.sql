-- ============================================================================
-- SEED NHÂN SỰ — Phòng QLNB, Chi nhánh Tràng Tiền
-- Nguồn: Sheet '1_Danh sach CBNV' (giống nhau trong 8 file cá nhân), đối chiếu
-- Thông báo phân công công việc P.QLNB T6/2026 + bổ sung Ngapt23.
-- Chạy sau 01-schema-va-rls.sql. Chạy lại an toàn (dùng on conflict).
-- ============================================================================

insert into departments (ma_phong, ten_phong) values
  ('QLNB', 'Quản lý nội bộ')
on conflict (ma_phong) do nothing;

-- Bước 1: chèn 12 cán bộ, CHƯA gán quản lý trực tiếp (tránh lỗi thứ tự khoá ngoại
-- vì một số người quản lý người khác trong cùng danh sách này).
insert into employees (ma_cbnv, ho_ten, chuc_danh, department_id, nhom_nghiep_vu, app_role, kpi_phu_luc)
select v.ma_cbnv, v.ho_ten, v.chuc_danh, d.id, v.nhom_nv, v.app_role, v.kpi_phu_luc
from (values
  ('00157251','Vũ Thị Lệ',              'Trưởng phòng QLNB',                         'TCHC','truong_phong',     'Cấu trúc chung (chưa có phụ lục riêng)'),
  ('00169422','Nguyễn Thị Phương Mai',  'Phó trưởng phòng QLNB',                     'TCHC','pho_truong_phong', 'KPI-CNH-QLNB1 (Phó trưởng phòng)'),
  ('00146999','Nguyễn Thị Nguyệt Anh',  'Chuyên viên TCNS cấp 3',                    'TCHC','canbo',            'KPI-CNH-QLNB2 (Chuyên viên/NV Tổ chức nhân sự)'),
  ('00157761','Nguyễn Hồng Quang',      'NV Hành chính - QL mua sắm TS cấp 4',       'TCHC','canbo',            'KPI-CNH-QLNB3 (NV Hành chính - QL mua sắm TS)'),
  ('00157764','Nguyễn Văn Hà',          'Lái xe',                                    'TCHC','canbo',            'Cấu trúc chung (chưa có phụ lục riêng)'),
  ('00157765','Tạ Duy Hiển',            'Lái xe',                                    'TCHC','canbo',            'Cấu trúc chung (chưa có phụ lục riêng)'),
  ('00157760','Phùng Ngọc Tiệp',        'Bảo vệ',                                    'TCHC','canbo',            'Cấu trúc chung (chưa có phụ lục riêng)'),
  ('00157279','Nguyễn Vân Anh',         'Phó trưởng phòng QLNB',                     'TCKT','pho_truong_phong', 'KPI-CNH-QLNB1 (Phó trưởng phòng)'),
  ('00157267','Hoàng Thị Thủy',         'Chuyên viên TCKT cấp 2',                    'TCKT','canbo',            'Cấu trúc chung (Chuyên viên TCKT)'),
  ('00157280','Trần Thùy Dương',        'Phó trưởng phòng QLNB (nghỉ TS)',           'KHTH','pho_truong_phong', 'KPI-CNH-QLNB1 (Phó trưởng phòng)'),
  ('00157275','Trần Thị Thu Giang',     'Chuyên viên KHKD cấp 2',                    'KHTH','canbo',            'Cấu trúc chung (Chuyên viên KHKD)'),
  ('00183881','Phạm Thanh Ngà',         'Chuyên viên KHKD cấp 1',                    'KHTH','canbo',            'Cấu trúc chung (Chuyên viên KHKD)')
) as v(ma_cbnv, ho_ten, chuc_danh, nhom_nv, app_role, kpi_phu_luc)
join departments d on d.ma_phong = 'QLNB'
on conflict (ma_cbnv) do update set
  ho_ten = excluded.ho_ten, chuc_danh = excluded.chuc_danh,
  nhom_nghiep_vu = excluded.nhom_nghiep_vu, app_role = excluded.app_role,
  kpi_phu_luc = excluded.kpi_phu_luc;

-- Bước 2: gán quản lý trực tiếp (đúng cột 'Cán bộ quản lý trực tiếp' trong Excel gốc).
-- Vũ Thị Lệ (Trưởng phòng) không có quản lý trực tiếp trong bảng này — quản lý
-- của chị là Giám đốc Chi nhánh, ngoài phạm vi phòng QLNB.
update employees e set quan_ly_truc_tiep_id = m.id
from (values
  ('00169422','00157251'), -- Phương Mai → Vũ Thị Lệ
  ('00146999','00169422'), -- Nguyệt Anh → Phương Mai
  ('00157761','00169422'), -- Hồng Quang → Phương Mai
  ('00157764','00157251'), -- Văn Hà → Vũ Thị Lệ
  ('00157765','00157251'), -- Duy Hiển → Vũ Thị Lệ
  ('00157760','00157251'), -- Ngọc Tiệp → Vũ Thị Lệ
  ('00157279','00157251'), -- Vân Anh → Vũ Thị Lệ
  ('00157267','00157279'), -- Thị Thủy → Vân Anh
  ('00157280','00157251'), -- Thùy Dương → Vũ Thị Lệ
  ('00157275','00157280'), -- Thu Giang → Thùy Dương
  ('00183881','00157280')  -- Thanh Ngà → Thùy Dương
) as map(ma_cbnv, ma_cbnv_quan_ly)
join employees m on m.ma_cbnv = map.ma_cbnv_quan_ly
where e.ma_cbnv = map.ma_cbnv;

-- ⚠️ CẦN LÀM THÊM SAU KHI CHẠY FILE NÀY (không tự động được vì cần thông tin
-- ngoài phạm vi phòng QLNB):
--   1. Thêm tài khoản Ban Giám đốc — chèn 1 dòng employees với app_role =
--      'ban_giam_doc', department_id = NULL (xem toàn chi nhánh), rồi tạo tài
--      khoản đăng nhập tương ứng bằng scripts/tao-tai-khoan-dang-nhap.mjs.
--   2. Vũ Thị Lệ (Trưởng phòng) hiện CHƯA có danh mục công việc — file gốc
--      không có catalog riêng cho vị trí Trưởng phòng. Cần xây dựng bổ sung
--      (theo đúng công thức a×0.4+b×0.5+c×0.1) rồi insert vào job_catalog.
