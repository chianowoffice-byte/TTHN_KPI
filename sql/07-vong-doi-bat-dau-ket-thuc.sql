-- ============================================================================
-- VÒNG ĐỜI CÔNG VIỆC 2 BƯỚC: BẮT ĐẦU → KẾT THÚC
-- Thay cho cơ chế "tích 1 phát = xong" — mỗi công việc giờ có: Số lượng
-- (mặc định 1, nhân thẳng vào điểm), Ngày bắt đầu (đổi được thành quá khứ để
-- ghi bù), Ngày đến hạn (mặc định hôm nay, đổi được thành tương lai), Ngày
-- kết thúc (chỉ có khi đã bấm Kết thúc). Kết thúc trễ hạn → Điểm Tiến độ = 0
-- tự động (không phải lãnh đạo hạ tay).
--
-- daily_log chưa có dữ liệu thật (chỉ có dữ liệu test đã dọn sạch) — làm lại
-- bảng này từ đầu cho gọn thay vì ALTER/RENAME nhiều bước dễ sót.
-- ============================================================================

drop table if exists daily_log cascade;

create table daily_log (
  id                        uuid primary key default gen_random_uuid(),
  employee_id               uuid not null references employees(id) on delete cascade,
  job_catalog_id            uuid not null references job_catalog(id),

  so_luong                  int not null default 1 check (so_luong > 0),
  gia_tri_don_vi            numeric(6,2) not null,     -- = job_catalog.gia_tri_cv tại thời điểm Bắt đầu (chốt, không đổi ngược sau)
  gia_tri_tong              numeric(6,2) generated always as (round(so_luong * gia_tri_don_vi, 2)) stored,

  ngay_ghi_nhan             date not null default current_date,  -- ngày thao tác Bắt đầu thật sự diễn ra (để tính is_ghi_bu)
  ngay_bat_dau              date not null default current_date,  -- có thể chỉnh lùi về quá khứ để ghi bù
  ngay_den_han              date not null default current_date,  -- có thể chỉnh tới tương lai
  ngay_ket_thuc_thuc_te     date,                                -- NULL = đang thực hiện, chưa xong

  diem_tien_do              numeric(6,2),  -- chỉ có giá trị sau khi Kết thúc: <=hạn giữ nguyên gia_tri_tong, >hạn = 0 (tự động)
  diem_chat_luong           numeric(6,2),  -- mặc định = gia_tri_tong khi Kết thúc, lãnh đạo sửa sau (màn Duyệt điểm, chưa dựng)

  ghi_chu                   text,
  is_ghi_bu                 boolean generated always as (abs(ngay_ghi_nhan - ngay_bat_dau) > 2) stored,

  created_by                uuid references employees(id),
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),

  check (ngay_ket_thuc_thuc_te is null or diem_tien_do is not null),
  check (diem_chat_luong is null or diem_chat_luong <= gia_tri_tong)
);

create index idx_daily_log_employee_open on daily_log (employee_id) where ngay_ket_thuc_thuc_te is null;
create index idx_daily_log_employee_finish on daily_log (employee_id, ngay_ket_thuc_thuc_te);

-- Chỉ 1 lượt "đang thực hiện" tại một thời điểm cho cùng 1 việc — tránh bấm
-- Bắt đầu nhiều lần chồng nhau cho cùng 1 đầu việc.
create unique index uq_daily_log_one_open_per_task
  on daily_log (employee_id, job_catalog_id)
  where ngay_ket_thuc_thuc_te is null;

-- ---------------------------------------------------------------------------
-- Trigger khoá quý — cập nhật lại theo cột mới (ngay_ket_thuc_thuc_te có thể
-- NULL khi đang thực hiện, dùng ngay_bat_dau làm mốc quý trong trường hợp đó).
-- ---------------------------------------------------------------------------
create or replace function fn_check_quarter_lock() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_moc date;
  v_nam int;
  v_quy int;
  v_locked boolean;
begin
  v_moc := coalesce(new.ngay_ket_thuc_thuc_te, new.ngay_bat_dau, old.ngay_ket_thuc_thuc_te, old.ngay_bat_dau);
  v_nam := extract(year from v_moc)::int;
  v_quy := ceil(extract(month from v_moc)::int / 3.0)::int;

  select is_locked into v_locked from kpi_quarter
  where employee_id = coalesce(new.employee_id, old.employee_id) and nam = v_nam and quy = v_quy;

  if v_locked and my_role() <> 'truong_phong' then
    raise exception 'Quý %/% của cán bộ này đã được Trưởng phòng chốt — chỉ Trưởng phòng mới sửa được.', v_quy, v_nam;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger trg_check_quarter_lock
  before insert or update or delete on daily_log
  for each row execute function fn_check_quarter_lock();

-- ---------------------------------------------------------------------------
-- Views — cập nhật lại theo tên cột mới.
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
where ngay_ket_thuc_thuc_te is not null  -- chỉ tính việc đã thực sự kết thúc
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
-- RPC — thay toggle_today_task bằng 5 hàm theo đúng vòng đời Bắt đầu/Kết thúc.
-- ============================================================================

drop function if exists toggle_today_task(uuid, uuid, date);

-- Bắt đầu 1 việc. Mặc định Số lượng=1, Ngày bắt đầu/Ngày đến hạn=hôm nay —
-- cán bộ chỉnh lại sau trong thẻ "Đang thực hiện" nếu cần (không bắt gõ ngay).
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

  select * into v_catalog from job_catalog
  where id = p_job_catalog_id and employee_id = v_employee_id and active;
  if v_catalog.id is null then
    raise exception 'Không tìm thấy công việc này.';
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
    (v_employee_id, p_job_catalog_id, p_so_luong, v_catalog.gia_tri_cv, p_ngay_bat_dau, p_ngay_den_han, v_employee_id)
  returning id into v_id;

  return json_build_object('daily_log_id', v_id);
exception
  when unique_violation then
    raise exception 'Việc này đang có 1 lượt thực hiện chưa kết thúc — kết thúc hoặc huỷ lượt đó trước.';
end;
$$;

-- Sửa Số lượng / Ngày bắt đầu / Ngày đến hạn của 1 lượt đang thực hiện.
create or replace function update_task_progress(
  p_token uuid, p_daily_log_id uuid,
  p_so_luong int default null,
  p_ngay_bat_dau date default null,
  p_ngay_den_han date default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_log daily_log;
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  select * into v_log from daily_log
  where id = p_daily_log_id and employee_id = v_employee_id and ngay_ket_thuc_thuc_te is null;
  if v_log.id is null then
    raise exception 'Không tìm thấy lượt thực hiện đang mở này.';
  end if;
  if p_ngay_bat_dau is not null and p_ngay_bat_dau > current_date then
    raise exception 'Ngày bắt đầu không được ở tương lai.';
  end if;
  if p_so_luong is not null and p_so_luong < 1 then
    raise exception 'Số lượng phải từ 1 trở lên.';
  end if;

  update daily_log set
    so_luong = coalesce(p_so_luong, so_luong),
    ngay_bat_dau = coalesce(p_ngay_bat_dau, ngay_bat_dau),
    ngay_den_han = coalesce(p_ngay_den_han, ngay_den_han),
    updated_at = now()
  where id = p_daily_log_id;
end;
$$;

-- Kết thúc 1 việc — tự tính Điểm Tiến độ theo đúng hạn/trễ hạn.
create or replace function finish_task(
  p_token uuid, p_daily_log_id uuid,
  p_ngay_ket_thuc date default current_date
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_log daily_log;
  v_diem_tien_do numeric(6,2);
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  select * into v_log from daily_log
  where id = p_daily_log_id and employee_id = v_employee_id and ngay_ket_thuc_thuc_te is null;
  if v_log.id is null then
    raise exception 'Không tìm thấy lượt thực hiện đang mở này.';
  end if;

  v_diem_tien_do := case when p_ngay_ket_thuc <= v_log.ngay_den_han then v_log.gia_tri_tong else 0 end;

  update daily_log set
    ngay_ket_thuc_thuc_te = p_ngay_ket_thuc,
    diem_tien_do = v_diem_tien_do,
    diem_chat_luong = v_log.gia_tri_tong,
    updated_at = now()
  where id = p_daily_log_id;

  return json_build_object('diem_tien_do', v_diem_tien_do, 'dung_han', p_ngay_ket_thuc <= v_log.ngay_den_han);
end;
$$;

-- Bỏ tích Kết thúc (tích nhầm) — quay lại trạng thái đang thực hiện.
create or replace function unfinish_task(p_token uuid, p_daily_log_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  update daily_log set
    ngay_ket_thuc_thuc_te = null, diem_tien_do = null, diem_chat_luong = null, updated_at = now()
  where id = p_daily_log_id and employee_id = v_employee_id;
  if not found then
    raise exception 'Không tìm thấy lượt thực hiện này.';
  end if;
end;
$$;

-- Huỷ hẳn 1 lượt Bắt đầu — CHỈ khi chưa Kết thúc (phải unfinish_task trước
-- nếu đã kết thúc), đúng theo yêu cầu tránh xoá nhầm dữ liệu đã hoàn thành.
create or replace function cancel_task(p_token uuid, p_daily_log_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  delete from daily_log
  where id = p_daily_log_id and employee_id = v_employee_id and ngay_ket_thuc_thuc_te is null;
  if not found then
    raise exception 'Chỉ huỷ được lượt đang thực hiện — việc đã Kết thúc phải bỏ tích Kết thúc trước.';
  end if;
end;
$$;

-- Màn "Hôm nay": tách 2 khối — đang thực hiện (mọi ngày, chưa kết thúc) và
-- danh mục còn lại (chưa có lượt nào mở), kèm cờ đã-kết-thúc-hôm-nay.
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
      jc.id as job_catalog_id, jc.ma_cv, jc.nhom_nv, jc.ten_cong_viec, jc.dinh_ky_tan_suat, jc.gia_tri_cv,
      fin.id as log_id, fin.so_luong as finished_so_luong, fin.gia_tri_tong as finished_gia_tri_tong,
      fin.is_ghi_bu as finished_is_ghi_bu,
      (fin.id is not null) as done_today
    from job_catalog jc
    left join daily_log fin
      on fin.job_catalog_id = jc.id and fin.employee_id = v_employee_id and fin.ngay_ket_thuc_thuc_te = p_ngay
    where jc.employee_id = v_employee_id and jc.active
      and not exists (
        select 1 from daily_log op
        where op.job_catalog_id = jc.id and op.employee_id = v_employee_id and op.ngay_ket_thuc_thuc_te is null
      )
    order by (jc.dinh_ky_tan_suat ilike '%ngày%') desc, jc.nhom_nv, jc.ma_cv
  ) row;

  return json_build_object('ngay', p_ngay, 'in_progress', v_in_progress, 'catalog', v_catalog);
end;
$$;

grant execute on function start_task(uuid, uuid, date, date, int) to anon;
grant execute on function update_task_progress(uuid, uuid, int, date, date) to anon;
grant execute on function finish_task(uuid, uuid, date) to anon;
grant execute on function unfinish_task(uuid, uuid) to anon;
grant execute on function cancel_task(uuid, uuid) to anon;
grant execute on function get_today_screen(uuid, date) to anon;
