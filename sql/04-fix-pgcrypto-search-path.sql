-- ============================================================================
-- FIX: "function crypt(text, text) does not exist" khi gọi login()/doi_mat_khau().
-- Nguyên nhân: Supabase cài pgcrypto vào schema 'extensions', nhưng 2 hàm dưới
-- đây giới hạn search_path chỉ còn 'public' (cố ý, chặn search_path injection)
-- nên không thấy crypt()/gen_salt() nữa. Thêm 'extensions' vào search_path của
-- đúng 2 hàm cần dùng pgcrypto — các hàm khác không đụng tới, không cần đổi.
-- Chạy lại an toàn (create or replace).
-- ============================================================================

create or replace function login(p_ma_cbnv text, p_mat_khau text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_employee employees;
  v_account  accounts;
  v_token    uuid;
begin
  select * into v_employee from employees where ma_cbnv = trim(p_ma_cbnv) and active;
  if v_employee.id is null then
    raise exception 'Sai mã CBNV hoặc mật khẩu.';
  end if;

  select * into v_account from accounts where employee_id = v_employee.id;
  if v_account.id is null then
    raise exception 'Tài khoản chưa được tạo — liên hệ Trưởng phòng.';
  end if;

  if v_account.locked_until is not null and v_account.locked_until > now() then
    raise exception 'Tài khoản tạm khoá do nhập sai nhiều lần — thử lại sau %.',
      to_char(v_account.locked_until, 'HH24:MI DD/MM');
  end if;

  if v_account.mat_khau_hash <> crypt(p_mat_khau, v_account.mat_khau_hash) then
    update accounts set
      failed_attempts = failed_attempts + 1,
      locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
    where id = v_account.id;
    raise exception 'Sai mã CBNV hoặc mật khẩu.';
  end if;

  update accounts set failed_attempts = 0, locked_until = null, updated_at = now() where id = v_account.id;

  insert into login_sessions (employee_id) values (v_employee.id) returning token into v_token;

  return json_build_object(
    'token', v_token,
    'employee_id', v_employee.id,
    'ma_cbnv', v_employee.ma_cbnv,
    'ho_ten', v_employee.ho_ten,
    'app_role', v_employee.app_role,
    'department_id', v_employee.department_id,
    'must_change_password', v_account.must_change_password
  );
end;
$$;

create or replace function doi_mat_khau(p_token uuid, p_mat_khau_cu text, p_mat_khau_moi text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_employee_id uuid := session_employee_id(p_token);
  v_hash text;
begin
  select mat_khau_hash into v_hash from accounts where employee_id = v_employee_id;
  if v_hash <> crypt(p_mat_khau_cu, v_hash) then
    raise exception 'Mật khẩu hiện tại không đúng.';
  end if;
  if length(p_mat_khau_moi) < 6 then
    raise exception 'Mật khẩu mới phải có ít nhất 6 ký tự.';
  end if;
  update accounts set
    mat_khau_hash = crypt(p_mat_khau_moi, gen_salt('bf')),
    must_change_password = false,
    updated_at = now()
  where employee_id = v_employee_id;
end;
$$;
