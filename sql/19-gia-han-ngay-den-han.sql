-- ============================================================================
-- Gia hạn Ngày đến hạn (nhiều lần) cho công việc CHƯA kết thúc — mỗi lần kéo
-- dài Hạn so với giá trị hiện tại BẮT BUỘC nhập Lý do, lưu lại thành lịch sử.
-- Khi Duyệt điểm, lãnh đạo xem được toàn bộ lịch sử gia hạn của việc đó (nếu
-- có) để cân nhắc khi chấm điểm Tiến độ — điểm mặc định vẫn tự tính theo
-- đúng/trễ so với Hạn (đã gia hạn) như cũ, lãnh đạo tự sửa lại nếu thấy gia
-- hạn không hợp lý (đã có sẵn cơ chế sửa điểm khi duyệt).
-- Rút ngắn Hạn (không phải gia hạn) hoặc sửa Ngày bắt đầu/Ghi chú vẫn KHÔNG
-- cần lý do, giữ nguyên như trước.
-- ============================================================================

create table daily_log_gia_han (
  id             uuid primary key default gen_random_uuid(),
  daily_log_id   uuid not null references daily_log(id) on delete cascade,
  han_cu         date not null,
  han_moi        date not null,
  ly_do          text not null,
  created_by     uuid references employees(id),
  created_at     timestamptz not null default now()
);

alter table daily_log_gia_han enable row level security;
revoke all on daily_log_gia_han from anon, authenticated;

create index idx_dlgh_daily_log on daily_log_gia_han (daily_log_id);

-- Dọn các bản cũ của start_task/update_task_progress: mỗi lần trước đây
-- thêm tham số mới, "create or replace" KHÔNG thay thế bản cũ (khác số
-- lượng tham số = hàm khác trong Postgres) — để lại nhiều overload cùng
-- tên, có thể gây lỗi "function is not unique" khi gọi. Xoá sạch các chữ
-- ký cũ đã biết trước khi tạo lại bản mới nhất, đảm bảo chỉ còn đúng 1 bản.
drop function if exists start_task(uuid, uuid, date, date, int);
drop function if exists update_task_progress(uuid, uuid, int, date, date);
drop function if exists update_task_progress(uuid, uuid, int, date, date, text);

create or replace function update_task_progress(
  p_token uuid, p_daily_log_id uuid,
  p_so_luong int default null,
  p_ngay_bat_dau date default null,
  p_ngay_den_han date default null,
  p_ghi_chu text default null,
  p_ly_do_gia_han text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_log daily_log;
  v_han_moi date;
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

  v_han_moi := coalesce(p_ngay_den_han, v_log.ngay_den_han);

  if v_han_moi > v_log.ngay_den_han then
    if p_ly_do_gia_han is null or trim(p_ly_do_gia_han) = '' then
      raise exception 'Cần nhập Lý do khi gia hạn (kéo dài Hạn).';
    end if;
    insert into daily_log_gia_han (daily_log_id, han_cu, han_moi, ly_do, created_by)
    values (p_daily_log_id, v_log.ngay_den_han, v_han_moi, trim(p_ly_do_gia_han), v_employee_id);
  end if;

  update daily_log set
    so_luong = coalesce(p_so_luong, so_luong),
    ngay_bat_dau = coalesce(p_ngay_bat_dau, ngay_bat_dau),
    ngay_den_han = v_han_moi,
    ghi_chu = coalesce(nullif(trim(p_ghi_chu), ''), ghi_chu),
    updated_at = now()
  where id = p_daily_log_id;
end;
$$;

-- get_pending_reviews: kèm lịch sử gia hạn (nếu có) của mỗi việc để lãnh đạo xem khi duyệt.
create or replace function get_pending_reviews(p_token uuid) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_items json;
begin
  select coalesce(json_agg(row order by row.ngay_ket_thuc_thuc_te desc), '[]'::json) into v_items from (
    select
      p.id as participant_id, p.cap, p.diem_toi_da, p.diem_tien_do, p.diem_chat_luong,
      dl.so_luong, dl.ngay_bat_dau, dl.ngay_den_han, dl.ngay_ket_thuc_thuc_te,
      dl.ghi_chu, dl.is_ghi_bu,
      jc.ma_cv, jc.ten_cong_viec,
      e.ho_ten as nguoi_thuc_hien, e.ma_cbnv as ma_cbnv_thuc_hien,
      coalesce(gh.lich_su, '[]'::json) as lich_su_gia_han
    from daily_log_participants p
    join daily_log dl on dl.id = p.daily_log_id
    join job_catalog jc on jc.id = dl.job_catalog_id
    join employees e on e.id = dl.employee_id
    left join lateral (
      select json_agg(json_build_object(
        'han_cu', g.han_cu, 'han_moi', g.han_moi, 'ly_do', g.ly_do, 'luc', g.created_at
      ) order by g.created_at) as lich_su
      from daily_log_gia_han g
      where g.daily_log_id = dl.id
    ) gh on true
    where p.employee_id = v_employee_id and not p.da_duyet
  ) row;
  return json_build_object('items', v_items);
end;
$$;

grant execute on function update_task_progress(uuid, uuid, int, date, date, text, text) to anon;
