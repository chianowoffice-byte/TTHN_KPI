-- ============================================================================
-- CẤP PGĐ/GĐ — CHỈ PHÊ DUYỆT, KHÔNG TÍNH ĐIỂM. Khác với Kiểm soát/Trưởng
-- phòng (điểm của họ CÓ cộng vào KPI cá nhân), PGĐ/GĐ chỉ đóng vai trò
-- "cửa duyệt" cho một số việc quan trọng — có/không duyệt, không có điểm
-- Tiến độ/Chất lượng nào được tính.
--
-- Hiện chưa có việc nào trong danh mục 444 việc cần tới cấp này (chỉ có Cán
-- bộ + Kiểm soát), và cũng chưa có ai giữ vai trò PGĐ/GĐ — phần dưới đây CHỈ
-- có tác dụng khi cả 2 điều kiện đó xuất hiện sau này (an toàn, không đổi gì
-- ở hiện tại).
-- ============================================================================

-- Thêm 2 vai trò pho_giam_doc/giam_doc vào hệ thống phân quyền — thay cho
-- placeholder 'ban_giam_doc' cũ chưa dùng tới.
alter table employees drop constraint if exists employees_app_role_check;
alter table employees add constraint employees_app_role_check
  check (app_role in ('canbo', 'pho_truong_phong', 'truong_phong', 'pho_giam_doc', 'giam_doc'));

-- ---------------------------------------------------------------------------
-- finish_task — thêm 2 nhánh tạo lượt DUYỆT (không phải CHẤM ĐIỂM) cho PGĐ/GĐ
-- khi job_catalog có khai diem_pgd/diem_gd. diem_toi_da vẫn lưu lại để tham
-- khảo mức độ quan trọng của việc, nhưng diem_tien_do/diem_chat_luong để
-- NULL — không tự tính, không cộng vào KPI ai cả.
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
  v_pgd_id uuid;
  v_gd_id uuid;
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

  -- Cấp Kiểm soát: quản lý trực tiếp của người làm, nếu đang là Phó/Trưởng phòng. Có tính điểm.
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

  -- Cấp Trưởng phòng: Trưởng phòng cùng phòng với người làm. Có tính điểm.
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

  -- Cấp PGĐ: CHỈ phê duyệt — diem_tien_do/diem_chat_luong để NULL, không tính điểm.
  if v_catalog.diem_pgd is not null then
    select id into v_pgd_id from employees where app_role = 'pho_giam_doc' limit 1;
    if v_pgd_id is not null then
      insert into daily_log_participants (daily_log_id, cap, employee_id, diem_toi_da)
      values (p_daily_log_id, 'pgd', v_pgd_id, v_catalog.diem_pgd)
      on conflict (daily_log_id, cap) do nothing;
    end if;
  end if;

  -- Cấp GĐ: CHỈ phê duyệt — diem_tien_do/diem_chat_luong để NULL, không tính điểm.
  if v_catalog.diem_gd is not null then
    select id into v_gd_id from employees where app_role = 'giam_doc' limit 1;
    if v_gd_id is not null then
      insert into daily_log_participants (daily_log_id, cap, employee_id, diem_toi_da)
      values (p_daily_log_id, 'gd', v_gd_id, v_catalog.diem_gd)
      on conflict (daily_log_id, cap) do nothing;
    end if;
  end if;

  return json_build_object('diem_tien_do', v_diem_tien_do, 'dung_han', v_dung_han);
end;
$$;

-- ---------------------------------------------------------------------------
-- duyet_diem — với cấp pgd/gd, KHÔNG cho sửa điểm (chỉ đánh dấu đã duyệt),
-- kể cả khi client lỡ gửi kèm điểm.
-- ---------------------------------------------------------------------------
create or replace function duyet_diem(
  p_token uuid, p_participant_id uuid,
  p_diem_tien_do numeric default null,
  p_diem_chat_luong numeric default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_part daily_log_participants;
  v_la_cap_diem boolean;
begin
  select * into v_part from daily_log_participants
  where id = p_participant_id and employee_id = v_employee_id and not da_duyet;
  if v_part.id is null then
    raise exception 'Không tìm thấy mục cần duyệt này.';
  end if;

  v_la_cap_diem := v_part.cap in ('kiem_soat', 'truong_phong');

  if v_la_cap_diem then
    if p_diem_tien_do is not null and p_diem_tien_do > v_part.diem_toi_da then
      raise exception 'Điểm Tiến độ không được vượt quá %.', v_part.diem_toi_da;
    end if;
    if p_diem_chat_luong is not null and p_diem_chat_luong > v_part.diem_toi_da then
      raise exception 'Điểm Chất lượng không được vượt quá %.', v_part.diem_toi_da;
    end if;
  end if;

  update daily_log_participants set
    diem_tien_do = case when v_la_cap_diem then coalesce(p_diem_tien_do, diem_tien_do) else null end,
    diem_chat_luong = case when v_la_cap_diem then coalesce(p_diem_chat_luong, diem_chat_luong) else null end,
    da_duyet = true,
    duyet_luc = now()
  where id = p_participant_id;
end;
$$;
