-- ============================================================================
-- DỌN SẠCH TOÀN BỘ — chỉ chạy vì đã lỡ chạy bộ 3 file SQL bản CŨ (dùng
-- Supabase Auth) và giờ đổi sang bản MỚI (bảng accounts tự quản lý).
-- An toàn: lúc này chưa có dữ liệu thật nào (mới có 12 cán bộ mẫu + danh mục
-- việc), xoá sạch làm lại từ đầu chắc chắn hơn vá từng chỗ.
--
-- CHẠY FILE NÀY 1 LẦN, SAU ĐÓ CHẠY LẠI ĐÚNG THỨ TỰ:
--   01-schema-va-rls.sql → 02-seed-nhan-su.sql → 03-seed-danh-muc-cv.sql
-- ============================================================================

drop table if exists satisfaction_survey cascade;
drop table if exists kpi_quarter cascade;
drop table if exists daily_log cascade;
drop table if exists job_catalog cascade;
drop table if exists login_sessions cascade;
drop table if exists accounts cascade;
drop table if exists employees cascade;
drop table if exists departments cascade;

drop function if exists my_employee_id() cascade;
drop function if exists my_role() cascade;
drop function if exists my_department_id() cascade;
drop function if exists is_manager_of(uuid) cascade;
drop function if exists session_employee_id(uuid) cascade;
drop function if exists login(text, text) cascade;
drop function if exists doi_mat_khau(uuid, text, text) cascade;
drop function if exists logout(uuid) cascade;
drop function if exists fn_check_quarter_lock() cascade;
drop function if exists fn_only_truong_phong_locks() cascade;
