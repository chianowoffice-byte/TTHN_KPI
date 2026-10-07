-- ============================================================================
-- 1) "Điểm thưởng": mảng Hoạt động đoàn thể (mảng 7) tính là điểm thưởng, tách
--    riêng khỏi điểm công việc KPI thường (màn Hôm nay, Thống kê, Tổng quan, Báo cáo).
-- 2) Báo cáo cá nhân theo khoảng ngày (get_my_report): việc đã khai báo + điểm,
--    và (nếu là người kiểm soát/duyệt) các việc đã kiểm soát + điểm kiểm soát.
-- 3) get_pending_reviews: định nghĩa lại bản đầy đủ (ghi chú, cờ ghi bù, lịch sử
--    gia hạn) — chạy lại an toàn, đảm bảo màn Duyệt điểm luôn lấy được ghi chú.
-- Chạy lại an toàn.
-- ============================================================================

alter table mang_cv add column if not exists la_diem_thuong boolean not null default false;
update mang_cv set la_diem_thuong = (ma_mang = 7);

-- ---------------------------------------------------------------------------
-- get_today_screen: kèm cờ la_diem_thuong của mảng cho từng việc trong danh mục.
-- ---------------------------------------------------------------------------
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
      jc.id as job_catalog_id, jc.ma_cv, mc.ten_mang as nhom_nv, mc.la_diem_thuong,
      jc.tan_suat as dinh_ky_tan_suat, jc.ten_cong_viec,
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

-- ---------------------------------------------------------------------------
-- get_pending_reviews: bản đầy đủ (ghi chú + ghi bù + lịch sử gia hạn).
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

-- ---------------------------------------------------------------------------
-- Thống kê cá nhân theo tháng: giá trị công việc KHÔNG gồm điểm thưởng; điểm
-- thưởng hiện riêng.
-- ---------------------------------------------------------------------------
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
  v_diem_thuong numeric;
begin
  select
    count(*),
    count(*) filter (where dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han),
    count(*) filter (where dl.ngay_ket_thuc_thuc_te > dl.ngay_den_han),
    coalesce(sum(dl.gia_tri_tong) filter (where not mc.la_diem_thuong), 0),
    coalesce(sum(dl.gia_tri_tong) filter (where mc.la_diem_thuong), 0)
  into v_tong_viec, v_dung_han, v_qua_han, v_tong_gia_tri, v_diem_thuong
  from daily_log dl
  join job_catalog jc on jc.id = dl.job_catalog_id
  join mang_cv mc on mc.id = jc.mang_cv_id
  where dl.employee_id = v_employee_id
    and dl.ngay_ket_thuc_thuc_te is not null
    and extract(year from dl.ngay_ket_thuc_thuc_te) = p_nam
    and extract(month from dl.ngay_ket_thuc_thuc_te) = p_thang;

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
    'tong_gia_tri', v_tong_gia_tri, 'diem_thuong', v_diem_thuong,
    'theo_tuan', v_by_week
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Tổng quan phòng (Trưởng phòng): tách điểm thưởng tương tự.
-- ---------------------------------------------------------------------------
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
  v_diem_thuong numeric;
begin
  select app_role into v_role from employees where id = v_employee_id;
  if v_role <> 'truong_phong' then
    raise exception 'Chỉ Trưởng phòng mới xem được màn tổng quan này.';
  end if;

  select
    count(*),
    count(*) filter (where dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han),
    count(*) filter (where dl.ngay_ket_thuc_thuc_te > dl.ngay_den_han),
    coalesce(sum(dl.gia_tri_tong) filter (where not mc.la_diem_thuong), 0),
    coalesce(sum(dl.gia_tri_tong) filter (where mc.la_diem_thuong), 0)
  into v_tong_viec, v_dung_han, v_qua_han, v_tong_gia_tri, v_diem_thuong
  from daily_log dl
  join job_catalog jc on jc.id = dl.job_catalog_id
  join mang_cv mc on mc.id = jc.mang_cv_id
  where dl.ngay_ket_thuc_thuc_te is not null
    and extract(year from dl.ngay_ket_thuc_thuc_te) = p_nam
    and extract(month from dl.ngay_ket_thuc_thuc_te) = p_thang;

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
      coalesce(sum(dl.gia_tri_tong) filter (where not mc.la_diem_thuong), 0) as gia_tri,
      coalesce(sum(dl.gia_tri_tong) filter (where mc.la_diem_thuong), 0) as diem_thuong
    from employees e
    left join daily_log dl on dl.employee_id = e.id and dl.ngay_ket_thuc_thuc_te is not null
      and extract(year from dl.ngay_ket_thuc_thuc_te) = p_nam
      and extract(month from dl.ngay_ket_thuc_thuc_te) = p_thang
    left join job_catalog jc on jc.id = dl.job_catalog_id
    left join mang_cv mc on mc.id = jc.mang_cv_id
    where e.active
    group by e.id, e.ho_ten, e.ma_cbnv
  ) row;

  return json_build_object(
    'nam', p_nam, 'thang', p_thang,
    'tong_viec', v_tong_viec, 'dung_han', v_dung_han, 'qua_han', v_qua_han,
    'tong_gia_tri', v_tong_gia_tri, 'diem_thuong', v_diem_thuong,
    'theo_tuan', v_by_week,
    'theo_can_bo', v_by_nhan_su
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- BÁO CÁO CÁ NHÂN THEO KHOẢNG NGÀY — ai cũng xem được của chính mình.
--  • khai_bao: việc mình khai báo. Việc đã Kết thúc tính theo ngày kết thúc, việc
--    đang thực hiện tính theo ngày bắt đầu, nằm trong [p_tu, p_den].
--  • kiem_soat: việc mình được giao duyệt/kiểm soát (Phó/Trưởng phòng...) có
--    ngày kết thúc trong khoảng, kèm điểm đã chấm + ghi chú của người làm.
-- ---------------------------------------------------------------------------
create or replace function get_my_report(p_token uuid, p_tu date, p_den date) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_khai_bao json;
  v_kiem_soat json;
  v_tong_kb json;
  v_tong_ks json;
begin
  if p_tu is null or p_den is null or p_tu > p_den then
    raise exception 'Khoảng ngày không hợp lệ — "Từ ngày" phải nhỏ hơn hoặc bằng "Đến ngày".';
  end if;
  if p_den - p_tu > 366 then
    raise exception 'Chỉ xem được tối đa 1 năm mỗi lần.';
  end if;

  select coalesce(json_agg(row order by row.ngay desc, row.ma_cv), '[]'::json) into v_khai_bao from (
    select
      dl.id, coalesce(dl.ngay_ket_thuc_thuc_te, dl.ngay_bat_dau) as ngay,
      jc.ma_cv, jc.ten_cong_viec, mc.ten_mang, mc.la_diem_thuong,
      dl.so_luong, dl.gia_tri_don_vi, dl.gia_tri_tong, dl.diem_tien_do, dl.diem_chat_luong,
      dl.ngay_bat_dau, dl.ngay_den_han, dl.ngay_ket_thuc_thuc_te, dl.ghi_chu, dl.is_ghi_bu,
      (dl.ngay_ket_thuc_thuc_te is not null) as da_xong,
      (dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han) as dung_han
    from daily_log dl
    join job_catalog jc on jc.id = dl.job_catalog_id
    join mang_cv mc on mc.id = jc.mang_cv_id
    where dl.employee_id = v_employee_id
      and coalesce(dl.ngay_ket_thuc_thuc_te, dl.ngay_bat_dau) between p_tu and p_den
  ) row;

  select json_build_object(
    'so_viec_xong', count(*) filter (where dl.ngay_ket_thuc_thuc_te is not null),
    'so_viec_dang_lam', count(*) filter (where dl.ngay_ket_thuc_thuc_te is null),
    'gia_tri', coalesce(sum(dl.gia_tri_tong) filter (where dl.ngay_ket_thuc_thuc_te is not null and not mc.la_diem_thuong), 0),
    'diem_thuong', coalesce(sum(dl.gia_tri_tong) filter (where dl.ngay_ket_thuc_thuc_te is not null and mc.la_diem_thuong), 0),
    'diem_tien_do', coalesce(sum(dl.diem_tien_do) filter (where not mc.la_diem_thuong), 0),
    'diem_chat_luong', coalesce(sum(dl.diem_chat_luong) filter (where not mc.la_diem_thuong), 0)
  ) into v_tong_kb
  from daily_log dl
  join job_catalog jc on jc.id = dl.job_catalog_id
  join mang_cv mc on mc.id = jc.mang_cv_id
  where dl.employee_id = v_employee_id
    and coalesce(dl.ngay_ket_thuc_thuc_te, dl.ngay_bat_dau) between p_tu and p_den;

  select coalesce(json_agg(row order by row.ngay desc, row.ma_cv), '[]'::json) into v_kiem_soat from (
    select
      p.id, p.cap, p.diem_toi_da, p.diem_tien_do, p.diem_chat_luong, p.da_duyet, p.duyet_luc,
      dl.ngay_ket_thuc_thuc_te as ngay,
      e.ho_ten as nguoi_thuc_hien, e.ma_cbnv as ma_cbnv_thuc_hien,
      jc.ma_cv, jc.ten_cong_viec,
      dl.so_luong, dl.ngay_bat_dau, dl.ngay_den_han, dl.ngay_ket_thuc_thuc_te,
      dl.ghi_chu, dl.is_ghi_bu,
      (dl.ngay_ket_thuc_thuc_te <= dl.ngay_den_han) as dung_han,
      (select count(*) from daily_log_gia_han g where g.daily_log_id = dl.id) as so_lan_gia_han
    from daily_log_participants p
    join daily_log dl on dl.id = p.daily_log_id
    join job_catalog jc on jc.id = dl.job_catalog_id
    join employees e on e.id = dl.employee_id
    where p.employee_id = v_employee_id
      and dl.ngay_ket_thuc_thuc_te between p_tu and p_den
  ) row;

  select json_build_object(
    'so_viec', count(*),
    'da_duyet', count(*) filter (where p.da_duyet),
    'cho_duyet', count(*) filter (where not p.da_duyet),
    'diem_tien_do', coalesce(sum(p.diem_tien_do) filter (where p.da_duyet and p.cap in ('kiem_soat', 'truong_phong')), 0),
    'diem_chat_luong', coalesce(sum(p.diem_chat_luong) filter (where p.da_duyet and p.cap in ('kiem_soat', 'truong_phong')), 0)
  ) into v_tong_ks
  from daily_log_participants p
  join daily_log dl on dl.id = p.daily_log_id
  where p.employee_id = v_employee_id
    and dl.ngay_ket_thuc_thuc_te between p_tu and p_den;

  return json_build_object(
    'tu', p_tu, 'den', p_den,
    'khai_bao', v_khai_bao, 'tong_khai_bao', v_tong_kb,
    'kiem_soat', v_kiem_soat, 'tong_kiem_soat', v_tong_ks
  );
end;
$$;

grant execute on function get_my_report(uuid, date, date) to anon;

-- Kiểm tra (chỉ đọc): mảng 7 phải có la_diem_thuong = true.
select ma_mang, ten_mang, la_diem_thuong from mang_cv order by ma_mang;
