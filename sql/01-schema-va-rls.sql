-- ============================================================================
-- SỔ KPI QLNB — SCHEMA KHỞI TẠO (chạy 1 lần trong Supabase SQL Editor)
-- Phòng Quản lý nội bộ, Chi nhánh Tràng Tiền — BIDV
-- ============================================================================
-- Giữ nguyên phương pháp gốc trong bộ Excel "Nền tảng đo lường năng suất và
-- chấm KPI Quý": Giá trị CV = (a)x0.4 + (b)x0.5 + (c)x0.1; KPI quý = Tài chính
-- 10% + Quy trình 70% (Tiến độ 25% + Chất lượng 30% + Số lượng 15%) +
-- Khách hàng nội bộ 15% + Học hỏi&Phát triển 5% ± điểm cộng/trừ.
-- ============================================================================

create extension if not exists pgcrypto; -- cho gen_random_uuid()

-- ---------------------------------------------------------------------------
-- 1. DEPARTMENTS — phòng ban. Giai đoạn 1 chỉ có QLNB, mở rộng bằng cách
--    thêm dòng, không đổi cấu trúc (phục vụ màn Ban Giám đốc xem toàn chi nhánh).
-- ---------------------------------------------------------------------------
create table departments (
  id          uuid primary key default gen_random_uuid(),
  ma_phong    text unique not null,
  ten_phong   text not null,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. EMPLOYEES — thay Sheet '1_Danh sach CBNV'.
--    auth_user_id nối sang auth.users sau khi tạo tài khoản đăng nhập (mã CBNV
--    + mật khẩu mặc định 123456, ghép email giả <ma_cbnv>@qlnb.noibo — xem
--    scripts/tao-tai-khoan-dang-nhap.mjs).
-- ---------------------------------------------------------------------------
create table employees (
  id                      uuid primary key default gen_random_uuid(),
  auth_user_id            uuid unique references auth.users(id),
  ma_cbnv                 text unique not null,
  ho_ten                  text not null,
  chuc_danh               text,
  department_id           uuid references departments(id),
  nhom_nghiep_vu          text,              -- TCHC / TCKT / KHTH ...
  quan_ly_truc_tiep_id    uuid references employees(id),
  app_role                text not null default 'canbo'
                          check (app_role in ('canbo','pho_truong_phong','truong_phong','ban_giam_doc')),
  kpi_phu_luc             text,              -- vd 'KPI-CNH-QLNB2 (Chuyên viên TCNS)'
  must_change_password    boolean not null default true,
  active                  boolean not null default true,
  created_at              timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. JOB_CATALOG — thay Sheet '2_Danh muc CV'. Mỗi cán bộ một danh mục riêng,
--    nhập 1 lần lúc triển khai, ít khi đổi. Giá trị CV tính tự động bằng cột
--    generated, đúng công thức gốc — không cho sai lệch tay.
-- ---------------------------------------------------------------------------
create table job_catalog (
  id                      uuid primary key default gen_random_uuid(),
  employee_id             uuid not null references employees(id) on delete cascade,
  ma_cv                   text not null,
  nhom_nv                 text,
  ten_cong_viec           text not null,
  dinh_ky_tan_suat        text,              -- 'Hàng ngày' / 'Hàng tháng' / 'Hàng quý' / 'Khi phát sinh' / '1 lần/năm' ...
  tieu_chi_tien_do        text,
  tieu_chi_chat_luong     text,
  pham_vi_anh_huong       numeric(5,1) not null check (pham_vi_anh_huong between 0 and 100), -- (a)
  muc_do_phuc_tap         numeric(5,1) not null check (muc_do_phuc_tap between 0 and 100),   -- (b)
  thoi_gian_thuc_hien     numeric(5,1) not null check (thoi_gian_thuc_hien between 0 and 100),-- (c)
  gia_tri_cv              numeric(6,2) generated always as
                            (round((pham_vi_anh_huong*0.4 + muc_do_phuc_tap*0.5 + thoi_gian_thuc_hien*0.1)::numeric, 2))
                            stored,
  active                  boolean not null default true,
  created_at              timestamptz not null default now(),
  unique (employee_id, ma_cv)
);

-- ---------------------------------------------------------------------------
-- 4. DAILY_LOG — thay Sheet '3_Nhat ky CV ngay'. Mỗi lượt tích = 1 dòng.
--    gia_tri_cv_snapshot chốt tại thời điểm ghi (không đổi ngược nếu sau này
--    job_catalog được sửa giá trị). is_ghi_bu tự tính để hiện nhãn minh bạch.
-- ---------------------------------------------------------------------------
create table daily_log (
  id                          uuid primary key default gen_random_uuid(),
  employee_id                 uuid not null references employees(id) on delete cascade,
  job_catalog_id               uuid not null references job_catalog(id),
  ngay_ghi_nhan                date not null default current_date,
  han_hoan_thanh                date,
  ngay_hoan_thanh_thuc_te      date not null default current_date,
  gia_tri_cv_snapshot          numeric(6,2) not null,
  diem_tien_do                 numeric(6,2),   -- lãnh đạo chấm; mặc định phía app = gia_tri_cv_snapshot nếu đúng hạn
  diem_chat_luong              numeric(6,2),
  ghi_chu                      text,
  is_ghi_bu                    boolean generated always as
                                  (abs(ngay_ghi_nhan - ngay_hoan_thanh_thuc_te) > 2) stored,
  created_by                   uuid references employees(id),
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),
  check (diem_tien_do is null or diem_tien_do <= gia_tri_cv_snapshot),
  check (diem_chat_luong is null or diem_chat_luong <= gia_tri_cv_snapshot)
);

create index idx_daily_log_employee_date on daily_log (employee_id, ngay_hoan_thanh_thuc_te);

-- ---------------------------------------------------------------------------
-- 5. KPI_QUARTER — thay Sheet '4_Tong hop Quy' + '5_Cham KPI Quy'.
--    so_cv_ke_hoach + 4 chỉ tiêu còn lại nhập tay cuối quý; %Tiến độ/%Chất
--    lượng/%Số lượng cộng dồn tự động từ daily_log qua view v_kpi_quarter.
-- ---------------------------------------------------------------------------
create table kpi_quarter (
  id                          uuid primary key default gen_random_uuid(),
  employee_id                 uuid not null references employees(id) on delete cascade,
  nam                          int not null,
  quy                          int not null check (quy between 1 and 4),
  so_cv_ke_hoach               int,
  diem_tai_chinh               numeric(5,1),   -- theo BSC Phòng
  diem_khach_hang_noi_bo       numeric(5,1),   -- theo Mẫu đo SHL
  diem_hoc_hoi_phat_trien      numeric(5,1),
  diem_cong                    numeric(5,1) not null default 0 check (diem_cong between 0 and 10),
  diem_tru                     numeric(5,1) not null default 0 check (diem_tru between 0 and 10),
  is_locked                    boolean not null default false,
  locked_at                    timestamptz,
  locked_by                    uuid references employees(id),
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),
  unique (employee_id, nam, quy)
);

-- ---------------------------------------------------------------------------
-- 6. SATISFACTION_SURVEY — thay Sheet '6_Mau do SHL'.
-- ---------------------------------------------------------------------------
create table satisfaction_survey (
  id                              uuid primary key default gen_random_uuid(),
  employee_id                     uuid not null references employees(id) on delete cascade, -- người được đánh giá
  nam                              int not null,
  quy                              int not null check (quy between 1 and 4),
  nguoi_danh_gia                   text,          -- tên phòng / cán bộ đánh giá
  diem_chat_luong_phoi_hop         numeric(5,1) check (diem_chat_luong_phoi_hop between 0 and 100),
  diem_tien_do_phoi_hop            numeric(5,1) check (diem_tien_do_phoi_hop between 0 and 100),
  diem_thai_do_phoi_hop            numeric(5,1) check (diem_thai_do_phoi_hop between 0 and 100),
  created_at                       timestamptz not null default now()
);

-- ============================================================================
-- VIEWS — cộng dồn tự động (thay công thức SUMIFS trong Excel)
-- ============================================================================

create or replace view v_quarter_progress as
select
  employee_id,
  extract(year from ngay_hoan_thanh_thuc_te)::int as nam,
  ceil(extract(month from ngay_hoan_thanh_thuc_te)::int / 3.0)::int as quy,
  sum(gia_tri_cv_snapshot)                         as tong_gia_tri_giao,
  sum(coalesce(diem_tien_do, 0))                   as tong_diem_tien_do,
  sum(coalesce(diem_chat_luong, 0))                as tong_diem_chat_luong,
  count(*)                                          as so_cv_thuc_hien
from daily_log
group by employee_id, nam, quy;

create or replace view v_kpi_quarter as
select
  k.*,
  coalesce(p.tong_gia_tri_giao, 0)  as tong_gia_tri_giao,
  coalesce(p.so_cv_thuc_hien, 0)    as so_cv_thuc_hien,
  case when p.tong_gia_tri_giao > 0
       then round(p.tong_diem_tien_do   / p.tong_gia_tri_giao * 100, 1) end as pct_tien_do,
  case when p.tong_gia_tri_giao > 0
       then round(p.tong_diem_chat_luong / p.tong_gia_tri_giao * 100, 1) end as pct_chat_luong,
  case when k.so_cv_ke_hoach > 0
       then least(round(p.so_cv_thuc_hien::numeric / k.so_cv_ke_hoach * 100, 1), 100) end as pct_so_luong
from kpi_quarter k
left join v_quarter_progress p
  on p.employee_id = k.employee_id and p.nam = k.nam and p.quy = k.quy;

-- Điểm KPI quý theo đúng cơ cấu trọng số (Tài chính 10% + Quy trình 70% + KH nội bộ 15% + Học hỏi&PT 5%).
-- ⚠️ NGƯỠNG XẾP LOẠI DƯỚI ĐÂY LÀ ƯỚC LƯỢNG — chỉ có 1 ví dụ thực tế đối chiếu được
-- (94.9 điểm → "Hoàn thành tốt" trong file ANHNTN13). CẦN đối chiếu lại đúng
-- ngưỡng chính thức trong Phụ lục KPI-CNH-QLNB gốc của BIDV trước khi dùng thật,
-- rồi sửa trực tiếp trong CASE WHEN bên dưới.
create or replace view v_kpi_quarter_score as
select
  q.*,
  round(
    coalesce(q.diem_tai_chinh, 0) * 0.10
    + coalesce(q.pct_tien_do, 0) * 0.25
    + coalesce(q.pct_chat_luong, 0) * 0.30
    + coalesce(q.pct_so_luong, 0) * 0.15
    + coalesce(q.diem_khach_hang_noi_bo, 0) * 0.15
    + coalesce(q.diem_hoc_hoi_phat_trien, 0) * 0.05
  , 1) as diem_kpi_a,
  round(
    coalesce(q.diem_tai_chinh, 0) * 0.10
    + coalesce(q.pct_tien_do, 0) * 0.25
    + coalesce(q.pct_chat_luong, 0) * 0.30
    + coalesce(q.pct_so_luong, 0) * 0.15
    + coalesce(q.diem_khach_hang_noi_bo, 0) * 0.15
    + coalesce(q.diem_hoc_hoi_phat_trien, 0) * 0.05
    + q.diem_cong - q.diem_tru
  , 1) as tong_diem_kpi_quy
from v_kpi_quarter q;

-- Màn Ban Giám đốc: tổng hợp hàng ngày theo phòng.
create or replace view v_daily_department_summary as
select
  d.id                                          as department_id,
  d.ten_phong,
  current_date                                  as ngay,
  count(distinct e.id)                          as tong_can_bo,
  count(distinct l.employee_id)                 as so_can_bo_da_ghi_nhan,
  coalesce(sum(l.gia_tri_cv_snapshot), 0)       as gia_tri_hoan_thanh_hom_nay
from departments d
left join employees e on e.department_id = d.id and e.active
left join daily_log l on l.employee_id = e.id and l.ngay_hoan_thanh_thuc_te = current_date
group by d.id, d.ten_phong;

-- ============================================================================
-- HÀM PHỤ TRỢ (security definer) — tránh đệ quy RLS khi 1 policy cần tra cứu
-- lại chính bảng employees (ai đang đăng nhập, vai trò gì, quản lý ai).
-- ============================================================================

create or replace function my_employee_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from employees where auth_user_id = auth.uid();
$$;

create or replace function my_role() returns text
language sql stable security definer set search_path = public as $$
  select app_role from employees where auth_user_id = auth.uid();
$$;

create or replace function my_department_id() returns uuid
language sql stable security definer set search_path = public as $$
  select department_id from employees where auth_user_id = auth.uid();
$$;

-- true nếu người đang đăng nhập là quản lý trực tiếp CỦA target, hoặc là
-- Trưởng phòng của cùng phòng ban với target.
create or replace function is_manager_of(target_employee_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from employees e
    where e.id = target_employee_id
      and (
        e.quan_ly_truc_tiep_id = my_employee_id()
        or (my_role() = 'truong_phong' and e.department_id = my_department_id())
      )
  );
$$;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

alter table departments enable row level security;
alter table employees enable row level security;
alter table job_catalog enable row level security;
alter table daily_log enable row level security;
alter table kpi_quarter enable row level security;
alter table satisfaction_survey enable row level security;

-- DEPARTMENTS: mọi người đã đăng nhập đều xem được danh sách phòng (cần cho
-- màn Ban Giám đốc và cho combobox chọn phòng khi tạo cán bộ mới).
create policy departments_select on departments for select
  using (auth.role() = 'authenticated');

-- EMPLOYEES
create policy employees_select on employees for select
  using (
    auth_user_id = auth.uid()
    or is_manager_of(id)
    or my_role() = 'ban_giam_doc'
  );

create policy employees_update_self_password_flag on employees for update
  using (auth_user_id = auth.uid())
  with check (auth_user_id = auth.uid());

-- JOB_CATALOG
create policy job_catalog_select on job_catalog for select
  using (
    employee_id = my_employee_id()
    or is_manager_of(employee_id)
    or my_role() = 'ban_giam_doc'
  );

create policy job_catalog_write on job_catalog for all
  using (my_role() in ('truong_phong','pho_truong_phong'))
  with check (my_role() in ('truong_phong','pho_truong_phong'));

-- DAILY_LOG
create policy daily_log_select on daily_log for select
  using (
    employee_id = my_employee_id()
    or is_manager_of(employee_id)
    or my_role() = 'ban_giam_doc'
  );

-- Cán bộ tự tích việc của mình; lãnh đạo có thể ghi hộ cấp dưới.
create policy daily_log_insert on daily_log for insert
  with check (
    employee_id = my_employee_id()
    or is_manager_of(employee_id)
  );

-- Sửa/ghi bù: chủ nhật ký hoặc quản lý trực tiếp — trigger bên dưới còn chặn
-- thêm nếu quý đã bị Trưởng phòng khoá.
create policy daily_log_update on daily_log for update
  using (employee_id = my_employee_id() or is_manager_of(employee_id))
  with check (employee_id = my_employee_id() or is_manager_of(employee_id));

create policy daily_log_delete on daily_log for delete
  using (employee_id = my_employee_id() or is_manager_of(employee_id));

-- KPI_QUARTER
create policy kpi_quarter_select on kpi_quarter for select
  using (
    employee_id = my_employee_id()
    or is_manager_of(employee_id)
    or my_role() = 'ban_giam_doc'
  );

create policy kpi_quarter_write on kpi_quarter for all
  using (is_manager_of(employee_id) or my_role() = 'truong_phong')
  with check (is_manager_of(employee_id) or my_role() = 'truong_phong');

-- SATISFACTION_SURVEY
create policy satisfaction_select on satisfaction_survey for select
  using (
    employee_id = my_employee_id()
    or is_manager_of(employee_id)
    or my_role() = 'ban_giam_doc'
  );

create policy satisfaction_write on satisfaction_survey for all
  using (is_manager_of(employee_id) or my_role() = 'truong_phong')
  with check (is_manager_of(employee_id) or my_role() = 'truong_phong');

-- ============================================================================
-- TRIGGER: chặn sửa/ghi bù nhật ký của một quý đã bị Trưởng phòng khoá, và
-- chặn người không phải Trưởng phòng tự đổi is_locked.
-- ============================================================================

create or replace function fn_check_quarter_lock() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_nam int;
  v_quy int;
  v_locked boolean;
begin
  v_nam := extract(year from coalesce(new.ngay_hoan_thanh_thuc_te, old.ngay_hoan_thanh_thuc_te))::int;
  v_quy := ceil(extract(month from coalesce(new.ngay_hoan_thanh_thuc_te, old.ngay_hoan_thanh_thuc_te))::int / 3.0)::int;

  select is_locked into v_locked from kpi_quarter
  where employee_id = coalesce(new.employee_id, old.employee_id) and nam = v_nam and quy = v_quy;

  if v_locked and my_role() <> 'truong_phong' then
    raise exception 'Quý %/% của cán bộ này đã được Trưởng phòng chốt — chỉ Trưởng phòng mới sửa được.', v_quy, v_nam;
  end if;
  return new;
end;
$$;

create trigger trg_check_quarter_lock
  before insert or update or delete on daily_log
  for each row execute function fn_check_quarter_lock();

create or replace function fn_only_truong_phong_locks() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.is_locked is distinct from old.is_locked) and my_role() <> 'truong_phong' then
    raise exception 'Chỉ Trưởng phòng mới được chốt/mở khoá quý.';
  end if;
  if (new.is_locked is distinct from old.is_locked) and new.is_locked then
    new.locked_at := now();
    new.locked_by := my_employee_id();
  end if;
  return new;
end;
$$;

create trigger trg_only_truong_phong_locks
  before update on kpi_quarter
  for each row execute function fn_only_truong_phong_locks();
