-- ============================================================================
-- ĐỔI SANG DANH MỤC CÔNG VIỆC "CHUẨN" THEO MẢNG (thay cho danh mục cũ riêng
-- từng cán bộ). Theo dữ liệu chuẩn mới: mỗi việc thuộc 1 trong 8 Mảng CV, có
-- điểm RIÊNG cho từng cấp (Cán bộ/Kiểm soát/Trưởng phòng/PGĐ/GĐ) — không còn
-- dùng chung 1 "Giá trị CV" như thiết kế cũ. Cán bộ thấy đúng những việc
-- thuộc (các) mảng mình được phân công (bảng employee_mang_cv), không còn
-- danh mục "của riêng từng người" nữa.
--
-- job_catalog và daily_log CHƯA có dữ liệu thật (chỉ có dữ liệu test đã dọn
-- sạch mỗi lần) — làm lại 2 bảng này từ đầu cho gọn, không ALTER từng cột.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. MẢNG CÔNG VIỆC — 8 mảng cố định của Phòng QLNB.
-- ---------------------------------------------------------------------------
create table if not exists mang_cv (
  id          uuid primary key default gen_random_uuid(),
  ma_mang     int unique not null,
  ten_mang    text not null,
  created_at  timestamptz not null default now()
);

insert into mang_cv (ma_mang, ten_mang) values
  (1, 'TỔ CHỨC – NHÂN SỰ'),
  (2, 'HÀNH CHÍNH – VĂN PHÒNG'),
  (3, 'KẾ HOẠCH – TỔNG HỢP'),
  (4, 'TÀI CHÍNH – KẾ TOÁN'),
  (5, 'CÔNG NGHỆ THÔNG TIN'),
  (6, 'TẠP VỤ'),
  (7, 'HOẠT ĐỘNG ĐOÀN THỂ'),
  (8, 'KHÁC')
on conflict (ma_mang) do update set ten_mang = excluded.ten_mang;

-- ---------------------------------------------------------------------------
-- 2. EMPLOYEE_MANG_CV — cán bộ nào được phân công (các) mảng nào (1 người có
--    thể thuộc nhiều mảng cùng lúc, đúng theo yêu cầu).
-- ---------------------------------------------------------------------------
create table if not exists employee_mang_cv (
  employee_id  uuid not null references employees(id) on delete cascade,
  mang_cv_id   uuid not null references mang_cv(id) on delete cascade,
  primary key (employee_id, mang_cv_id)
);

alter table employee_mang_cv enable row level security;
revoke all on employee_mang_cv from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. JOB_CATALOG — làm lại: bỏ employee_id + công thức (a)(b)(c) cũ, thay
--    bằng mang_cv_id + điểm riêng từng cấp (NULL = cấp đó không tham gia việc
--    này). diem_can_bo là điểm cán bộ trực tiếp làm nhận được.
-- ---------------------------------------------------------------------------
drop table if exists daily_log cascade;   -- phải xoá trước vì có khoá ngoại tới job_catalog
drop table if exists job_catalog cascade;

create table job_catalog (
  id                    uuid primary key default gen_random_uuid(),
  ma_cv                 text unique not null,
  ten_cong_viec         text not null,
  mang_cv_id            uuid not null references mang_cv(id),
  diem_can_bo           numeric(6,2),
  diem_kiem_soat        numeric(6,2),
  diem_truong_phong     numeric(6,2),
  diem_pgd              numeric(6,2),
  diem_gd               numeric(6,2),
  active                boolean not null default true,
  created_at            timestamptz not null default now()
);

alter table job_catalog enable row level security;
revoke all on job_catalog from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. DAILY_LOG — giữ nguyên cấu trúc vòng đời Bắt đầu/Kết thúc đã có, chỉ đổi
--    nguồn "Giá trị đơn vị" sang job_catalog.diem_can_bo (điểm cấp Cán bộ).
--    Điểm các cấp Kiểm soát/TP/PGĐ/GĐ CHƯA tính ở bước này (để làm ở màn
--    "Duyệt điểm" sau) — daily_log hiện vẫn chỉ ghi nhận đúng phần việc của
--    người trực tiếp làm, như đang chạy.
-- ---------------------------------------------------------------------------
create table daily_log (
  id                          uuid primary key default gen_random_uuid(),
  employee_id                 uuid not null references employees(id) on delete cascade,
  job_catalog_id               uuid not null references job_catalog(id),

  so_luong                    int not null default 1 check (so_luong > 0),
  gia_tri_don_vi               numeric(6,2) not null,  -- = job_catalog.diem_can_bo tại thời điểm Bắt đầu
  gia_tri_tong                 numeric(6,2) generated always as (round(so_luong * gia_tri_don_vi, 2)) stored,

  ngay_ghi_nhan                 date not null default current_date,
  ngay_bat_dau                  date not null default current_date,
  ngay_den_han                  date not null default current_date,
  ngay_ket_thuc_thuc_te          date,

  diem_tien_do                   numeric(6,2),
  diem_chat_luong                numeric(6,2),

  ghi_chu                        text,
  is_ghi_bu                      boolean generated always as (abs(ngay_ghi_nhan - ngay_bat_dau) > 2) stored,

  created_by                     uuid references employees(id),
  created_at                     timestamptz not null default now(),
  updated_at                     timestamptz not null default now(),

  check (ngay_ket_thuc_thuc_te is null or diem_tien_do is not null),
  check (diem_chat_luong is null or diem_chat_luong <= gia_tri_tong)
);

create index idx_daily_log_employee_open on daily_log (employee_id) where ngay_ket_thuc_thuc_te is null;
create index idx_daily_log_employee_finish on daily_log (employee_id, ngay_ket_thuc_thuc_te);
create unique index uq_daily_log_one_open_per_task
  on daily_log (employee_id, job_catalog_id)
  where ngay_ket_thuc_thuc_te is null;

alter table daily_log enable row level security;
revoke all on daily_log from anon, authenticated;

create trigger trg_check_quarter_lock
  before insert or update or delete on daily_log
  for each row execute function fn_check_quarter_lock();

-- ---------------------------------------------------------------------------
-- 5. Views phụ thuộc daily_log/job_catalog — dựng lại (bị cascade-drop ở trên).
-- ---------------------------------------------------------------------------
create or replace view v_quarter_progress as
select
  employee_id,
  extract(year from ngay_ket_thuc_thuc_te)::int as nam,
  ceil(extract(month from ngay_ket_thuc_thuc_te)::int / 3.0)::int as quy,
  sum(gia_tri_tong)                                as tong_gia_tri_giao,
  sum(coalesce(diem_tien_do, 0))                   as tong_diem_tien_do,
  sum(coalesce(diem_chat_luong, 0))                as tong_diem_chat_luong,
  count(*)                                          as so_cv_thuc_hien
from daily_log
where ngay_ket_thuc_thuc_te is not null
group by employee_id, nam, quy;

create or replace view v_daily_department_summary as
select
  d.id                                          as department_id,
  d.ten_phong,
  current_date                                  as ngay,
  count(distinct e.id)                          as tong_can_bo,
  count(distinct l.employee_id)                 as so_can_bo_da_ghi_nhan,
  coalesce(sum(l.gia_tri_tong), 0)              as gia_tri_hoan_thanh_hom_nay
from departments d
left join employees e on e.department_id = d.id and e.active
left join daily_log l on l.employee_id = e.id and l.ngay_ket_thuc_thuc_te = current_date
group by d.id, d.ten_phong;

-- ============================================================================
-- 6. RPC — cập nhật lại theo cấu trúc mới. Giữ NGUYÊN tên hàm + hình dạng JSON
-- trả về (client không cần sửa gì) — chỉ đổi nguồn dữ liệu bên trong:
--   • "Danh mục của tôi" giờ = mọi job_catalog thuộc (các) mảng tôi được phân
--     công (qua employee_mang_cv), thay vì job_catalog.employee_id = tôi.
--   • item.nhom_nv trả về TÊN MẢNG (mang_cv.ten_mang).
--   • item.dinh_ky_tan_suat trả về NULL (dữ liệu chuẩn mới không có cột này —
--     màn "Hôm nay" tự ẩn nhóm "Việc hàng ngày"/chip Tần suất khi không có).
--   • item.gia_tri_cv trả về job_catalog.diem_can_bo.
-- ============================================================================

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
      dl.ngay_bat_dau, dl.ngay_den_han, dl.is_ghi_bu
    from daily_log dl join job_catalog jc on jc.id = dl.job_catalog_id
    where dl.employee_id = v_employee_id and dl.ngay_ket_thuc_thuc_te is null
  ) row;

  select coalesce(json_agg(row), '[]'::json) into v_catalog from (
    select
      jc.id as job_catalog_id, jc.ma_cv, mc.ten_mang as nhom_nv,
      null::text as dinh_ky_tan_suat, jc.ten_cong_viec,
      coalesce(jc.diem_can_bo, 0) as gia_tri_cv,
      fin.id as log_id, fin.so_luong as finished_so_luong, fin.gia_tri_tong as finished_gia_tri_tong,
      fin.is_ghi_bu as finished_is_ghi_bu,
      (fin.id is not null) as done_today
    from job_catalog jc
    join mang_cv mc on mc.id = jc.mang_cv_id
    join employee_mang_cv emc on emc.mang_cv_id = jc.mang_cv_id and emc.employee_id = v_employee_id
    left join daily_log fin
      on fin.job_catalog_id = jc.id and fin.employee_id = v_employee_id and fin.ngay_ket_thuc_thuc_te = p_ngay
    where jc.active
      and not exists (
        select 1 from daily_log op
        where op.job_catalog_id = jc.id and op.employee_id = v_employee_id and op.ngay_ket_thuc_thuc_te is null
      )
    order by mc.ma_mang, jc.ma_cv
  ) row;

  return json_build_object('ngay', p_ngay, 'in_progress', v_in_progress, 'catalog', v_catalog);
end;
$$;

-- start_task: nguồn giá trị đơn vị đổi sang job_catalog.diem_can_bo (coalesce 0
-- cho vài việc chỉ có cấp Kiểm soát trở lên, chưa có điểm Cán bộ trong dữ liệu
-- chuẩn). Kiểm tra thêm: chỉ bắt đầu được việc thuộc mảng mình được phân công.
create or replace function start_task(
  p_token uuid, p_job_catalog_id uuid,
  p_ngay_bat_dau date default current_date,
  p_ngay_den_han date default current_date,
  p_so_luong int default 1
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_catalog job_catalog;
  v_id uuid;
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  select jc.* into v_catalog from job_catalog jc
  join employee_mang_cv emc on emc.mang_cv_id = jc.mang_cv_id and emc.employee_id = v_employee_id
  where jc.id = p_job_catalog_id and jc.active;
  if v_catalog.id is null then
    raise exception 'Không tìm thấy công việc này trong (các) mảng bạn được phân công.';
  end if;
  if p_ngay_bat_dau > current_date then
    raise exception 'Ngày bắt đầu không được ở tương lai.';
  end if;
  if p_so_luong < 1 then
    raise exception 'Số lượng phải từ 1 trở lên.';
  end if;

  insert into daily_log
    (employee_id, job_catalog_id, so_luong, gia_tri_don_vi, ngay_bat_dau, ngay_den_han, created_by)
  values
    (v_employee_id, p_job_catalog_id, p_so_luong, coalesce(v_catalog.diem_can_bo, 0), p_ngay_bat_dau, p_ngay_den_han, v_employee_id)
  returning id into v_id;

  return json_build_object('daily_log_id', v_id);
exception
  when unique_violation then
    raise exception 'Việc này đang có 1 lượt thực hiện chưa kết thúc — kết thúc hoặc huỷ lượt đó trước.';
end;
$$;

grant execute on function get_today_screen(uuid, date) to anon;
grant execute on function start_task(uuid, uuid, date, date, int) to anon;
-- update_task_progress / finish_task / unfinish_task / cancel_task không đổi
-- (đã grant từ trước, không phụ thuộc cấu trúc job_catalog).
