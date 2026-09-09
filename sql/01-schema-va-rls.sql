-- ============================================================================
-- SỔ KPI QLNB — SCHEMA KHỞI TẠO (chạy 1 lần trong Supabase SQL Editor)
-- Phòng Quản lý nội bộ, Chi nhánh Tràng Tiền — BIDV
-- ============================================================================
-- Giữ nguyên phương pháp gốc trong bộ Excel "Nền tảng đo lường năng suất và
-- chấm KPI Quý": Giá trị CV = (a)x0.4 + (b)x0.5 + (c)x0.1; KPI quý = Tài chính
-- 10% + Quy trình 70% (Tiến độ 25% + Chất lượng 30% + Số lượng 15%) +
-- Khách hàng nội bộ 15% + Học hỏi&Phát triển 5% ± điểm cộng/trừ.
--
-- MÔ HÌNH ĐĂNG NHẬP: tự xây bảng tài khoản riêng (accounts), KHÔNG dùng
-- Supabase Auth. Vì vậy Postgres không tự biết "ai đang gọi" (không có
-- auth.uid()) — toàn bộ dữ liệu bị KHOÁ CỨNG với người dùng thường (REVOKE),
-- chỉ truy cập được qua các hàm RPC (security definer) tự kiểm tra "vé"
-- (login_sessions.token) rồi mới cho đọc/ghi. Đây là ranh giới bảo mật duy
-- nhất của hệ thống — mọi RPC mới thêm sau này đều phải theo đúng khuôn này.
-- ============================================================================

create extension if not exists pgcrypto; -- cho gen_random_uuid() và crypt()/gen_salt() băm mật khẩu

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
-- 2. EMPLOYEES — thay Sheet '1_Danh sach CBNV'. Không còn cột nối sang
--    auth.users (không dùng Supabase Auth) — tài khoản đăng nhập nằm ở bảng
--    accounts riêng, nối qua employee_id.
-- ---------------------------------------------------------------------------
create table employees (
  id                      uuid primary key default gen_random_uuid(),
  ma_cbnv                 text unique not null,
  ho_ten                  text not null,
  chuc_danh               text,
  department_id           uuid references departments(id),
  nhom_nghiep_vu          text,              -- TCHC / TCKT / KHTH ...
  quan_ly_truc_tiep_id    uuid references employees(id),
  app_role                text not null default 'canbo'
                          check (app_role in ('canbo','pho_truong_phong','truong_phong','ban_giam_doc')),
  kpi_phu_luc             text,              -- vd 'KPI-CNH-QLNB2 (Chuyên viên TCNS)'
  active                  boolean not null default true,
  created_at              timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. ACCOUNTS — tài khoản đăng nhập, mã CBNV + mật khẩu (đã băm bằng
--    pgcrypto's crypt()/blowfish — KHÔNG BAO GIỜ lưu mật khẩu thô hay có thể
--    đảo ngược lại). Khoá tạm 15 phút sau 5 lần sai liên tiếp.
-- ---------------------------------------------------------------------------
create table accounts (
  id                      uuid primary key default gen_random_uuid(),
  employee_id             uuid not null unique references employees(id) on delete cascade,
  mat_khau_hash           text not null,
  must_change_password    boolean not null default true,
  failed_attempts         int not null default 0,
  locked_until            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 4. LOGIN_SESSIONS — "vé" cấp sau khi đăng nhập đúng. App lưu token này
--    (localStorage) và gửi kèm mọi lệnh gọi RPC tiếp theo.
-- ---------------------------------------------------------------------------
create table login_sessions (
  token         uuid primary key default gen_random_uuid(),
  employee_id   uuid not null references employees(id) on delete cascade,
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default (now() + interval '30 days'),
  revoked       boolean not null default false
);

create index idx_login_sessions_employee on login_sessions (employee_id) where not revoked;

-- ---------------------------------------------------------------------------
-- 5. JOB_CATALOG — thay Sheet '2_Danh muc CV'. Mỗi cán bộ một danh mục riêng,
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
-- 6. DAILY_LOG — thay Sheet '3_Nhat ky CV ngay'. Mỗi lượt tích = 1 dòng.
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
-- 7. KPI_QUARTER — thay Sheet '4_Tong hop Quy' + '5_Cham KPI Quy'.
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
-- 8. SATISFACTION_SURVEY — thay Sheet '6_Mau do SHL'.
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
-- KHOÁ CỨNG MỌI BẢNG — không cấp quyền gì cho anon/authenticated. Đây là điểm
-- khác biệt quan trọng nhất so với dùng Supabase Auth: vì không có auth.uid(),
-- Row Level Security không có gì để đối chiếu, nên phải chặn truy cập bảng
-- trực tiếp hoàn toàn và bắt buộc đi qua RPC. RLS bên dưới bật thêm cho chắc
-- (phòng khi lỡ tay cấp quyền lại sau này), nhưng REVOKE mới là lớp chặn thật.
-- ============================================================================

revoke all on departments, employees, accounts, login_sessions, job_catalog, daily_log, kpi_quarter, satisfaction_survey
  from anon, authenticated;

alter table departments enable row level security;
alter table employees enable row level security;
alter table accounts enable row level security;
alter table login_sessions enable row level security;
alter table job_catalog enable row level security;
alter table daily_log enable row level security;
alter table kpi_quarter enable row level security;
alter table satisfaction_survey enable row level security;
-- Không tạo policy nào cả — RLS bật + không có policy = từ chối mọi truy vấn.
-- Chỉ các hàm "security definer" bên dưới (chạy với quyền chủ sở hữu, bỏ qua
-- RLS) mới đọc/ghi được các bảng này.

-- ============================================================================
-- VIEWS — cộng dồn tự động (thay công thức SUMIFS trong Excel). Views KHÔNG
-- được cấp quyền trực tiếp (theo REVOKE ở trên) — các RPC đọc dữ liệu quý sẽ
-- SELECT từ view này ở bên trong, client không SELECT thẳng được.
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

-- ⚠️ NGƯỠNG XẾP LOẠI DƯỚI ĐÂY LÀ ƯỚC LƯỢNG — chỉ có 1 ví dụ thực tế đối chiếu được
-- (94.9 điểm → "Hoàn thành tốt" trong file ANHNTN13). CẦN đối chiếu lại đúng
-- ngưỡng chính thức trong Phụ lục KPI-CNH-QLNB gốc của BIDV trước khi dùng thật.
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
-- PHIÊN ĐĂNG NHẬP — hàm phụ trợ đọc "ai đang gọi" từ token, thay cho auth.uid().
-- Mọi RPC nghiệp vụ khác (thêm sau, khi dựng từng màn) đều bắt đầu bằng
-- perform set_config('app.employee_id', session_employee_id(p_token)::text, true);
-- rồi mới gọi các hàm my_role()/is_manager_of() bên dưới — y hệt cách dùng
-- auth.uid() kiểu cũ, chỉ đổi nguồn.
-- ============================================================================

create or replace function session_employee_id(p_token uuid) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_employee_id uuid;
begin
  select employee_id into v_employee_id from login_sessions
  where token = p_token and not revoked and expires_at > now();
  if v_employee_id is null then
    raise exception 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn — vui lòng đăng nhập lại.';
  end if;
  return v_employee_id;
end;
$$;

create or replace function my_employee_id() returns uuid
language sql stable as $$
  select nullif(current_setting('app.employee_id', true), '')::uuid;
$$;

create or replace function my_role() returns text
language sql stable security definer set search_path = public as $$
  select app_role from employees where id = my_employee_id();
$$;

create or replace function my_department_id() returns uuid
language sql stable security definer set search_path = public as $$
  select department_id from employees where id = my_employee_id();
$$;

-- true nếu người đang đăng nhập (my_employee_id()) là quản lý trực tiếp CỦA
-- target, hoặc là Trưởng phòng của cùng phòng ban với target.
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
-- RPC: ĐĂNG NHẬP / ĐỔI MẬT KHẨU / ĐĂNG XUẤT — 3 hàm duy nhất được mở cho
-- người CHƯA đăng nhập (anon), vì phải gọi được trước khi có token.
-- ============================================================================

create or replace function login(p_ma_cbnv text, p_mat_khau text) returns json
language plpgsql security definer set search_path = public, extensions as $$
-- 'extensions' cần có trong search_path vì Supabase cài pgcrypto (crypt/gen_salt) ở đó, không phải 'public'.
declare
  v_employee employees;
  v_account  accounts;
  v_token    uuid;
begin
  select * into v_employee from employees where ma_cbnv = trim(p_ma_cbnv) and active;
  if v_employee.id is null then
    raise exception 'Sai mã CBNV hoặc mật khẩu.';
  end if;

  select * into v_account from accounts where employee_id = v_employee.id;
  if v_account.id is null then
    raise exception 'Tài khoản chưa được tạo — liên hệ Trưởng phòng.';
  end if;

  if v_account.locked_until is not null and v_account.locked_until > now() then
    raise exception 'Tài khoản tạm khoá do nhập sai nhiều lần — thử lại sau %.',
      to_char(v_account.locked_until, 'HH24:MI DD/MM');
  end if;

  if v_account.mat_khau_hash <> crypt(p_mat_khau, v_account.mat_khau_hash) then
    update accounts set
      failed_attempts = failed_attempts + 1,
      locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
    where id = v_account.id;
    raise exception 'Sai mã CBNV hoặc mật khẩu.';
  end if;

  update accounts set failed_attempts = 0, locked_until = null, updated_at = now() where id = v_account.id;

  insert into login_sessions (employee_id) values (v_employee.id) returning token into v_token;

  return json_build_object(
    'token', v_token,
    'employee_id', v_employee.id,
    'ma_cbnv', v_employee.ma_cbnv,
    'ho_ten', v_employee.ho_ten,
    'app_role', v_employee.app_role,
    'department_id', v_employee.department_id,
    'must_change_password', v_account.must_change_password
  );
end;
$$;

create or replace function doi_mat_khau(p_token uuid, p_mat_khau_cu text, p_mat_khau_moi text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_hash text;
begin
  select mat_khau_hash into v_hash from accounts where employee_id = v_employee_id;
  if v_hash <> crypt(p_mat_khau_cu, v_hash) then
    raise exception 'Mật khẩu hiện tại không đúng.';
  end if;
  if length(p_mat_khau_moi) < 6 then
    raise exception 'Mật khẩu mới phải có ít nhất 6 ký tự.';
  end if;
  update accounts set
    mat_khau_hash = crypt(p_mat_khau_moi, gen_salt('bf')),
    must_change_password = false,
    updated_at = now()
  where employee_id = v_employee_id;
end;
$$;

create or replace function logout(p_token uuid) returns void
language sql security definer set search_path = public as $$
  update login_sessions set revoked = true where token = p_token;
$$;

grant execute on function login(text, text) to anon;
grant execute on function doi_mat_khau(uuid, text, text) to anon;
grant execute on function logout(uuid) to anon;

-- ============================================================================
-- TRIGGER: chặn sửa/ghi bù nhật ký của một quý đã bị Trưởng phòng khoá, và
-- chặn người không phải Trưởng phòng tự đổi is_locked. Đọc "ai đang thao tác"
-- qua my_role()/my_employee_id() ở trên — các RPC ghi dữ liệu (thêm ở bước
-- dựng từng màn) phải set_config('app.employee_id', ...) trước khi INSERT/UPDATE.
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
  -- QUAN TRỌNG: 'new' luôn NULL khi trigger chạy cho DELETE — trả thẳng 'new'
  -- trong trường hợp đó khiến Postgres ÂM THẦM HUỶ lệnh xoá (không báo lỗi).
  -- Phải trả coalesce(new, old) để DELETE vẫn thực hiện bình thường.
  return coalesce(new, old);
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
