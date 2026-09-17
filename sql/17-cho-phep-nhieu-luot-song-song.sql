-- ============================================================================
-- Cho phép 1 công việc có nhiều lượt "đang thực hiện" song song (trước đây
-- chỉ tối đa 1 lượt mở/công việc), và catalog KHÔNG còn ẩn công việc đang
-- thực hiện khỏi list tích được — cán bộ có thể tích thêm 1 lượt mới ngay
-- cả khi lượt cũ của đúng việc đó chưa Kết thúc (VD: làm việc A buổi sáng,
-- chưa xong, phát sinh thêm 1 lượt việc A độc lập buổi chiều).
-- Khi Kết thúc, logic gộp Số lượng (nếu trùng Ngày bắt đầu + Ngày kết thúc,
-- đã có ở migration 16) vẫn áp dụng bình thường.
-- ============================================================================

drop index if exists uq_daily_log_one_open_per_task;

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
end;
$$;

-- get_today_screen: catalog hiện TẤT CẢ công việc active (không loại việc
-- đang thực hiện nữa) + báo kèm số lượt đang mở/tổng SL đang mở của việc đó,
-- để hiện badge "Đang thực hiện" ngay trên dòng catalog.
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
    order by mc.ma_mang, jc.ma_cv
  ) row;

  return json_build_object('ngay', p_ngay, 'in_progress', v_in_progress, 'catalog', v_catalog);
end;
$$;
