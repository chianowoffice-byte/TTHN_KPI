-- ============================================================================
-- MÀN "TỔNG QUAN" — CHỈ Trưởng phòng xem. Tổng hoạt động của cả phòng trong
-- 1 tháng: tổng việc đã kết thúc, đúng hạn/quá hạn, tổng giá trị, chia theo
-- tuần trong tháng và theo từng cán bộ.
-- ============================================================================

create or replace function get_month_overview(
  p_token uuid,
  p_nam int default extract(year from current_date)::int,
  p_thang int default extract(month from current_date)::int
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_role text;
  v_by_week json;
  v_by_nhan_su json;
  v_tong_viec int;
  v_dung_han int;
  v_qua_han int;
  v_tong_gia_tri numeric;
begin
  select app_role into v_role from employees where id = v_employee_id;
  if v_role <> 'truong_phong' then
    raise exception 'Chỉ Trưởng phòng mới xem được màn tổng quan này.';
  end if;

  select
    count(*),
    count(*) filter (where ngay_ket_thuc_thuc_te <= ngay_den_han),
    count(*) filter (where ngay_ket_thuc_thuc_te > ngay_den_han),
    coalesce(sum(gia_tri_tong), 0)
  into v_tong_viec, v_dung_han, v_qua_han, v_tong_gia_tri
  from daily_log
  where ngay_ket_thuc_thuc_te is not null
    and extract(year from ngay_ket_thuc_thuc_te) = p_nam
    and extract(month from ngay_ket_thuc_thuc_te) = p_thang;

  -- Chia theo tuần trong tháng (tuần 1 = ngày 1-7, ...) — dễ nhìn trên điện
  -- thoại hơn 31 cột/ngày.
  select coalesce(json_agg(row order by row.tuan), '[]'::json) into v_by_week from (
    select
      ((extract(day from ngay_ket_thuc_thuc_te)::int - 1) / 7) + 1 as tuan,
      count(*) filter (where ngay_ket_thuc_thuc_te <= ngay_den_han) as dung_han,
      count(*) filter (where ngay_ket_thuc_thuc_te > ngay_den_han) as qua_han
    from daily_log
    where ngay_ket_thuc_thuc_te is not null
      and extract(year from ngay_ket_thuc_thuc_te) = p_nam
      and extract(month from ngay_ket_thuc_thuc_te) = p_thang
    group by 1
  ) row;

  select coalesce(json_agg(row order by row.gia_tri desc, row.ho_ten), '[]'::json) into v_by_nhan_su from (
    select
      e.ho_ten, e.ma_cbnv,
      count(dl.id) as so_viec,
      count(dl.id) filter (where dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han) as dung_han,
      count(dl.id) filter (where dl.ngay_ket_thuc_thuc_te > dl.ngay_den_han) as qua_han,
      coalesce(sum(dl.gia_tri_tong), 0) as gia_tri
    from employees e
    left join daily_log dl on dl.employee_id = e.id and dl.ngay_ket_thuc_thuc_te is not null
      and extract(year from dl.ngay_ket_thuc_thuc_te) = p_nam
      and extract(month from dl.ngay_ket_thuc_thuc_te) = p_thang
    where e.active
    group by e.id, e.ho_ten, e.ma_cbnv
  ) row;

  return json_build_object(
    'nam', p_nam, 'thang', p_thang,
    'tong_viec', v_tong_viec, 'dung_han', v_dung_han, 'qua_han', v_qua_han,
    'tong_gia_tri', v_tong_gia_tri,
    'theo_tuan', v_by_week,
    'theo_can_bo', v_by_nhan_su
  );
end;
$$;

grant execute on function get_month_overview(uuid, int, int) to anon;
