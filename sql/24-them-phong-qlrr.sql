-- ============================================================================
-- THÊM PHÒNG QLRR (Quản lý rủi ro) vào hệ thống. Nguồn: KPI_QLRR_.xlsx
-- (78 việc, 11 mảng, 5 nhân sự). Cần đã chạy 23-them-phong-qlkh.sql
-- (mang_cv theo phòng + cột thu_tu). Chạy lại an toàn.
--
--  * Mã việc đổi từ CV00001.. thành QLRR-001.. để không trùng mã của phòng khác.
--  * Quản lý trực tiếp: các Phó trưởng phòng và cán bộ đều đặt = Trưởng phòng
--    (Dương Bá Quyền, 11539) vì file không ghi ai quản lý ai. Đổi bằng:
--      update employees set quan_ly_truc_tiep_id = (select id from employees where ma_cbnv = '<mã người quản lý>')
--      where ma_cbnv = '<mã cán bộ>';
--  * Mật khẩu mặc định 123456, bắt đổi ở lần đăng nhập đầu.
-- ============================================================================

insert into departments (ma_phong, ten_phong) values ('QLRR', 'Phòng QLRR')
on conflict (ma_phong) do nothing;

do $do$
declare
  v_pb uuid := (select id from departments where ma_phong = 'QLRR');
  v_tp uuid;
begin
  -- 1) Mảng
  insert into mang_cv (ma_mang, ten_mang, department_id, la_diem_thuong) values
    (1, 'Quản lý tín dụng', v_pb, false),
    (2, 'Quản lý rủi ro tín dụng', v_pb, false),
    (3, 'Quản lý rủi ro hoạt động', v_pb, false),
    (4, 'Quản lý phân công lao động & giờ làm việc', v_pb, false),
    (5, 'Phòng chống rửa tiền', v_pb, false),
    (6, 'Quản lý hệ thống chất lượng ISO', v_pb, false),
    (7, 'Kiểm tra nội bộ', v_pb, false),
    (8, 'Nhiệm vụ QLRR chung', v_pb, false),
    (9, 'Xử lý nợ / Xử lý tranh chấp', v_pb, false),
    (10, 'RRTD đối tác & RRHĐ - CNTT', v_pb, false),
    (11, 'Công tác khác', v_pb, false)
  on conflict (department_id, ma_mang) do update set ten_mang = excluded.ten_mang;

  -- 2) Nhân sự
  insert into employees (ma_cbnv, ho_ten, chuc_danh, department_id, app_role, active) values
    ('11539', 'Dương Bá Quyền', 'Trưởng phòng QLRR', v_pb, 'truong_phong', true),
    ('28229', 'Mai Danh Kiên', 'Phó trưởng phòng QLRR', v_pb, 'pho_truong_phong', true),
    ('1215', 'Trần Thị Kim Anh', 'Phó trưởng phòng QLRR', v_pb, 'pho_truong_phong', true),
    ('157272', 'Nguyễn Ngọc Hà', 'Cán bộ', v_pb, 'canbo', true),
    ('157349', 'Trần Thanh Hà', 'Phó trưởng phòng QLRR', v_pb, 'pho_truong_phong', true)
  on conflict (ma_cbnv) do update set
    ho_ten = excluded.ho_ten, chuc_danh = excluded.chuc_danh, department_id = excluded.department_id,
    app_role = excluded.app_role, active = true;

  select id into v_tp from employees where ma_cbnv = '11539';
  update employees set quan_ly_truc_tiep_id = v_tp
  where ma_cbnv in ('28229', '1215', '157272', '157349');

  insert into accounts (employee_id, mat_khau_hash, must_change_password)
  select id, extensions.crypt('123456', extensions.gen_salt('bf')), true
  from employees where ma_cbnv in ('11539', '28229', '1215', '157272', '157349')
  on conflict (employee_id) do nothing;

  -- 3) Phân công mảng theo sheet "Cán bộ"
  delete from employee_mang_cv where employee_id in (select id from employees where ma_cbnv in ('11539', '28229', '1215', '157272', '157349'));
  insert into employee_mang_cv (employee_id, mang_cv_id)
  select e.id, mc.id
  from (values
    ('11539', 1),
    ('11539', 2),
    ('11539', 3),
    ('11539', 4),
    ('11539', 5),
    ('11539', 6),
    ('11539', 7),
    ('11539', 8),
    ('11539', 9),
    ('11539', 10),
    ('11539', 11),
    ('28229', 1),
    ('28229', 2),
    ('28229', 3),
    ('28229', 4),
    ('28229', 5),
    ('28229', 6),
    ('28229', 7),
    ('28229', 8),
    ('28229', 9),
    ('28229', 10),
    ('28229', 11),
    ('1215', 1),
    ('1215', 2),
    ('1215', 3),
    ('1215', 4),
    ('1215', 5),
    ('1215', 6),
    ('1215', 7),
    ('1215', 8),
    ('1215', 9),
    ('1215', 10),
    ('1215', 11),
    ('157272', 1),
    ('157272', 2),
    ('157272', 3),
    ('157272', 4),
    ('157272', 5),
    ('157272', 6),
    ('157272', 7),
    ('157272', 8),
    ('157272', 9),
    ('157272', 10),
    ('157272', 11),
    ('157349', 1),
    ('157349', 2),
    ('157349', 3),
    ('157349', 4),
    ('157349', 5),
    ('157349', 6),
    ('157349', 7),
    ('157349', 8),
    ('157349', 9),
    ('157349', 10),
    ('157349', 11)
  ) a(ma_cbnv, ma_mang)
  join employees e on e.ma_cbnv = a.ma_cbnv
  join mang_cv mc on mc.department_id = v_pb and mc.ma_mang = a.ma_mang
  on conflict (employee_id, mang_cv_id) do nothing;

  -- 4) Danh mục việc
  insert into job_catalog (ma_cv, ten_cong_viec, mang_cv_id, diem_can_bo, diem_kiem_soat, tan_suat, thu_tu, active)
  select v.ma_cv, v.ten, mc.id, v.diem_can_bo, v.diem_kiem_soat, v.tan_suat, v.thu_tu, true
  from (values
    (1, 'QLRR-001', 'Tham mưu đề xuất chính sách tín dụng và phổ biển các VBCĐ do BIDV ban hành', 1, 57.0::numeric, 57.0::numeric, 'Theo văn bản ban hành'),
    (2, 'QLRR-002', 'Xây dựng VB hướng dẫn t/hiện công tác TD tại CN & biện pháp phát triển TD: Mức độ đơn giản', 1, 57.0::numeric, 57.0::numeric, 'Theo kế hoạch/phân giao'),
    (3, 'QLRR-003', 'Xây dựng VB hướng dẫn t/hiện công tác TD tại CN & biện pháp phát triển TD: Mức độ phức tạp', 1, 68.0::numeric, 68.0::numeric, 'Theo kế hoạch/phân giao'),
    (4, 'QLRR-004', 'Xác định, kiểm soát cơ cấu, giới hạn tín dụng tại Chi nhánh và các bộ phận nghiệp vụ liên quan', 1, 68.0::numeric, 68.0::numeric, 'Thường xuyên/định kỳ'),
    (5, 'QLRR-005', 'Đầu mối xây dựng, đề xuất trình Giám đốc kế hoạch giảm nợ xấu của Chi nhánh', 1, 70.0::numeric, 70.0::numeric, 'Theo kế hoạch/phân giao'),
    (6, 'QLRR-006', 'Giám sát, trình phê duyệt phân loại nợ và trích lập dự phòng rủi ro', 1, 68.0::numeric, 68.0::numeric, 'Khi phát sinh hồ sơ'),
    (7, 'QLRR-007', 'Khảo sát tài sản đảm bảo: Mức độ phức tạp (cần khảo sát tài sản định giá và 3 tài sản so sánh)', 1, 65.0::numeric, 65.0::numeric, 'Khi phát sinh hồ sơ'),
    (8, 'QLRR-008', 'Định giá tài sản đảm bảo (lập báo cáo định giá)', 1, 58.0::numeric, 58.0::numeric, 'Khi phát sinh hồ sơ (sau khi có kết quả khảo sát)'),
    (9, 'QLRR-009', 'Báo cáo công tác tín dụng và chất lượng tín dụng: mức độ đơn giản', 1, 50.0::numeric, 50.0::numeric, 'Định kỳ/đột xuất'),
    (10, 'QLRR-010', 'Báo cáo công tác TD và chất lượng TD: mức độ phức tạp cần', 1, 86.0::numeric, 86.0::numeric, 'Định kỳ/đột xuất'),
    (11, 'QLRR-011', 'P/hợp, đề xuất PA xử lý các khoản nợ xấu; nợ ngoại bảng', 1, 68.0::numeric, 68.0::numeric, 'Theo kế hoạch/phân giao'),
    (12, 'QLRR-012', 'Trình lãnh đạo về việc miễn, giảm lãi, cơ cấu nợ', 1, 48.0::numeric, 48.0::numeric, 'Khi phát sinh hồ sơ'),
    (13, 'QLRR-013', 'Tư vấn pháp lý liên quan đến hoạt động NH/Thẩm tra các HĐ và văn kiện TD: Mức độ đơn giản', 1, 48.0::numeric, 48.0::numeric, 'Khi phát sinh/theo phân công'),
    (14, 'QLRR-014', 'Tư vấn pháp lý liên quan hoạt động NH/Thẩm tra các HĐ, văn kiện TD: Mức độ phức tạp', 1, 68.0::numeric, 68.0::numeric, 'Khi phát sinh/theo phân công'),
    (15, 'QLRR-015', 'Rà soát, kiểm tra việc chấm điểm xếp hạng tín dụng của khối quản lý khách hàng', 1, 48.0::numeric, 48.0::numeric, 'Thường xuyên/định kỳ'),
    (16, 'QLRR-016', 'Tham mưu, đề xuất xây dựng các quy định, biện pháp quản lý rủi ro tín dụng:', 2, 68.0::numeric, 68.0::numeric, 'Theo kế hoạch/phân giao'),
    (17, 'QLRR-017', 'Thực hiện nhiệm vụ cán bộ thẩm định - Khách hàng bán lẻ: Mức độ đơn giản', 2, 30.0::numeric, 30.0::numeric, 'Phát sinh theo hồ sơ'),
    (18, 'QLRR-018', 'Thực hiện nhiệm vụ cán bộ thẩm định - Khách hàng bán lẻ: Mức độ phức tạp', 2, 58.0::numeric, 58.0::numeric, 'Phát sinh theo hồ sơ'),
    (19, 'QLRR-019', 'Thực hiện nhiệm vụ cán bộ thẩm định - Khách hàng doanh nghiệp (KHDN): Mức độ đơn giản', 2, 58.0::numeric, 58.0::numeric, 'Phát sinh theo hồ sơ'),
    (20, 'QLRR-020', 'Thực hiện nhiệm vụ cán bộ thẩm định - Khách hàng doanh nghiệp (KHDN): Mức độ phức tạp', 2, 82.0::numeric, 82.0::numeric, 'Phát sinh theo hồ sơ'),
    (21, 'QLRR-021', 'Phối hợp, hỗ trợ Phòng quản lý khách hàng để phát hiện, xử lý các khoản nợ có vấn đề.', 2, 48.0::numeric, 48.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (22, 'QLRR-022', 'Phổ biến, triển khai thực hiện các VBCĐ công văn hướng dẫn về QLRRHĐ', 3, 46.0::numeric, 46.0::numeric, 'Theo văn bản ban hành'),
    (23, 'QLRR-023', 'T/hiện các biện pháp kiểm soát, khắc phục theo chỉ đạo của TSC và đề xuất triển khai tại CN', 3, 58.0::numeric, 58.0::numeric, 'Thường xuyên/định kỳ'),
    (24, 'QLRR-024', 'Phổ biến CV cảnh báo&triển khai biện pháp phòng ngừa, kiểm soát theo chỉ đạo TSC.', 3, 46.0::numeric, 46.0::numeric, 'Theo văn bản ban hành'),
    (25, 'QLRR-025', 'Thu thập, tổng hợp, theo dõi, báo cáo tình hình xử lý, khắc phục sự kiện RRHĐ nhóm 1', 3, 58.0::numeric, 58.0::numeric, 'Định kỳ/đột xuất'),
    (26, 'QLRR-026', 'Tổng hợp, rà soát và báo cáo tình hình xử lý, khắc phục sự kiện RRHĐ nhóm 2 của CN', 3, 68.0::numeric, 68.0::numeric, 'Định kỳ/đột xuất'),
    (27, 'QLRR-027', 'Đầu mối rà soát dữ liệu giao dịch nghi ngờ; tổng hợp và báo cáo kết quả rà soát về TSC', 3, 80.0::numeric, 80.0::numeric, 'Định kỳ/đột xuất'),
    (28, 'QLRR-028', 'T/hợp & đề xuất hình thức xử lý cá nhân vi phạm & gửi BC kết quả xử lý về TSC.', 3, 80.0::numeric, 80.0::numeric, 'Theo kế hoạch/phân giao'),
    (29, 'QLRR-029', 'Lưu trữ, quản lý dữ liệu rủi ro hoạt động của chi nhánh.', 3, 18.0::numeric, 18.0::numeric, 'Khi phát sinh'),
    (30, 'QLRR-030', 'Tổ chức tự đào tạo về QLRRHĐ tại chi nhánh', 3, 58.0::numeric, 58.0::numeric, 'Theo kế hoạch'),
    (31, 'QLRR-031', 'Phổ biến, triển khai thực hiện VBCĐ, công văn hướng dẫn về quản lý PCLV&GD', 4, 46.0::numeric, 46.0::numeric, 'Theo văn bản ban hành'),
    (32, 'QLRR-032', 'Giám sát, theo dõi việc thực hiện Quy định về PC&KG làm việc tại BIDV.', 4, 58.0::numeric, 58.0::numeric, 'Thường xuyên/định kỳ'),
    (33, 'QLRR-033', 'Tổng hợp và đề xuất hình thức xử lý cá nhân có hành vi vi phạm, gửi kết quả xử lý về TSC.', 4, 68.0::numeric, 68.0::numeric, 'Theo kế hoạch/phân giao'),
    (34, 'QLRR-034', 'Tư vấn,tham mưu cho lãnh đạo triển khai chủ trương, chỉ đạo của BIDV về công tác PCRT', 5, 56.0::numeric, 56.0::numeric, 'Theo kế hoạch/phân giao'),
    (35, 'QLRR-035', 'Cung cấp thông tin/phối hợp với Trụ sở chính/cơ quan Nhà nước có thẩm quyền: Mức độ đơn giản', 5, 38.0::numeric, 38.0::numeric, 'Theo yêu cầu phát sinh'),
    (36, 'QLRR-036', 'Cung cấp thông tin/phối hợp với Trụ sở chính/cơ quan Nhà nước có thẩm quyền: Mức độ phức tạp', 5, 70.0::numeric, 70.0::numeric, 'Theo yêu cầu phát sinh'),
    (37, 'QLRR-037', 'Thực hiện báo cáo theo QĐ PCRT, PCRT, Tuân thủ FATCA', 5, 56.0::numeric, 56.0::numeric, 'Định kỳ/đột xuất'),
    (38, 'QLRR-038', 'Đề xuất tổ chức đào tạo/tham gia đào tạo về phòng, chống rửa tiền tại đơn vị.', 5, 56.0::numeric, 56.0::numeric, 'Theo kế hoạch'),
    (39, 'QLRR-039', 'Thực hiện chế độ báo cáo định kỳ/đột xuất theo quy định.', 5, 56.0::numeric, 56.0::numeric, 'Định kỳ/đột xuất'),
    (40, 'QLRR-040', 'Hỗ trợ phòng GDKH, QLKH & phòng liên quan t/hiện công tác PCRT/PCKB/Tuân thủ FATCA.', 5, 48.0::numeric, 48.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (41, 'QLRR-041', 'Lưu trữ hồ sơ, tài liệu các công việc liên quan', 5, 18.0::numeric, 18.0::numeric, 'Khi phát sinh'),
    (42, 'QLRR-042', 'Xây dựng kế hoạch duy trì hệ thống quản lý ISO/kế hoạch ĐLSHL/đánh giá nội bộ của CN', 6, 58.0::numeric, 58.0::numeric, 'Theo kế hoạch/phân giao'),
    (43, 'QLRR-043', 'T/hợp xây dựng/đánh giá Mục tiêu chất lượng, an toàn thông tin; ĐLSHL KH nội bộ', 6, 58.0::numeric, 58.0::numeric, 'Theo kế hoạch/phân giao'),
    (44, 'QLRR-044', 'Tổ chức đo lường sự hài lòng khách hàng bên ngoài/Tổ chức', 6, 58.0::numeric, 58.0::numeric, 'Khi phát sinh/theo phân công'),
    (45, 'QLRR-045', 'T/hợp danh mục TS an toàn thông tin/kết quả đánh giá /KH & kết quả XLRR an toàn thông tin.', 6, 68.0::numeric, 68.0::numeric, 'Khi phát sinh/theo phân công'),
    (46, 'QLRR-046', 'Đầu mối tiếp tổ chức chứng nhận/tiếp đoàn đánh giá nội bộ của TSC tại chi nhánh', 6, 68.0::numeric, 68.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (47, 'QLRR-047', 'Kiểm tra, BC kết quả khắc phục sau đánh giá nội bộ', 6, 56.0::numeric, 56.0::numeric, 'Khi phát sinh/theo phân công'),
    (48, 'QLRR-048', 'Tổng hợp kết quả áp dụng, duy trì các hệ thống quản lý ISO, đề xuất cải tiến', 6, 58.0::numeric, 58.0::numeric, 'Theo kế hoạch/phân giao'),
    (49, 'QLRR-049', 'Xây dựng và tổ chức thực hiện kế hoạch tự kiểm tra, kiểm soát nội bộ', 7, 70.0::numeric, 70.0::numeric, 'Thường xuyên/định kỳ'),
    (50, 'QLRR-050', 'Tham gia thực hiện kiểm tra theo kế hoạch hoặc chương trình theo yêu cầu của BIDV.', 7, 58.0::numeric, 58.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (51, 'QLRR-051', 'Theo dõi, giám sát,đôn đốc việc t/hiện các kiến nghị sau thanh tra, kiểm tra, kiểm toán của CN', 7, 58.0::numeric, 58.0::numeric, 'Thường xuyên/định kỳ'),
    (52, 'QLRR-052', 'T/hiện đầu mối/phối hợp với đơn vị có thẩm quyền tổ chức kiểm tra/thanh tra/kiểm toán tại CN', 7, 82.0::numeric, 82.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (53, 'QLRR-053', 'Đầu mối tiếp nhận, tham mưu cho Giám đốc CN xử lý các đơn thư khiếu nại, tố cáo phát sinh', 7, 68.0::numeric, 68.0::numeric, 'Theo kế hoạch/phân giao'),
    (54, 'QLRR-054', 'T/hiện giám sát công tác kho quỹ cuối ngày/cuối tháng và kiểm tra đột xuất ATKQ/ATM.', 7, 36.0::numeric, 36.0::numeric, 'Thường xuyên/định kỳ'),
    (55, 'QLRR-055', 'T/hiện báo cáo, thống kê liên quan đến hoạt động KTGS,tội phạm', 7, 48.0::numeric, 48.0::numeric, 'Định kỳ/đột xuất'),
    (56, 'QLRR-056', 'Đề xuất, trình lãnh đạo phê duyệt và giám sát thực hiện hạn mức phê duyệt trên chương trình', 8, 56.0::numeric, 56.0::numeric, 'Khi phát sinh hồ sơ'),
    (57, 'QLRR-057', 'T/hiện cung cấp thông tin KH phục vụ công tác quản lý, điều tra tội phạm', 8, 56.0::numeric, 56.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (58, 'QLRR-058', 'Đầu mối t/hiện hỗ trợ cưỡng chế thuế, hỗ trợ công tác thi hành án theo yêu cầu .', 8, 48.0::numeric, 48.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (59, 'QLRR-059', 'Thư ký Hội đồng tín dụng, Hội đồng cơ cấu nợ... theo quy định.', 8, 44.0::numeric, 44.0::numeric, 'Khi phát sinh/theo phân công'),
    (60, 'QLRR-060', 'Thực hiện các nhiệm vụ khác theo yêu cầu của lãnh đạo', 8, 39.0::numeric, 39.0::numeric, 'Khi phát sinh/theo phân công'),
    (61, 'QLRR-061', 'Tham gia định giá trực tiếp', 9, 48.0::numeric, 48.0::numeric, 'Khi phát sinh hồ sơ'),
    (62, 'QLRR-062', 'Đề xuất, trình duyệt giảm miễn lãi', 9, 48.0::numeric, 48.0::numeric, 'Khi phát sinh hồ sơ'),
    (63, 'QLRR-063', 'Đề xuất trình bán nợ', 9, 68.0::numeric, 68.0::numeric, 'Khi phát sinh hồ sơ'),
    (64, 'QLRR-064', 'Làm hồ sơ XLRR trình HSC', 9, 80.0::numeric, 80.0::numeric, 'Khi phát sinh hồ sơ'),
    (65, 'QLRR-065', 'Trình Xử lý tài sản', 9, 68.0::numeric, 68.0::numeric, 'Khi phát sinh hồ sơ'),
    (66, 'QLRR-066', 'Lập báo cáo xử lý tranh chấp theo định kỳ, đột xuất.', 9, 48.0::numeric, 48.0::numeric, 'Định kỳ/đột xuất'),
    (67, 'QLRR-067', 'Trình HSC xóa nợ khi có yêu cầu', 9, 80.0::numeric, 80.0::numeric, 'Khi phát sinh hồ sơ'),
    (68, 'QLRR-068', 'Các báo cáo định kỳ hoặc đột xuất khi có phân công', 9, 48.0::numeric, 48.0::numeric, 'Định kỳ/đột xuất'),
    (69, 'QLRR-069', 'Tham gia các dự án/tổ/nhóm ngoài nhiệm vụ thường xuyên', 9, 70.0::numeric, 70.0::numeric, 'Khi phát sinh/theo yêu cầu'),
    (70, 'QLRR-070', 'Lưu trữ hồ sơ', 9, 18.0::numeric, 18.0::numeric, 'Khi phát sinh'),
    (71, 'QLRR-071', 'Rà soát yêu cầu của đơn vị cần cung cấp, báo cáo lãnh đạoChi nhánh về nội dung cần cung cấp', 9, 36.0::numeric, 36.0::numeric, 'Định kỳ/đột xuất'),
    (72, 'QLRR-072', 'Trình cấp/sửa đổi/gia hạn hạn mức rủi ro tín dụng đối tác', 10, 68.0::numeric, 68.0::numeric, 'Khi phát sinh hồ sơ'),
    (73, 'QLRR-073', 'Phổ biến, triển khai thực hiện các văn bản chế độ, công văn hướng dẫn, cảnh báo của BIDV', 10, 46.0::numeric, 46.0::numeric, 'Theo văn bản ban hành'),
    (74, 'QLRR-074', 'Triển khai các công cụ và thực hiện các báo cáo theo Quy định', 10, 58.0::numeric, 58.0::numeric, 'Định kỳ/đột xuất'),
    (75, 'QLRR-075', 'Đề xuất thực hiện các biện pháp kiểm soát, khắc phục QLRRHĐ, QLRRCNTT tại Chi nhánh.', 10, 68.0::numeric, 68.0::numeric, 'Thường xuyên/định kỳ'),
    (76, 'QLRR-076', 'Lưu trữ, quản lý hồ sơ, tài liệu, dữ liệu của chi nhánh.', 10, 18.0::numeric, 18.0::numeric, 'Khi phát sinh'),
    (77, 'QLRR-077', 'Đề xuất tổ chức tự đào tạo/tham gia đào tạo tại chi nhánh', 10, 48.0::numeric, 48.0::numeric, 'Theo kế hoạch'),
    (78, 'QLRR-078', 'Công tác khác phát sinh chưa có trong danh mục', 11, 30.0::numeric, 30.0::numeric, 'Khi phát sinh')
  ) v(thu_tu, ma_cv, ten, ma_mang, diem_can_bo, diem_kiem_soat, tan_suat)
  join mang_cv mc on mc.department_id = v_pb and mc.ma_mang = v.ma_mang
  on conflict (ma_cv) do update set
    ten_cong_viec = excluded.ten_cong_viec, mang_cv_id = excluded.mang_cv_id,
    diem_can_bo = excluded.diem_can_bo, diem_kiem_soat = excluded.diem_kiem_soat,
    tan_suat = excluded.tan_suat, thu_tu = excluded.thu_tu, active = true;
end
$do$;

-- KIỂM TRA SAU KHI CHẠY (chỉ đọc). Mong đợi: QLRR = 11 mảng, 78 việc, 5 nhân sự; QLNB/QLKH giữ nguyên.
select d.ma_phong,
  (select count(*) from mang_cv m where m.department_id = d.id) as so_mang,
  (select count(*) from job_catalog j join mang_cv m on m.id = j.mang_cv_id where m.department_id = d.id and j.active) as so_viec_dang_dung,
  (select count(*) from employees e where e.department_id = d.id and e.active) as so_nhan_su
from departments d order by d.ma_phong;
