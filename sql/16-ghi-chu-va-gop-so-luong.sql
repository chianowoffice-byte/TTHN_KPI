-- ============================================================================
-- 1) Ghi chú chi tiết — start_task/update_task_progress nhận thêm p_ghi_chu.
-- 2) Gộp số lượng khi làm lại đúng việc đó trong ngày: Kết thúc 1 lượt mà đã
--    có 1 lượt KHÁC của cùng việc, cùng Ngày bắt đầu + Ngày kết thúc (Ngày
--    đến hạn không cần trùng) và đã Kết thúc từ trước → cộng dồn Số lượng +
--    nối thêm Ghi chú vào lượt cũ, xoá lượt vừa Kết thúc (không tạo dòng
--    mới, không tạo lại lượt duyệt Kiểm soát/Trưởng phòng — lượt cũ giữ
--    nguyên trạng thái đã/chưa duyệt).
-- ============================================================================

create or replace function start_task(
  p_token uuid, p_job_catalog_id uuid,
  p_ngay_bat_dau date default current_date,
  p_ngay_den_han date default current_date,
  p_so_luong int default 1,
  p_ghi_chu text default null
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
    (employee_id, job_catalog_id, so_luong, gia_tri_don_vi, ngay_bat_dau, ngay_den_han, ghi_chu, created_by)
  values
    (v_employee_id, p_job_catalog_id, p_so_luong, coalesce(v_catalog.diem_can_bo, 0), p_ngay_bat_dau, p_ngay_den_han, nullif(trim(p_ghi_chu), ''), v_employee_id)
  returning id into v_id;

  return json_build_object('daily_log_id', v_id);
exception
  when unique_violation then
    raise exception 'Việc này đang có 1 lượt thực hiện chưa kết thúc — kết thúc hoặc huỷ lượt đó trước.';
end;
$$;

create or replace function update_task_progress(
  p_token uuid, p_daily_log_id uuid,
  p_so_luong int default null,
  p_ngay_bat_dau date default null,
  p_ngay_den_han date default null,
  p_ghi_chu text default null
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
    ghi_chu = coalesce(nullif(trim(p_ghi_chu), ''), ghi_chu),
    updated_at = now()
  where id = p_daily_log_id;
end;
$$;

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
  v_existing daily_log;
  v_merged_so_luong int;
  v_merged_gia_tri_tong numeric(6,2);
  v_merged_ghi_chu text;
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  select * into v_log from daily_log
  where id = p_daily_log_id and employee_id = v_employee_id and ngay_ket_thuc_thuc_te is null;
  if v_log.id is null then
    raise exception 'Không tìm thấy lượt thực hiện đang mở này.';
  end if;

  select * into v_catalog from job_catalog where id = v_log.job_catalog_id;

  -- Có lượt KHÁC của cùng việc, cùng Ngày bắt đầu + Ngày kết thúc, đã Kết
  -- thúc từ trước? Nếu có, gộp vào đó thay vì tạo thêm 1 lượt đã kết thúc.
  select * into v_existing from daily_log
  where employee_id = v_employee_id and job_catalog_id = v_log.job_catalog_id
    and ngay_bat_dau = v_log.ngay_bat_dau and ngay_ket_thuc_thuc_te = p_ngay_ket_thuc
    and id <> p_daily_log_id;

  if v_existing.id is not null then
    v_merged_so_luong := v_existing.so_luong + v_log.so_luong;
    v_merged_gia_tri_tong := round(v_merged_so_luong * v_existing.gia_tri_don_vi, 2);
    v_merged_ghi_chu := trim(both E'\n' from
      coalesce(v_existing.ghi_chu, '') ||
      case when v_existing.ghi_chu is not null and v_log.ghi_chu is not null then E'\n---\n' else '' end ||
      coalesce(v_log.ghi_chu, '')
    );
    v_dung_han := v_existing.ngay_ket_thuc_thuc_te <= v_existing.ngay_den_han;

    update daily_log set
      so_luong = v_merged_so_luong,
      ghi_chu = nullif(v_merged_ghi_chu, ''),
      diem_tien_do = case when v_dung_han then v_merged_gia_tri_tong else 0 end,
      diem_chat_luong = v_merged_gia_tri_tong,
      updated_at = now()
    where id = v_existing.id;

    delete from daily_log where id = p_daily_log_id;

    return json_build_object(
      'diem_tien_do', case when v_dung_han then v_merged_gia_tri_tong else 0 end,
      'dung_han', v_dung_han,
      'da_gop', true,
      'so_luong_gop', v_merged_so_luong
    );
  end if;

  -- Không có lượt nào để gộp — xử lý như bình thường.
  v_dung_han := p_ngay_ket_thuc <= v_log.ngay_den_han;
  v_diem_tien_do := case when v_dung_han then v_log.gia_tri_tong else 0 end;

  update daily_log set
    ngay_ket_thuc_thuc_te = p_ngay_ket_thuc,
    diem_tien_do = v_diem_tien_do,
    diem_chat_luong = v_log.gia_tri_tong,
    updated_at = now()
  where id = p_daily_log_id;

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

  if v_catalog.diem_pgd is not null then
    select id into v_pgd_id from employees where app_role = 'pho_giam_doc' limit 1;
    if v_pgd_id is not null then
      insert into daily_log_participants (daily_log_id, cap, employee_id, diem_toi_da)
      values (p_daily_log_id, 'pgd', v_pgd_id, v_catalog.diem_pgd)
      on conflict (daily_log_id, cap) do nothing;
    end if;
  end if;

  if v_catalog.diem_gd is not null then
    select id into v_gd_id from employees where app_role = 'giam_doc' limit 1;
    if v_gd_id is not null then
      insert into daily_log_participants (daily_log_id, cap, employee_id, diem_toi_da)
      values (p_daily_log_id, 'gd', v_gd_id, v_catalog.diem_gd)
      on conflict (daily_log_id, cap) do nothing;
    end if;
  end if;

  return json_build_object('diem_tien_do', v_diem_tien_do, 'dung_han', v_dung_han, 'da_gop', false);
end;
$$;

-- get_today_screen: bổ sung ghi_chu của lượt đã kết thúc hôm nay vào JSON trả về.
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
      jc.id as job_catalog_id, jc.ma_cv, mc.ten_mang as nhom_nv,
      null::text as dinh_ky_tan_suat, jc.ten_cong_viec,
      coalesce(jc.diem_can_bo, 0) as gia_tri_cv,
      fin.id as log_id, fin.so_luong as finished_so_luong, fin.gia_tri_tong as finished_gia_tri_tong,
      fin.is_ghi_bu as finished_is_ghi_bu, fin.ghi_chu as finished_ghi_chu,
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

grant execute on function start_task(uuid, uuid, date, date, int, text) to anon;
grant execute on function update_task_progress(uuid, uuid, int, date, date, text) to anon;
