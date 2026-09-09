-- ============================================================================
-- RPC PHỤC VỤ MÀN "HÔM NAY" — đọc danh mục việc + trạng thái đã tích của 1
-- ngày, và tích/bỏ tích 1 việc. Theo đúng khuôn đã đặt ở 01-schema-va-rls.sql:
-- mọi RPC ghi dữ liệu đều set_config('app.employee_id', ...) trước khi
-- INSERT/DELETE để trigger khoá quý (fn_check_quarter_lock) nhận biết đúng
-- người đang thao tác.
--
-- Đơn giản hoá so với bản mô phỏng: KHÔNG tự suy "hạn hôm nay" từ cột tần
-- suất (chữ tự do trong Excel gốc, quá nhiều biến thể để suy luận chắc chắn)
-- — hiện toàn bộ danh mục, việc có tần suất chứa "ngày" ghim lên đầu, còn lại
-- xếp theo nhóm nghiệp vụ; cán bộ tự tìm và tích.
-- ============================================================================

create or replace function get_today_screen(p_token uuid, p_ngay date default current_date) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_items json;
begin
  select coalesce(json_agg(row), '[]'::json) into v_items from (
    select
      jc.id as job_catalog_id,
      jc.ma_cv,
      jc.nhom_nv,
      jc.ten_cong_viec,
      jc.dinh_ky_tan_suat,
      jc.gia_tri_cv,
      dl.id as log_id,
      dl.diem_tien_do,
      dl.diem_chat_luong,
      dl.is_ghi_bu,
      (dl.id is not null) as done
    from job_catalog jc
    left join daily_log dl
      on dl.job_catalog_id = jc.id
      and dl.employee_id = v_employee_id
      and dl.ngay_hoan_thanh_thuc_te = p_ngay
    where jc.employee_id = v_employee_id and jc.active
    order by (jc.dinh_ky_tan_suat ilike '%ngày%') desc, jc.nhom_nv, jc.ma_cv
  ) row;

  return json_build_object('ngay', p_ngay, 'items', v_items);
end;
$$;

create or replace function toggle_today_task(p_token uuid, p_job_catalog_id uuid, p_ngay date default current_date) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_catalog job_catalog;
  v_existing_id uuid;
begin
  perform set_config('app.employee_id', v_employee_id::text, true);

  select * into v_catalog from job_catalog
  where id = p_job_catalog_id and employee_id = v_employee_id and active;
  if v_catalog.id is null then
    raise exception 'Không tìm thấy công việc này.';
  end if;

  select id into v_existing_id from daily_log
  where job_catalog_id = p_job_catalog_id and employee_id = v_employee_id and ngay_hoan_thanh_thuc_te = p_ngay;

  if v_existing_id is not null then
    delete from daily_log where id = v_existing_id;
    return json_build_object('done', false);
  else
    insert into daily_log
      (employee_id, job_catalog_id, ngay_ghi_nhan, ngay_hoan_thanh_thuc_te,
       gia_tri_cv_snapshot, diem_tien_do, diem_chat_luong, created_by)
    values
      (v_employee_id, p_job_catalog_id, current_date, p_ngay,
       v_catalog.gia_tri_cv, v_catalog.gia_tri_cv, v_catalog.gia_tri_cv, v_employee_id);
    return json_build_object('done', true);
  end if;
end;
$$;

grant execute on function get_today_screen(uuid, date) to anon;
grant execute on function toggle_today_task(uuid, uuid, date) to anon;
