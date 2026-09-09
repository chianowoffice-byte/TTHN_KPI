-- ============================================================================
-- FIX LỖI THẬT: bỏ tích 1 việc báo thành công (done:false) nhưng dòng nhật ký
-- KHÔNG bị xoá. Nguyên nhân: trigger fn_check_quarter_lock (chặn sửa nhật ký
-- của quý đã khoá) kết thúc bằng "return new" — khi trigger chạy cho lệnh
-- DELETE thì "new" luôn là NULL, và Postgres coi trigger BEFORE DELETE trả về
-- NULL là lệnh "âm thầm huỷ thao tác xoá" (không có lỗi nào được báo ra).
-- Sửa: trả coalesce(new, old) để DELETE vẫn chạy bình thường.
-- Chạy lại an toàn (create or replace).
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
  return coalesce(new, old);
end;
$$;

-- Dọn dòng dữ liệu rác phát sinh trong lúc test lỗi này (HC-VT-01 của Nguyễn
-- Hồng Quang, ngày hôm nay, đáng lẽ đã bị xoá nhưng bị trigger chặn nhầm).
delete from daily_log
where job_catalog_id = '6a69fd72-6343-4e87-957f-bd0b072e78b2'
  and ngay_hoan_thanh_thuc_te = current_date;
