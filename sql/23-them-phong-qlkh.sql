-- ============================================================================
-- THÊM PHÒNG QLKH vào hệ thống (dùng chung app với QLNB, tách dữ liệu theo phòng).
-- Nguồn: KPI_QLKH_.xlsx (40 việc, 18 mảng, 2 cán bộ) + Trưởng phòng Hồ Hoàng Tuấn (157348).
--
--  * mang_cv gắn theo phòng (department_id): mảng của QLNB và QLKH đánh số riêng, không đụng nhau.
--  * Mảng của từng việc được SUY RA THEO SỐ HIỆU VIỆC (QLKH 1 -> mảng 1, 4.1-4.2 -> 5, 4.3-4.5 -> 6,
--    4.6 -> 7, 5 -> 8, 6 -> 9, 7 -> 10, 8 -> 11, 9.x -> 12, 10 -> 13, 11 -> 14, 12 -> 15, 13 -> 16,
--    14 -> 17, 15 -> 18) vì cột "Mảng CV" trong file chỉ có 1-5, không khớp 18 mảng.
--  * Mã việc giữ số hiệu gốc (QLKH-2.1...), xếp theo đúng thứ tự trong file (cột thu_tu).
--  * Tài khoản: mật khẩu mặc định 123456, bắt đổi ở lần đăng nhập đầu.
--  * Tổng quan (Trưởng phòng) chỉ tính nhân sự CÙNG PHÒNG — trước đây cộng cả mọi phòng.
-- Chạy lại an toàn.
-- ============================================================================

insert into departments (ma_phong, ten_phong) values ('QLKH', 'Phòng QLKH')
on conflict (ma_phong) do nothing;

alter table mang_cv add column if not exists department_id uuid references departments(id);
update mang_cv set department_id = (select id from departments where ma_phong = 'QLNB') where department_id is null;
alter table mang_cv drop constraint if exists mang_cv_ma_mang_key;
create unique index if not exists uq_mang_cv_phong_ma on mang_cv (department_id, ma_mang);

alter table job_catalog add column if not exists thu_tu int;

do $do$
declare
  v_qlkh uuid := (select id from departments where ma_phong = 'QLKH');
  v_tp uuid;
begin
  -- 1) 18 mảng của QLKH
  insert into mang_cv (ma_mang, ten_mang, department_id, la_diem_thuong) values
    (1, 'Đánh giá thực trạng nợ ngoại bảng, nợ xấu', v_qlkh, false),
    (2, 'Giao kế hoạch', v_qlkh, false),
    (3, 'Xây dựng phương án xử lý nợ', v_qlkh, false),
    (4, 'Triển khai các biện pháp xử lý nợ', v_qlkh, false),
    (5, 'Định giá tài sản bảo đảm', v_qlkh, false),
    (6, 'Bán đấu giá tài sản/khoản nợ', v_qlkh, false),
    (7, 'Đôn đốc khách hàng', v_qlkh, false),
    (8, 'Giảm miễn lãi', v_qlkh, false),
    (9, 'Bán nợ', v_qlkh, false),
    (10, 'Xử lý rủi ro', v_qlkh, false),
    (11, 'Xử lý tài sản', v_qlkh, false),
    (12, 'Khởi kiện, phá sản và thi hành án', v_qlkh, false),
    (13, 'Xóa nợ', v_qlkh, false),
    (14, 'Báo cáo', v_qlkh, false),
    (15, 'Xây dựng văn bản chế độ', v_qlkh, false),
    (16, 'Tham gia các dự án/tổ/nhóm ngoài nhiệm vụ thường xuyên', v_qlkh, false),
    (17, 'Lưu trữ hồ sơ', v_qlkh, false),
    (18, 'Cung cấp tài liệu thanh tra/kiểm tra/kiểm toán', v_qlkh, false)
  on conflict (department_id, ma_mang) do update set ten_mang = excluded.ten_mang;

  -- 2) Nhân sự: Trưởng phòng + 2 cán bộ
  insert into employees (ma_cbnv, ho_ten, chuc_danh, department_id, app_role, active) values
    ('157348', 'Hồ Hoàng Tuấn', 'Trưởng phòng QLKH', v_qlkh, 'truong_phong', true),
    ('145294', 'Nguyễn Việt Hưng', 'Chuyên viên', v_qlkh, 'canbo', true),
    ('62494', 'Phạm Văn Hiếu', 'Chuyên viên', v_qlkh, 'canbo', true)
  on conflict (ma_cbnv) do update set
    ho_ten = excluded.ho_ten, chuc_danh = excluded.chuc_danh, department_id = excluded.department_id,
    app_role = excluded.app_role, active = true;

  select id into v_tp from employees where ma_cbnv = '157348';
  update employees set quan_ly_truc_tiep_id = v_tp
  where ma_cbnv in ('145294', '62494');

  insert into accounts (employee_id, mat_khau_hash, must_change_password)
  select id, extensions.crypt('123456', extensions.gen_salt('bf')), true
  from employees where ma_cbnv in ('157348', '145294', '62494')
  on conflict (employee_id) do nothing;

  -- 3) Phân công mảng: 2 cán bộ theo sheet "Cán bộ"; Trưởng phòng được cả 18 mảng
  delete from employee_mang_cv where employee_id in (select id from employees where ma_cbnv in ('157348', '145294', '62494'));
  insert into employee_mang_cv (employee_id, mang_cv_id)
  select e.id, mc.id
  from (values
    ('157348', 1),
    ('157348', 2),
    ('157348', 3),
    ('157348', 4),
    ('157348', 5),
    ('157348', 6),
    ('157348', 7),
    ('157348', 8),
    ('157348', 9),
    ('157348', 10),
    ('157348', 11),
    ('157348', 12),
    ('157348', 13),
    ('157348', 14),
    ('157348', 15),
    ('157348', 16),
    ('157348', 17),
    ('157348', 18),
    ('145294', 1),
    ('145294', 3),
    ('145294', 4),
    ('145294', 5),
    ('145294', 6),
    ('145294', 7),
    ('145294', 8),
    ('145294', 9),
    ('145294', 11),
    ('145294', 13),
    ('145294', 14),
    ('145294', 15),
    ('62494', 1),
    ('62494', 3),
    ('62494', 4),
    ('62494', 5),
    ('62494', 6),
    ('62494', 7),
    ('62494', 8),
    ('62494', 9),
    ('62494', 11),
    ('62494', 13),
    ('62494', 14),
    ('62494', 15)
  ) a(ma_cbnv, ma_mang)
  join employees e on e.ma_cbnv = a.ma_cbnv
  join mang_cv mc on mc.department_id = v_qlkh and mc.ma_mang = a.ma_mang
  on conflict (employee_id, mang_cv_id) do nothing;

  -- 4) Danh mục việc QLKH
  insert into job_catalog (ma_cv, ten_cong_viec, mang_cv_id, diem_can_bo, diem_kiem_soat, tan_suat, thu_tu, active)
  select v.ma_cv, v.ten, mc.id, v.diem_can_bo, v.diem_kiem_soat, v.tan_suat, v.thu_tu, true
  from (values
    (1, 'QLKH-1', 'Tổng hợp số liệu, phân tích đánh giá về thực trạng và đề xuất phương hướng tổng thể', 1, 7.3::numeric, 7.3::numeric, 'Hàng ngày'),
    (2, 'QLKH-2', 'Đầu mối tổng hợp/rà soát số liệu Giao kế hoạch đến từng khách hàng/khoản nợ trực tiếp', 2, 9.8::numeric, 9.8::numeric, 'Hàng quý'),
    (3, 'QLKH-2.1', 'Cán bộ tổng hợp rà soát số liệu theo từng khách hàng/khoản nợ trực tiếp', 2, 7.7::numeric, 7.7::numeric, 'Hàng quý'),
    (4, 'QLKH-3', 'Xây dựng phương án xử lý nợ đối với khách hàng trình Lãnh đạo Chi nhánh', 3, 10.0::numeric, 10.0::numeric, 'Hàng ngày'),
    (5, 'QLKH-4.1', 'Tham gia định giá trực tiếp', 5, 8.0::numeric, 8.0::numeric, 'Khi phát sinh'),
    (6, 'QLKH-4.2', 'Đề xuất, phối hợp thẩm định giá độc lập', 5, 6.0::numeric, 6.0::numeric, 'Khi phát sinh'),
    (7, 'QLKH-4.3', 'Trình lựa chọn công ty bán đấu giá', 6, 6.2::numeric, 6.2::numeric, 'Khi phát sinh'),
    (8, 'QLKH-4.4', 'Phối hợp công ty đấu giá triển khai bán đấu giá từng lần', 6, 7.7::numeric, 7.7::numeric, 'Khi phát sinh'),
    (9, 'QLKH-4.5', 'Hoàn thiện thủ tục sau đấu giá: ký hợp đồng, bàn giao tài sản/khoản nợ', 6, 8.0::numeric, 8.0::numeric, 'Khi phát sinh'),
    (10, 'QLKH-4.6', 'Làm việc với khách hàng, gửi văn bản…', 7, 8.0::numeric, 8.0::numeric, 'Khi phát sinh'),
    (11, 'QLKH-5', 'Đề xuất, trình duyệt giảm miễn lãi thẩm quyền chi nhánh', 8, 8.0::numeric, 8.0::numeric, 'Hàng ngày'),
    (12, 'QLKH-5.1', 'Đề xuất, trình duyệt giảm miễn lãi thẩm quyền Hội sở chính', 8, 9.0::numeric, 9.0::numeric, 'Hàng ngày'),
    (13, 'QLKH-6', 'Đề xuất trình bán nợ (Thẩm quyền chi nhánh)', 9, 9.7::numeric, 9.7::numeric, 'Hàng ngày'),
    (14, 'QLKH-6.2', 'Đề xuất trình bán nợ (Thẩm quyền HSC)', 9, 8.9::numeric, 8.9::numeric, 'Hàng ngày'),
    (15, 'QLKH-6.3', 'Các thủ tục thực hiện sau khi bán nợ', 9, 8.0::numeric, 8.0::numeric, 'Hàng ngày'),
    (16, 'QLKH-7', 'Làm hồ sơ XLRR trình HSC', 10, 6.2::numeric, 6.2::numeric, 'Hàng quý'),
    (17, 'QLKH-8', 'Trình Xử lý tài sản thẩm quyền chi nhánh', 11, 8.0::numeric, 8.0::numeric, 'Hàng ngày'),
    (18, 'QLKH-8.1', 'Trình Xử lý tài sản thẩm quyền HSC', 11, 8.8::numeric, 8.8::numeric, 'Hàng ngày'),
    (19, 'QLKH-8.2', 'Các nội dung triển khai xử lý tài sản sau khi có phê duyệt xử lý', 11, 9.2::numeric, 9.2::numeric, 'Hàng ngày'),
    (20, 'QLKH-9', 'Rà soát, đánh giá, hoàn thiện hồ sơ khởi kiện.', 12, 9.8::numeric, 9.8::numeric, 'Hàng ngày'),
    (21, 'QLKH-9.1', 'Lập Tờ trình đề xuất khởi kiện khách hàng.', 12, 8.5::numeric, 8.5::numeric, 'Hàng ngày'),
    (22, 'QLKH-9.2', 'Soạn quyết định ủy quyền tham gia tố tụng.', 12, 6.2::numeric, 6.2::numeric, 'Hàng ngày'),
    (23, 'QLKH-9.3', 'Soạn thảo Đơn khởi kiện, Yêu cầu độc lập, Yêu cầu phản tố, Đơn yêu cầu áp dụng biện pháp khẩn cấp tạm thời, Đơn yêu cầu mở thủ tục phá sản doanh nghiệp; văn bản đề nghị tham gia thủ tục phá sản; Giấy đòi nợ, Đơn đề nghị áp dụng biện pháp khẩn cấp tạm thời ...', 12, 9.4::numeric, 9.4::numeric, 'Hàng ngày'),
    (24, 'QLKH-9.4', 'Xây dựng bản luận cứ bảo vệ quyền lợi của BIDV.', 12, 9.0::numeric, 9.0::numeric, 'Hàng ngày'),
    (25, 'QLKH-9.5', 'Đề xuất việc thuê tư vấn pháp lý hỗ trợ việc khởi kiện, giải quyết tranh chấp', 12, 8.0::numeric, 8.0::numeric, 'Hàng ngày'),
    (26, 'QLKH-9.6', 'Tham gia trực tiếp tố tụng tại tòa án đối với các vụ án/vụ việc dân sự/hành chính/hình sự với tư cách Nguyên đơn, Bị đơn, Người có quyền lợi và nghĩa vụ liên quan như: Tham gia các buổi hòa giải; Phiên họp công khai chứng cứ và hòa giải; Tham gia buổi xem xét, thẩm định tại chỗ TS; Phiên đối chất; Phiên tòa xét xử sơ thẩm/phúc thẩm; ...', 12, 9.7::numeric, 9.7::numeric, 'Hàng ngày'),
    (27, 'QLKH-9.7', 'Soạn thảo các văn bản liên quan gửi Cơ quan Tòa án trong quá trình tố tụng như Bản tự Khai, Đơn đề nghị xem xét, thẩm định tại chỗ; VB đề nghị Tòa án tiến hành thu thập chứng cứ, tài liệu; Đơn đề nghị xét xử; Văn bản đề nghị xử lý tài sản bảo đảm trong giai đoạn phá sản; Văn bản chỉ định Quản tài viên;...', 12, 9.4::numeric, 9.4::numeric, 'Hàng ngày'),
    (28, 'QLKH-9.8', 'Soạn thảo Đơn kháng cáo, Đơn đề nghị kháng nghị, Đơn giám đốc thẩm, tái thẩm', 12, 9.4::numeric, 9.4::numeric, 'Hàng ngày'),
    (29, 'QLKH-9.9', 'Soạn thảo các văn bản kiến nghị, khiếu nại về hành vi vi phạm của Cơ quan tiến hành tố tụng, người tiến hành tố tụng.', 12, 9.4::numeric, 9.4::numeric, 'Hàng ngày'),
    (30, 'QLKH-9.10', 'Soạn thảo các văn bản trong quá trình Thi hành án: cung cấp điều kiện thi hành án, đơn yêu cầu định giá lại tài sản; đơn kiến nghị, khiếu nại; ...', 12, 8.9::numeric, 8.9::numeric, 'Hàng ngày'),
    (31, 'QLKH-9.11', 'Tham gia quá trình thi hành án tại cơ quan Thi hành án có thẩm quyền như: Tham gia giải quyết theo giấy triệu tập; Tham gia các buổi cưỡng chế, kê biên tài sản; Tham gia quá trình bán đấu giá, cưỡng chế bàn giao tài sản; …', 12, 9.7::numeric, 9.7::numeric, 'Hàng ngày'),
    (32, 'QLKH-9.12', 'Phối hợp với Trụ sở chính tham gia các thủ tục tố tụng, phá sản, thi hành án đối với các khoản nợ chuyển giao về Trụ sở chính', 12, 9.4::numeric, 9.4::numeric, 'Hàng ngày'),
    (33, 'QLKH-9.13', 'Lập báo cáo xử lý tranh chấp theo định kỳ, đột xuất.', 12, 9.5::numeric, 9.5::numeric, 'Hàng ngày'),
    (34, 'QLKH-10', 'Trình HSC xóa nợ khi có yêu cầu', 13, 7.0::numeric, 7.0::numeric, 'Hàng năm'),
    (35, 'QLKH-10.1', 'Triển khai thủ tục xóa nợ sau khi có phê duyệt', 13, 6.7::numeric, 6.7::numeric, 'Hàng năm'),
    (36, 'QLKH-11', 'Các báo cáo định kỳ hoặc đột xuất khi có phân công', 14, 6.8::numeric, 6.8::numeric, 'Hàng ngày'),
    (37, 'QLKH-12', 'Xây dựng cơ chế, chính sách, đổi mới cải tiến quy trình, quy định', 15, 8.8::numeric, 8.8::numeric, 'Hàng quý/Hàng năm'),
    (38, 'QLKH-13', '(Đánh giá dựa trên kết quả của Lãnh đạo quản lý dự án/tổ/nhóm…)', 16, 8.0::numeric, 8.0::numeric, 'Hàng ngày'),
    (39, 'QLKH-14', 'Lưu trữ hồ sơ', 17, 7.0::numeric, 7.0::numeric, 'Hàng ngày'),
    (40, 'QLKH-15', 'Rà soát yêu cầu của đơn vị cần cung cấp, báo cáo lãnh đạoChi nhánh về nội dung cần cung cấp', 18, 8.8::numeric, 8.8::numeric, 'Hàng ngày')
  ) v(thu_tu, ma_cv, ten, ma_mang, diem_can_bo, diem_kiem_soat, tan_suat)
  join mang_cv mc on mc.department_id = v_qlkh and mc.ma_mang = v.ma_mang
  on conflict (ma_cv) do update set
    ten_cong_viec = excluded.ten_cong_viec, mang_cv_id = excluded.mang_cv_id,
    diem_can_bo = excluded.diem_can_bo, diem_kiem_soat = excluded.diem_kiem_soat,
    tan_suat = excluded.tan_suat, thu_tu = excluded.thu_tu, active = true;
end
$do$;

-- Màn Hôm nay: xếp việc theo thứ tự trong file (thu_tu) trước, rồi theo mã.
create or replace function get_today_screen(p_token uuid, p_ngay date default current_date) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_in_progress json;
  v_catalog json;
begin
  select coalesce(json_agg(row order by row.ngay_den_han), '[]'::json) into v_in_progress from (
    select
      dl.id as daily_log_id, jc.id as job_catalog_id, jc.ma_cv, jc.ten_cong_viec,
      dl.so_luong, dl.gia_tri_don_vi, dl.gia_tri_tong,
      dl.ngay_bat_dau, dl.ngay_den_han, dl.is_ghi_bu, dl.ghi_chu
    from daily_log dl join job_catalog jc on jc.id = dl.job_catalog_id
    where dl.employee_id = v_employee_id and dl.ngay_ket_thuc_thuc_te is null
  ) row;

  select coalesce(json_agg(row), '[]'::json) into v_catalog from (
    select
      jc.id as job_catalog_id, jc.ma_cv, mc.ten_mang as nhom_nv, mc.la_diem_thuong,
      jc.tan_suat as dinh_ky_tan_suat, jc.ten_cong_viec,
      coalesce(jc.diem_can_bo, 0) as gia_tri_cv,
      fin.id as log_id, fin.so_luong as finished_so_luong, fin.gia_tri_tong as finished_gia_tri_tong,
      fin.is_ghi_bu as finished_is_ghi_bu, fin.ghi_chu as finished_ghi_chu,
      (fin.id is not null) as done_today,
      coalesce(ip.cnt, 0) as in_progress_count,
      coalesce(ip.tong_sl, 0) as in_progress_so_luong
    from job_catalog jc
    join mang_cv mc on mc.id = jc.mang_cv_id
    join employee_mang_cv emc on emc.mang_cv_id = jc.mang_cv_id and emc.employee_id = v_employee_id
    left join daily_log fin
      on fin.job_catalog_id = jc.id and fin.employee_id = v_employee_id and fin.ngay_ket_thuc_thuc_te = p_ngay
    left join lateral (
      select count(*) as cnt, sum(op.so_luong) as tong_sl
      from daily_log op
      where op.job_catalog_id = jc.id and op.employee_id = v_employee_id and op.ngay_ket_thuc_thuc_te is null
    ) ip on true
    where jc.active
    order by mc.ma_mang, jc.thu_tu nulls last, jc.ma_cv
  ) row;

  return json_build_object('ngay', p_ngay, 'in_progress', v_in_progress, 'catalog', v_catalog);
end;
$$;

-- Tổng quan phòng (Trưởng phòng): CHỈ tính nhân sự cùng phòng với người xem.
create or replace function get_month_overview(
  p_token uuid,
  p_nam int default extract(year from current_date)::int,
  p_thang int default extract(month from current_date)::int
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_role text;
  v_dept uuid;
  v_by_week json;
  v_by_nhan_su json;
  v_tong_viec int;
  v_dung_han int;
  v_qua_han int;
  v_tong_gia_tri numeric;
  v_diem_thuong numeric;
begin
  select app_role, department_id into v_role, v_dept from employees where id = v_employee_id;
  if v_role <> 'truong_phong' then
    raise exception 'Chỉ Trưởng phòng mới xem được màn tổng quan này.';
  end if;

  select
    count(*),
    count(*) filter (where dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han),
    count(*) filter (where dl.ngay_ket_thuc_thuc_te > dl.ngay_den_han),
    coalesce(sum(dl.gia_tri_tong) filter (where not mc.la_diem_thuong), 0),
    coalesce(sum(dl.gia_tri_tong) filter (where mc.la_diem_thuong), 0)
  into v_tong_viec, v_dung_han, v_qua_han, v_tong_gia_tri, v_diem_thuong
  from daily_log dl
  join employees e on e.id = dl.employee_id and e.department_id is not distinct from v_dept
  join job_catalog jc on jc.id = dl.job_catalog_id
  join mang_cv mc on mc.id = jc.mang_cv_id
  where dl.ngay_ket_thuc_thuc_te is not null
    and extract(year from dl.ngay_ket_thuc_thuc_te) = p_nam
    and extract(month from dl.ngay_ket_thuc_thuc_te) = p_thang;

  select coalesce(json_agg(row order by row.tuan), '[]'::json) into v_by_week from (
    select
      ((extract(day from dl.ngay_ket_thuc_thuc_te)::int - 1) / 7) + 1 as tuan,
      count(*) filter (where dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han) as dung_han,
      count(*) filter (where dl.ngay_ket_thuc_thuc_te > dl.ngay_den_han) as qua_han
    from daily_log dl
    join employees e on e.id = dl.employee_id and e.department_id is not distinct from v_dept
    where dl.ngay_ket_thuc_thuc_te is not null
      and extract(year from dl.ngay_ket_thuc_thuc_te) = p_nam
      and extract(month from dl.ngay_ket_thuc_thuc_te) = p_thang
    group by 1
  ) row;

  select coalesce(json_agg(row order by row.gia_tri desc, row.ho_ten), '[]'::json) into v_by_nhan_su from (
    select
      e.ho_ten, e.ma_cbnv,
      count(dl.id) as so_viec,
      count(dl.id) filter (where dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han) as dung_han,
      count(dl.id) filter (where dl.ngay_ket_thuc_thuc_te > dl.ngay_den_han) as qua_han,
      coalesce(sum(dl.gia_tri_tong) filter (where not mc.la_diem_thuong), 0) as gia_tri,
      coalesce(sum(dl.gia_tri_tong) filter (where mc.la_diem_thuong), 0) as diem_thuong
    from employees e
    left join daily_log dl on dl.employee_id = e.id and dl.ngay_ket_thuc_thuc_te is not null
      and extract(year from dl.ngay_ket_thuc_thuc_te) = p_nam
      and extract(month from dl.ngay_ket_thuc_thuc_te) = p_thang
    left join job_catalog jc on jc.id = dl.job_catalog_id
    left join mang_cv mc on mc.id = jc.mang_cv_id
    where e.active and e.department_id is not distinct from v_dept
    group by e.id, e.ho_ten, e.ma_cbnv
  ) row;

  return json_build_object(
    'nam', p_nam, 'thang', p_thang,
    'tong_viec', v_tong_viec, 'dung_han', v_dung_han, 'qua_han', v_qua_han,
    'tong_gia_tri', v_tong_gia_tri, 'diem_thuong', v_diem_thuong,
    'theo_tuan', v_by_week,
    'theo_can_bo', v_by_nhan_su
  );
end;
$$;

-- KIỂM TRA SAU KHI CHẠY (chỉ đọc). Mong đợi: QLKH = 18 mảng, 40 việc, 3 nhân sự; QLNB giữ nguyên.
select d.ma_phong,
  (select count(*) from mang_cv m where m.department_id = d.id) as so_mang,
  (select count(*) from job_catalog j join mang_cv m on m.id = j.mang_cv_id where m.department_id = d.id and j.active) as so_viec_dang_dung,
  (select count(*) from employees e where e.department_id = d.id and e.active) as so_nhan_su
from departments d order by d.ma_phong;
