-- ============================================================================
-- Màn Duyệt điểm: bổ sung Ngày bắt đầu, Ghi chú chi tiết, cờ Ghi bù vào dữ
-- liệu trả về — để lãnh đạo click vào từng việc xem được toàn bộ nội dung
-- cán bộ đã nhập (trước đây chỉ thấy tên việc/mã/SL/ngày kết thúc/hạn).
-- ============================================================================

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
