-- ============================================================================
-- MÀN "DUYỆT ĐIỂM" — Phó/Trưởng phòng chấm điểm cấp Kiểm soát/Trưởng phòng khi
-- cán bộ Kết thúc 1 việc có khai điểm ở cấp đó trong job_catalog.
--
-- Người duyệt tự suy ra (đúng nguyên tắc đã thống nhất — không khai báo tay):
--   • Kiểm soát  = quản lý trực tiếp (quan_ly_truc_tiep_id) của người làm,
--     NẾU người đó đang giữ vai trò Phó/Trưởng phòng.
--   • Trưởng phòng = người giữ app_role='truong_phong' cùng phòng với người làm.
--   • PGĐ/GĐ: CHƯA xử lý ở bước này — chưa có ai giữ 2 vai trò đó trong hệ
--     thống; bổ sung sau khi có người thật (chỉ cần thêm nhánh insert tương tự).
-- ============================================================================

create table if not exists daily_log_participants (
  id             uuid primary key default gen_random_uuid(),
  daily_log_id   uuid not null references daily_log(id) on delete cascade,
  cap            text not null check (cap in ('kiem_soat','truong_phong','pgd','gd')),
  employee_id    uuid not null references employees(id),
  diem_toi_da    numeric(6,2) not null,   -- = job_catalog.diem_<cap> tại thời điểm Kết thúc (chốt)
  diem_tien_do   numeric(6,2),            -- mặc định tự tính giống cấp Cán bộ (đúng hạn/trễ hạn), sửa được khi duyệt
  diem_chat_luong numeric(6,2),           -- mặc định = diem_toi_da, sửa được khi duyệt
  da_duyet       boolean not null default false,
  duyet_luc      timestamptz,
  created_at     timestamptz not null default now(),
  unique (daily_log_id, cap),
  check (diem_tien_do is null or diem_tien_do <= diem_toi_da),
  check (diem_chat_luong is null or diem_chat_luong <= diem_toi_da)
);

create index idx_dlp_employee_pending on daily_log_participants (employee_id) where not da_duyet;

alter table daily_log_participants enable row level security;
revoke all on daily_log_participants from anon, authenticated;

-- ---------------------------------------------------------------------------
-- finish_task — thêm bước tự tạo lượt chờ duyệt cho Kiểm soát/Trưởng phòng.
-- ---------------------------------------------------------------------------
create or replace function finish_task(
  p_token uuid, p_daily_log_id uuid,
  p_ngay_ket_thuc date default current_date
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_log daily_log;
  v_catalog job_catalog;
  v_diem_tien_do numeric(6,2);
  v_dung_han boolean;
  v_manager_id uuid;
  v_manager_role text;
  v_doer_dept uuid;
  v_tp_id uuid;
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  select * into v_log from daily_log
  where id = p_daily_log_id and employee_id = v_employee_id and ngay_ket_thuc_thuc_te is null;
  if v_log.id is null then
    raise exception 'Không tìm thấy lượt thực hiện đang mở này.';
  end if;

  select * into v_catalog from job_catalog where id = v_log.job_catalog_id;

  v_dung_han := p_ngay_ket_thuc <= v_log.ngay_den_han;
  v_diem_tien_do := case when v_dung_han then v_log.gia_tri_tong else 0 end;

  update daily_log set
    ngay_ket_thuc_thuc_te = p_ngay_ket_thuc,
    diem_tien_do = v_diem_tien_do,
    diem_chat_luong = v_log.gia_tri_tong,
    updated_at = now()
  where id = p_daily_log_id;

  -- Cấp Kiểm soát: quản lý trực tiếp của người làm, nếu đang là Phó/Trưởng phòng.
  if v_catalog.diem_kiem_soat is not null then
    select quan_ly_truc_tiep_id into v_manager_id from employees where id = v_employee_id;
    if v_manager_id is not null then
      select app_role into v_manager_role from employees where id = v_manager_id;
      if v_manager_role in ('pho_truong_phong', 'truong_phong') then
        insert into daily_log_participants (daily_log_id, cap, employee_id, diem_toi_da, diem_tien_do, diem_chat_luong)
        values (
          p_daily_log_id, 'kiem_soat', v_manager_id, v_catalog.diem_kiem_soat,
          case when v_dung_han then v_catalog.diem_kiem_soat else 0 end,
          v_catalog.diem_kiem_soat
        )
        on conflict (daily_log_id, cap) do nothing;
      end if;
    end if;
  end if;

  -- Cấp Trưởng phòng: Trưởng phòng cùng phòng với người làm.
  if v_catalog.diem_truong_phong is not null then
    select department_id into v_doer_dept from employees where id = v_employee_id;
    select id into v_tp_id from employees where department_id = v_doer_dept and app_role = 'truong_phong' limit 1;
    if v_tp_id is not null then
      insert into daily_log_participants (daily_log_id, cap, employee_id, diem_toi_da, diem_tien_do, diem_chat_luong)
      values (
        p_daily_log_id, 'truong_phong', v_tp_id, v_catalog.diem_truong_phong,
        case when v_dung_han then v_catalog.diem_truong_phong else 0 end,
        v_catalog.diem_truong_phong
      )
      on conflict (daily_log_id, cap) do nothing;
    end if;
  end if;

  return json_build_object('diem_tien_do', v_diem_tien_do, 'dung_han', v_dung_han);
end;
$$;

-- ---------------------------------------------------------------------------
-- unfinish_task — bỏ tích Kết thúc thì xoá luôn các lượt chờ duyệt phát sinh
-- (kể cả đã duyệt rồi — coi như huỷ toàn bộ, làm lại từ đầu nếu Kết thúc lại).
-- ---------------------------------------------------------------------------
create or replace function unfinish_task(p_token uuid, p_daily_log_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  delete from daily_log_participants where daily_log_id = p_daily_log_id;

  update daily_log set
    ngay_ket_thuc_thuc_te = null, diem_tien_do = null, diem_chat_luong = null, updated_at = now()
  where id = p_daily_log_id and employee_id = v_employee_id;
  if not found then
    raise exception 'Không tìm thấy lượt thực hiện này.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC màn Duyệt điểm.
-- ---------------------------------------------------------------------------
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
      jc.ma_cv, jc.ten_cong_viec,
      e.ho_ten as nguoi_thuc_hien, e.ma_cbnv as ma_cbnv_thuc_hien
    from daily_log_participants p
    join daily_log dl on dl.id = p.daily_log_id
    join job_catalog jc on jc.id = dl.job_catalog_id
    join employees e on e.id = dl.employee_id
    where p.employee_id = v_employee_id and not p.da_duyet
  ) row;
  return json_build_object('items', v_items);
end;
$$;

create or replace function duyet_diem(
  p_token uuid, p_participant_id uuid,
  p_diem_tien_do numeric default null,
  p_diem_chat_luong numeric default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_part daily_log_participants;
begin
  select * into v_part from daily_log_participants
  where id = p_participant_id and employee_id = v_employee_id and not da_duyet;
  if v_part.id is null then
    raise exception 'Không tìm thấy mục cần duyệt này.';
  end if;
  if p_diem_tien_do is not null and p_diem_tien_do > v_part.diem_toi_da then
    raise exception 'Điểm Tiến độ không được vượt quá %.', v_part.diem_toi_da;
  end if;
  if p_diem_chat_luong is not null and p_diem_chat_luong > v_part.diem_toi_da then
    raise exception 'Điểm Chất lượng không được vượt quá %.', v_part.diem_toi_da;
  end if;

  update daily_log_participants set
    diem_tien_do = coalesce(p_diem_tien_do, diem_tien_do),
    diem_chat_luong = coalesce(p_diem_chat_luong, diem_chat_luong),
    da_duyet = true,
    duyet_luc = now()
  where id = p_participant_id;
end;
$$;

grant execute on function get_pending_reviews(uuid) to anon;
grant execute on function duyet_diem(uuid, uuid, numeric, numeric) to anon;
