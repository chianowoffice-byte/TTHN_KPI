-- ============================================================================
-- MÀN "THỐNG KÊ" — bản cá nhân của màn Tổng quan, cho MỌI người (cán bộ, Phó/
-- Trưởng phòng) tự xem hoạt động của chính mình theo tháng. Không giới hạn
-- vai trò như get_month_overview (chỉ Trưởng phòng) — ai gọi thì xem của
-- chính người đó, không xem được của người khác.
-- ============================================================================

create or replace function get_my_month_overview(
  p_token uuid,
  p_nam int default extract(year from current_date)::int,
  p_thang int default extract(month from current_date)::int
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_by_week json;
  v_tong_viec int;
  v_dung_han int;
  v_qua_han int;
  v_tong_gia_tri numeric;
begin
  select
    count(*),
    count(*) filter (where ngay_ket_thuc_thuc_te <= ngay_den_han),
    count(*) filter (where ngay_ket_thuc_thuc_te > ngay_den_han),
    coalesce(sum(gia_tri_tong), 0)
  into v_tong_viec, v_dung_han, v_qua_han, v_tong_gia_tri
  from daily_log
  where employee_id = v_employee_id
    and ngay_ket_thuc_thuc_te is not null
    and extract(year from ngay_ket_thuc_thuc_te) = p_nam
    and extract(month from ngay_ket_thuc_thuc_te) = p_thang;

  select coalesce(json_agg(row order by row.tuan), '[]'::json) into v_by_week from (
    select
      ((extract(day from ngay_ket_thuc_thuc_te)::int - 1) / 7) + 1 as tuan,
      count(*) filter (where ngay_ket_thuc_thuc_te <= ngay_den_han) as dung_han,
      count(*) filter (where ngay_ket_thuc_thuc_te > ngay_den_han) as qua_han
    from daily_log
    where employee_id = v_employee_id
      and ngay_ket_thuc_thuc_te is not null
      and extract(year from ngay_ket_thuc_thuc_te) = p_nam
      and extract(month from ngay_ket_thuc_thuc_te) = p_thang
    group by 1
  ) row;

  return json_build_object(
    'nam', p_nam, 'thang', p_thang,
    'tong_viec', v_tong_viec, 'dung_han', v_dung_han, 'qua_han', v_qua_han,
    'tong_gia_tri', v_tong_gia_tri,
    'theo_tuan', v_by_week
  );
end;
$$;

grant execute on function get_my_month_overview(uuid, int, int) to anon;
