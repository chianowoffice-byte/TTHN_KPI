-- ============================================================================
-- CẬP NHẬT TOÀN BỘ DANH MỤC CÔNG VIỆC theo file "DS CÔNG VIỆC PHÒNG QLNB THEO 7541"
-- (415 việc, 8 mảng, 13 cán bộ). Sinh tự động từ file Excel.
--
-- Cách xử lý để KHÔNG mất lịch sử đã làm (daily_log tham chiếu job_catalog):
--   * Việc mới trùng (cùng mảng + cùng tên, bỏ mã đầu tên) với việc cũ -> GIỮ id cũ,
--     chỉ cập nhật mã/tên/điểm/tần suất (lịch sử nhật ký vẫn gắn đúng việc đó).
--   * Việc mới chưa có -> thêm mới.
--   * Việc cũ không còn trong danh sách mới: đã có người làm -> chuyển sang
--     "ngừng dùng" (active=false, mã đổi thành CU-...), vẫn xem được lịch sử;
--     chưa ai làm -> xoá hẳn.
--   * Thêm cột tần suất (job_catalog.tan_suat) -> bộ lọc "Tần suất" ở màn Hôm nay
--     dùng lại được (trước đây danh mục chuẩn không có cột này).
--   * Phân công mảng cho cán bộ theo đúng sheet "Cán bộ".
-- Chạy trong 1 giao dịch: lỗi ở đâu thì huỷ toàn bộ, không để dở dang.
-- Mã việc mới = <tiền tố>-<số thứ tự 3 chữ số theo thứ tự trong file>, vd KHTH-001.
-- ============================================================================

begin;

alter table job_catalog add column if not exists tan_suat text;

-- 1) Tên 8 mảng
insert into mang_cv (ma_mang, ten_mang) values
  (1, 'TỔ CHỨC – NHÂN SỰ'),
  (2, 'HÀNH CHÍNH – VĂN PHÒNG'),
  (3, 'KẾ HOẠCH – TỔNG HỢP'),
  (4, 'TÀI CHÍNH – KẾ TOÁN'),
  (5, 'CÔNG NGHỆ THÔNG TIN'),
  (6, 'TẠP VỤ'),
  (7, 'HOẠT ĐỘNG ĐOÀN THỂ'),
  (8, 'KHÁC')
on conflict (ma_mang) do update set ten_mang = excluded.ten_mang;

create function pg_temp.norm_ten(s text) returns text language sql immutable as $$
  select btrim(lower(regexp_replace(regexp_replace(btrim(s), '^(2023-)?[A-Za-z]+\s*[0-9]+\s*-\s*', ''), '\s+', ' ', 'g')), ' .')
$$;

-- 2) Danh sách việc mới (staging)
create temp table _new_cv (seq int, prefix text, ten text, ma_mang int, diem_can_bo numeric(6,2), diem_kiem_soat numeric(6,2), tan_suat text, ma_cv text) on commit drop;
insert into _new_cv (seq, prefix, ten, ma_mang, diem_can_bo, diem_kiem_soat, tan_suat) values
  (1, 'KHTH', 'Xây dựng KHKD năm', 3, 100.0::numeric, 100.0::numeric, 'Quý 4'),
  (2, 'KHTH', 'Xây dựng KHKD Quý', 3, 82.0::numeric, 82.0::numeric, 'Các Quý'),
  (3, 'KHTH', 'Phân giao KHKD năm tới các đơn vị', 3, 100.0::numeric, 100.0::numeric, 'Quý 4'),
  (4, 'KHTH', 'Phân giao KHKD Quý tới các đơn vị', 3, 82.0::numeric, 82.0::numeric, 'Các Quý'),
  (5, 'KHTH', 'Rà soát, điều chỉnh KHKD của Chi nhánh gửi Trụ sở chính', 3, 100.0::numeric, 100.0::numeric, 'Khi phát sinh'),
  (6, 'KHTH', 'Rà soát, điều chỉnh KHKD các Phòng tại Chi nhánh', 3, 70.0::numeric, 70.0::numeric, 'Khi phát sinh'),
  (7, 'KHTH', 'Đo lường, phân tích, báo cáo hiệu quả kinh doanh đa chiều. Rà soát, kiểm soát, đề xuất gia tăng nguồn thu', 3, 70.0::numeric, 70.0::numeric, 'Tháng/quý/năm/đột xuất'),
  (8, 'KHTH', 'Xây dựng tiêu chí, ban hành thông báo hướng dẫn xét HTNV tập thể và cá nhân tại chi nhánh', 3, 100.0::numeric, 100.0::numeric, 'Năm/khi có thay đổi'),
  (9, 'KHTH', 'Thực hiện xét HTNV tập thể và cá nhân Đánh giá kỳ Năm', 3, 100.0::numeric, 100.0::numeric, 'Hàng năm'),
  (10, 'KHTH', 'Thực hiện xét HTNV tập thể và cá nhân Đánh giá kỳ Quý', 3, 70.0::numeric, 70.0::numeric, 'Hàng quý'),
  (11, 'KHTH', 'Thực hiện chấm điểm đánh giá HTNV chi nhánh, điểm xếp hạng chi nhánh Đánh giá kỳ Năm', 3, 100.0::numeric, 100.0::numeric, 'Hàng năm'),
  (12, 'KHTH', 'Thực hiện chấm điểm đánh giá HTNV chi nhánh, điểm xếp hạng chi nhánh Đánh giá kỳ Quý', 3, 70.0::numeric, 70.0::numeric, 'Hàng quý'),
  (13, 'KHTH', 'Phối hợp trong công tác xếp hạng phòng giao dịch', 3, 70.0::numeric, 70.0::numeric, 'Định kỳ tháng, quý, năm'),
  (14, 'KHTH', 'Xây dựng, triển khai kế hoạch phát triển mạng lưới của Chi nhánh trung hạn/hàng năm (mở mới, chấm dứt hoạt động, thay đổi địa điểm,….);', 3, 70.0::numeric, 70.0::numeric, 'Năm/ Quý/ Khi có phát sinh'),
  (15, 'KHTH', 'Thực hiện các thủ tục trong công tác mạng lưới tại đơn vị theo phân công', 3, 8.8::numeric, 8.8::numeric, 'Khi phát sinh'),
  (16, 'KHTH', 'Công tác chi trả thu nhập nhập (lương năng suất, thưởng doanh số, KPI) theo phân công chi nhánh Đề xuất triển khai tại đơn vị', 3, 70.0::numeric, 70.0::numeric, 'Năm/ Quý/ Khi có phát sinh'),
  (17, 'KHTH', 'Thực hiện đánh giá, chi trả định kỳ thu nhập (lương năng suất, thưởng doanh số, KPI) hàng kỳ', 3, 10.0::numeric, 10.0::numeric, 'Định kỳ Quý'),
  (18, 'KHTH', 'Xây dựng văn bản chế độ liên quan đến chế độ tài chính, kế toán, phân cấp ủy quyền trong công tác tài chính kế toán tại chi nhánh', 3, 100.0::numeric, 100.0::numeric, 'Khi phát sinh'),
  (19, 'KHTH', 'Thực hiện phân tích, phân bổ chi phí đối với các bộ phận kinh doanh, bộ phận hỗ trợ phục vụ công tác quản trị điều hành', 3, 10.0::numeric, 10.0::numeric, 'Khi phát sinh'),
  (20, 'KHTH', 'Xây dựng chính sách, theo dõi, quản lý tài sản (giá trị)/vốn và các quỹ, tình hình thực hiện kế hoạch tài chính, định mức chi phí của chi nhánh', 3, 10.0::numeric, 10.0::numeric, 'Khi phát sinh'),
  (21, 'KHTH', 'Thực hiện tổng hợp, kê khai, quyết toán và nộp các loại thuế theo quy định. Quản lý và lập báo cáo tình hình thực hiện nghĩa vụ với NSNN', 3, 40.0::numeric, 40.0::numeric, 'Khi phát sinh'),
  (22, 'KHTH', 'Thẩm định, quản lý, tham gia ý kiến vào các phương án, dự toán mua sắm, chi tiêu', 3, 8.5::numeric, 8.5::numeric, 'Khi phát sinh'),
  (23, 'KHTH', '+ Tờ trình Ban lãnh đạo Cập nhật, theo dõi, triển khai các sản phẩm huy động vốn dân cư; lãi suất huy động vốn; điều hành vốn', 3, 52.0::numeric, 52.0::numeric, 'Khi phát sinh'),
  (24, 'KHTH', '+ Ban hành văn bản triển khai Cập nhật, theo dõi, triển khai các sản phẩm huy động vốn dân cư; lãi suất huy động vốn; điều hành vốn', 3, 7.9::numeric, 7.9::numeric, 'Khi phát sinh'),
  (25, 'KHTH', '+ Theo dõi, rà soát FTP tiền vay, LS tiền gửi', 3, 8.2::numeric, 8.2::numeric, NULL::text),
  (26, 'KHTH', '+ Tờ trình Ban lãnh đạo xây dựng, đề xuất chính sách khách hàng huy động vốn', 3, 52.0::numeric, 52.0::numeric, 'Đột xuất khi phát sinh'),
  (27, 'KHTH', '+ Ban hành văn bản triển khai chính sách khách hàng huy động vốn', 3, 7.9::numeric, 7.9::numeric, 'Đột xuất khi phát sinh'),
  (28, 'KHTH', 'Cài đặt lãi suất huy động vốn dân cư tại Chi nhánh', 3, 6.7::numeric, 6.7::numeric, 'Khi HSC có thay đổi lãi suất'),
  (29, 'KHTH', '+ Tờ trình Ban lãnh đạo TB lãi suất cho vay KHDN, theo dõi các gói cho vay ưu đãi', 3, 52.0::numeric, 52.0::numeric, 'Khi HSC có thay đổi lãi suất'),
  (30, 'KHTH', '+ Ban hành văn bản triển khai TB lãi suất cho vay KHDN, theo dõi các gói cho vay ưu đãi', 3, 7.9::numeric, 7.9::numeric, 'Khi HSC có thay đổi lãi suất'),
  (31, 'KHTH', 'Tờ trình Ban lãnh đạo đề xuất triển khai các quy định của TSC về lãi suất cho vay', 3, 52.0::numeric, 52.0::numeric, 'Đột xuất khi phát sinh'),
  (32, 'KHTH', 'Ban hành văn bản khai các quy định của TSC về lãi suất cho vay', 3, 7.9::numeric, 7.9::numeric, 'Đột xuất khi phát sinh'),
  (33, 'KHTH', '+ Theo dõi, rà soát FTP tiền vay, LS tiền vay', 3, 8.2::numeric, 8.2::numeric, 'Đột xuất khi phát sinh'),
  (34, 'KHTH', '- Tính toán, rà soát, đối chiếu cấp bù dự thu dự chi FTP định kỳ/đột xuất', 3, 8.2::numeric, 8.2::numeric, 'Định kỳ tháng, quý, năm/đột xuất khi phát sinh'),
  (35, 'KHTH', 'Ban hành biểu phí dịch vụ tại Chi nhánh', 3, 67.0::numeric, 67.0::numeric, 'Khi HSC có thay đổi biểu phí'),
  (36, 'KHTH', 'Đề xuất chính sách phí ưu đãi áp dụng cho KH trình Giám đốc/Hội đồng dịch vụ', 3, 10.0::numeric, 10.0::numeric, '-Định kỳ 6 tháng; Đột xuất khi phát sinh'),
  (37, 'KHTH', '- Quản lý trạng thái ngoại tệ của CN', 3, 6.4::numeric, 6.4::numeric, 'Hàng ngày'),
  (38, 'KHTH', '- Đăng ký nhu cầu giao dịch ngoại tệ, phái sinh của các Phòng và thực hiện đối ứng với HSC', 3, 6.4::numeric, 6.4::numeric, 'Hàng ngày'),
  (39, 'KHTH', '- Thông báo tỷ giá hàng ngày áp dụng tại Chi nhánh', 3, 4.0::numeric, 4.0::numeric, 'Hàng ngày'),
  (40, 'KHTH', '- Đầu mối/phối hợp với các bộ phận khác của CN để triển khai các công văn/sản phẩm liên quan đến nghiệp vụ KDVTT', 3, 64.0::numeric, 64.0::numeric, 'Khi có công văn hướng dẫn của HSC'),
  (41, 'TCKT', 'Giao dịch hạch toán thu nhập/chi phí từ TKTG theo đề nghị', 4, 2.2::numeric, 2.2::numeric, 'Ngày'),
  (42, 'TCKT', 'Giao dịch thẻ, thừa thiếu quỹ tiền mặt, thừa thiếu quỹ ATM', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (43, 'TCKT', 'Giao dịch chia sẻ phí', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (44, 'TCKT', 'Giao dịch phân bổ bảo lãnh', 4, 4.3::numeric, 4.3::numeric, 'Ngày'),
  (45, 'TCKT', 'Giao dịch tiền gửi', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (46, 'TCKT', 'Giao dịch XDCB (gồm sửa chữa lớn), quyết toán mua sắm TSCĐ, CCLĐ', 4, 10.0::numeric, 10.0::numeric, 'Ngày'),
  (47, 'TCKT', 'Giao dịch nhập/xuất kho, điều chuyển, thanh lý TS/CCLĐ', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (48, 'TCKT', 'Giao dịch sửa chữa TS/CCLĐ, mua bảo hiểm TS/CCLĐ', 4, 6.7::numeric, 6.7::numeric, 'Ngày'),
  (49, 'TCKT', 'Giao dịch tăng giảm TS/CCLĐ', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (50, 'TCKT', 'Giao dịch nhập/xuất tài sản thuê hoạt động', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (51, 'TCKT', 'Giao dịch chi quản lý công vụ chung', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (52, 'TCKT', 'Giao dịch Chi NCKH', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (53, 'TCKT', 'Giao dịch Chi nhân viên (trừ nộp/chi BHXH)', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (54, 'TCKT', 'Giao dịch liên quan đến quỹ thu nhập', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (55, 'TCKT', 'Nộp/chi bảo hiểm xã hội', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (56, 'TCKT', 'Giao dịch ấn chỉ, vật liệu', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (57, 'TCKT', 'Giao dịch chi Lễ tân khánh tiết', 4, 5.2::numeric, 5.2::numeric, 'Ngày'),
  (58, 'TCKT', 'Giao dịch chi tiếp thị, khuyến mại, hội nghị, hội thảo', 4, 10.0::numeric, 10.0::numeric, 'Ngày'),
  (59, 'TCKT', 'Giao dịch chi HHMG', 4, 9.7::numeric, 9.7::numeric, 'Ngày'),
  (60, 'TCKT', 'Giao dịch nộp thuế', 4, 8.5::numeric, 8.5::numeric, 'Ngày'),
  (61, 'TCKT', 'Giao dịch khác có độ phức tạp cao', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (62, 'TCKT', 'Giao dịch khác có độ phức tạp trung bình', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (63, 'TCKT', 'Giao dịch khác có độ phức tạp thấp', 4, 1.0::numeric, 1.0::numeric, 'Ngày'),
  (64, 'TCKT', '1.1 Kiểm soát Cân đối TKKT ngày', 4, 10.0::numeric, 10.0::numeric, 'Ngày'),
  (65, 'TCKT', '1.2 Kiểm soát Cân đối TKKT tháng', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (66, 'TCKT', '1.3 Kiểm soát Cân đối TKKT năm', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (67, 'TCKT', '2 Kiểm soát TK trung gian', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (68, 'TCKT', '3 Kiểm tra, đối chiếu số dư tài khoản TGTT với các TCTD khác (một số chi nhánh)', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (69, 'TCKT', '4.1 Kiểm soát các báo cáo Kế toán tổng hợp', 4, 7.0::numeric, 7.0::numeric, 'Ngày'),
  (70, 'TCKT', '4.2 Rà soát các biến động bất thường, nghi ngờ,... theo hướng dẫn tại từng thời kỳ của BIDV', 4, 7.0::numeric, 7.0::numeric, 'Khi phát sinh'),
  (71, 'TCKT', '4.3. Phối hợp với các phòng ban tại CN thực hiện điều chỉnh GL khi có yêu cầu', 4, 4.0::numeric, 4.0::numeric, 'Khi phát sinh'),
  (72, 'TCKT', '4.4. Kiểm soát công nợ phải thu, phải trả, theo dõi, quản lý và tổng hợp, báo cáo hàng kỳ đối với toàn bộ khoản công nợ trên chương trình quản lý công nợ', 4, 10.0::numeric, 10.0::numeric, 'Ngày'),
  (73, 'TCKT', '4.5 Kiểm soát số liệu kế toán khác (dự thu, dự chi, thu nhập chờ phân bổ, chi phí chờ phân bổ, các khoản mục ngoại bảng…)', 4, 98.0::numeric, 98.0::numeric, 'Tháng'),
  (74, 'TCKT', '5.Kiểm soát báo cáo khác', 4, 4.0::numeric, 4.0::numeric, 'Ngày'),
  (75, 'TCKT', 'Công tác tập hợp,lưu trữ chứng từ hàng ngày', 4, 7.3::numeric, 7.3::numeric, 'Ngày'),
  (76, 'TCKT', 'Công tác lưu trữ tài liệu, chứng từ kế toán chi nhánh', 4, 8.5::numeric, 8.5::numeric, 'Khi phát sinh'),
  (77, 'TCKT', 'Lập các loại báo cáo kế toán tài chính theo quy định của Nhà nước và cung cấp số liệu kế toán phục vụ công tác quản trị điều hành của chi nhánh', 4, 73.0::numeric, 73.0::numeric, 'Khi phát sinh'),
  (78, 'TCKT', 'Cung cấp/Giải trình tài liệu, số liệu kế toán phục vụ công tác thanh tra, kiểm tra, kiểm toán….', 4, NULL::numeric, 0.0::numeric, 'Khi phát sinh'),
  (79, 'TCKT', 'Cung cấp/Giải trình tài liệu, số liệu kế toán phục vụ công tác thanh tra, kiểm tra, kiểm toán….Độ phức tạp rất cao', 4, 100.0::numeric, 100.0::numeric, 'Khi phát sinh'),
  (80, 'TCKT', 'Cung cấp/Giải trình tài liệu, số liệu kế toán phục vụ công tác thanh tra, kiểm tra, kiểm toán….Độ phức tạp cao', 4, 70.0::numeric, 70.0::numeric, 'Khi phát sinh'),
  (81, 'TCKT', 'Cung cấp/Giải trình tài liệu, số liệu kế toán phục vụ công tác thanh tra, kiểm tra, kiểm toán….Độ phức tạp trung bình', 4, 40.0::numeric, 40.0::numeric, 'Khi phát sinh'),
  (82, 'TCKT', 'Cung cấp/Giải trình tài liệu, số liệu kế toán phục vụ công tác thanh tra, kiểm tra, kiểm toán….Độ phức tạp thấp', 4, 10.0::numeric, 10.0::numeric, 'Khi phát sinh'),
  (83, 'TCKT', 'Lập/ Kiểm soát báo cáo quyết toán năm', 4, 10.0::numeric, 10.0::numeric, 'Khi phát sinh'),
  (84, 'TCKT', 'Triển khai công tác quyết toán hàng năm', 4, 82.0::numeric, 82.0::numeric, 'Khi phát sinh'),
  (85, 'TCKT', 'Triển khai các chương trình phần mềm TCKT theo hướng dẫn của TSC', 4, 40.0::numeric, 40.0::numeric, 'Khi phát sinh'),
  (86, 'TCKT', 'Triển khai các văn bản, chế độ, quy định về TCKT tại đơn vị', 4, 82.0::numeric, 82.0::numeric, 'Khi phát sinh'),
  (87, 'KHTH', 'Báo cáo kết quả hoạt động kinh doanh Chi nhánh hàng ngày', 3, 10.0::numeric, 10.0::numeric, 'Hàng ngày'),
  (88, 'KHTH', 'Báo cáo kết quả hoạt động kinh doanh Chi nhánh hàng tháng', 3, 70.0::numeric, 70.0::numeric, 'Tháng'),
  (89, 'KHTH', 'Báo cáo kết quả hoạt động kinh doanh Chi nhánh hàng quý/6 tháng/năm', 3, 100.0::numeric, 100.0::numeric, 'Quý'),
  (90, 'KHTH', '- Báo cáo tình hình hoạt động của các phòng nghiệp vụ hàng tháng', 3, 40.0::numeric, 40.0::numeric, 'Tháng'),
  (91, 'KHTH', '- Thu thập thông tin địa bàn, chính sách giá phí của đối thủ cạnh tranh định kỳ 6 tháng/lần', 3, 100.0::numeric, 100.0::numeric, '6 tháng'),
  (92, 'KHTH', '- Báo cáo thống kê thông tư 11', 3, 10.0::numeric, 10.0::numeric, 'Tháng/quý'),
  (93, 'KHTH', 'Báo cáo đột xuất theo yêu cầu của Lãnh đạo Chi nhánh, Trụ sở chính Độ phức tạp rất cao', 3, 100.0::numeric, 100.0::numeric, 'Đột xuất khi có yêu cầu'),
  (94, 'KHTH', 'Báo cáo đột xuất theo yêu cầu của Lãnh đạo Chi nhánh, Trụ sở chính Độ phức tạp cao', 3, 70.0::numeric, 70.0::numeric, 'Đột xuất khi có yêu cầu'),
  (95, 'KHTH', 'Báo cáo đột xuất theo yêu cầu của Lãnh đạo Chi nhánh, Trụ sở chính Độ phức tạp trung bình', 3, 40.0::numeric, 40.0::numeric, 'Đột xuất khi có yêu cầu'),
  (96, 'KHTH', 'Báo cáo đột xuất theo yêu cầu của Lãnh đạo Chi nhánh, Trụ sở chính Độ phức tạp thấp', 3, 10.0::numeric, 10.0::numeric, 'Đột xuất khi có yêu cầu'),
  (97, 'KHTH', 'Báo cáo ngoại ngành Độ phức tạp rất cao', 3, 100.0::numeric, 100.0::numeric, 'Đột xuất khi có yêu cầu'),
  (98, 'KHTH', 'Báo cáo ngoại ngành Độ phức tạp cao', 3, 70.0::numeric, 70.0::numeric, 'Đột xuất khi có yêu cầu'),
  (99, 'KHTH', 'Báo cáo ngoại ngành Độ phức tạp trung bình', 3, 40.0::numeric, 40.0::numeric, 'Đột xuất khi có yêu cầu'),
  (100, 'KHTH', 'Báo cáo ngoại ngành Độ phức tạp thấp', 3, 10.0::numeric, 10.0::numeric, 'Đột xuất khi có yêu cầu'),
  (101, 'KHTH', 'Trình, ban hành văn bản triển khai công tác đánh giá cán bộ, hướng dẫn thực hiện trên PM tại đơn vị', 3, 82.0::numeric, 82.0::numeric, 'Khi phát sinh'),
  (102, 'KHTH', 'Trình ban hành mới Bộ chỉ tiêu BSC phòng, KPIs cán bộ áp dụng tại đơn vị', 3, 82.0::numeric, 82.0::numeric, 'Khi HSC ban hành mới'),
  (103, 'KHTH', 'Trình điều chỉnh, cập nhật Bộ chỉ tiêu BSC phòng, KPIs cán bộ áp dụng tại đơn vị', 3, 10.0::numeric, 10.0::numeric, 'Khi HSC thông báo/CN thay đổi'),
  (104, 'KHTH', 'Thực hiện quy trình ĐGCB trên PS kỳ Quý', 3, 82.0::numeric, 82.0::numeric, 'Hàng quý'),
  (105, 'KHTH', 'Thực hiện quy trình ĐGCB trên PS kỳ 6 tháng/năm', 3, 100.0::numeric, 100.0::numeric, '6 tháng / năm'),
  (106, 'KHTH', 'Phối hợp rà soát dữ liệu đánh giá cán bộ các vị trí tác nghiệp, TDS...', 3, 10.0::numeric, 10.0::numeric, 'Theo kỳ đánh giá'),
  (107, 'KHTH', 'Tổng hợp nội dung trình phê duyệt kết quả Thi Đua hàng quý/6 tháng/năm', 3, 100.0::numeric, 100.0::numeric, 'Hàng tháng/ quý/ năm'),
  (108, 'KHTH', 'Tổng hợp nội dung Thông báo kết luận họp giao ban/họp chuyên đề', 3, 70.0::numeric, 70.0::numeric, 'Hàng tuần'),
  (109, 'KHTH', 'Theo dõi cơ chế động lực của HSC', 3, 8.8::numeric, 8.8::numeric, 'Hàng quý'),
  (110, 'KHTH', 'Ban hành văn bản phát động thi đua tại Chi nhánh', 3, 82.0::numeric, 82.0::numeric, '6 tháng'),
  (111, 'KHTH', 'Thực hiện khen thưởng tới các phòng nghiệp vụ', 3, 10.0::numeric, 10.0::numeric, 'Hàng quý/ năm'),
  (112, 'KHTH', 'Theo dõi rà soát công tác gán AM RM của các phòng nghiệp vụ', 3, 10.0::numeric, 10.0::numeric, 'Hàng tuần'),
  (113, 'TCKT', 'Mở khóa kho tiền theo phân công của Lãnh đạo', 4, 5.2::numeric, 5.2::numeric, 'Ngày'),
  (114, 'TCKT', 'Tham gia các Tổ kiểm tra nội bộ, Tổ công tác khác', 4, 10.0::numeric, 10.0::numeric, 'Khi phát sinh'),
  (115, 'TCKT', 'Xuất hóa đơn thủ công', 4, 4.0::numeric, 4.0::numeric, 'Khi phát sinh'),
  (116, 'TCKT', 'Tham gia công tác kiểm kê (ấn chỉ, tài sản đảm bảo, tài sản…)', 4, 4.3::numeric, 4.3::numeric, 'Hàng tháng/quý/năm'),
  (117, 'KHAC', 'Công tác khác Độ phức tạp rất cao', 8, 10.0::numeric, 10.0::numeric, 'Khi phát sinh'),
  (118, 'KHAC', 'Công tác khác Độ phức tạp cao', 8, 7.0::numeric, 7.0::numeric, 'Khi phát sinh'),
  (119, 'KHAC', 'Công tác khác Độ phức tạp trung bình', 8, 4.0::numeric, 4.0::numeric, 'Khi phát sinh'),
  (120, 'KHAC', 'Công tác khác Độ phức tạp thấp', 8, 1.0::numeric, 1.0::numeric, 'Khi phát sinh'),
  (121, 'TCNS', 'Ban hành Thông báo tới các phòng v/v đề xuất/bổ sung quy hoạch cán bộ (các phòng đề xuất có ý kiến của Phó Giám đốc phụ trách)', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (122, 'TCNS', 'Tổng hợp nhu cầu của các phòng, chuẩn bị tài liệu họp', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (123, 'TCNS', 'Tổ chức họp Hội nghị liên tịch thông qua danh sách tổng hợp quy hoạch', 1, 9.4::numeric, 9.4::numeric, NULL::text),
  (124, 'TCNS', 'Tổ chức họp và bỏ phiếu tại Hội nghị cán bộ', 1, 6.4::numeric, 6.4::numeric, NULL::text),
  (125, 'TCNS', 'Tổ chức họp Hội nghị liên tịch để thống nhất danh sách đề nghị quy hoạch', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (126, 'TCNS', 'Lập hồ sơ quy hoạch gửi HO báo cáo hoặc xin ý kiến phê duyệt', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (127, 'TCNS', 'Thông báo/phổ biến kết quả quy hoạch', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (128, 'TCNS', 'Cập nhật trên chương trình QLNS', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (129, 'TCNS', 'Lưu hồ sơ quy hoạch', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (130, 'TCNS', 'Lập kế hoạch đào tạo, bồi dưỡng, luân chuyển đối với cán bộ được phê duyệt quy hoạch.', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (131, 'TCNS', 'Căn cứ định biên số lượng lãnh đạo tại đơn vị và nhu cầu bổ sung, phòng TCHC rà soát, xác định nhu cầu bổ nhiệm, bổ nhiệm lại báo cáo Giám đốc', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (132, 'TCNS', 'Dự kiến nhân sự được bổ nhiệm báo cáo Giám đốc', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (133, 'TCNS', 'Tổ chức họp Hội nghị liên tịch họp thông qua chủ trương bổ sung nhu cầu nhân sự bổ nhiệm và nhân sự được bổ nhiệm, nhận xét đánh giá cán bộ được bổ nhiệm', 1, 5.5::numeric, 5.5::numeric, NULL::text),
  (134, 'TCNS', 'Lập biên bản cuộc họp Hội nghị liên tịch ký các thành viên cuộc họp', 1, 7.9::numeric, 7.9::numeric, NULL::text),
  (135, 'TCNS', 'Gửi văn bản xin ý kiến phê duyệt của HO về việc bổ nhiệm cán bộ (nếu có)', 1, 9.7::numeric, 9.7::numeric, NULL::text),
  (136, 'TCNS', 'Chuẩn bị phiếu đích danh và Lấy phiếu trong Cấp ủy và phòng có cán bộ dự kiến được bổ nhiệm', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (137, 'TCNS', 'Lập Tờ trình báo cáo Giám đốc về tỷ lệ phiếu, đề xuất bổ nhiệm và ra Quyết định bổ nhiệm', 1, 8.2::numeric, 8.2::numeric, NULL::text),
  (138, 'TCNS', 'Công bố quyết định và lưu toàn bộ hồ sơ bổ nhiệm theo quy định', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (139, 'TCNS', 'Theo dõi, xác định kế hoạch điều động luân chuyển thuộc diện quy hoạch, cán bộ thuộc diện luân chuyển đến hạn luân chuyển', 1, 8.2::numeric, 8.2::numeric, NULL::text),
  (140, 'TCNS', 'Căn cứ tình hình nhân sự của các phòng, phòng TCHC đề xuất điều động luân chuyển đối với cán bộ.', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (141, 'TCNS', 'Lập tờ trình đề xuất với Lãnh đạo về việc điều động, luân chuyển.', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (142, 'TCNS', 'Công bố quyết định và lưu toàn bộ hồ sơ điều động, luân chuyển theo quy định', 1, 5.5::numeric, 5.5::numeric, NULL::text),
  (143, 'TCNS', 'Tổ chức Họp hội nghị liên tịch đối với trường hợp điều động cán bộ giữ chức vụ', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (144, 'TCNS', 'Lập biên bản cuộc họp Hội nghị liên tịch ký các thành viên cuộc họp đối với trường hợp điều động cán bộ giữ chức vụ', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (145, 'TCNS', 'Thực hiện tờ trình về việc xây dựng định biên lao động của đơn vị trên cơ sở công văn hướng dẫn của Hội Sở chính', 1, 70.0::numeric, 70.0::numeric, NULL::text),
  (146, 'TCNS', 'Họp liên tịch Cấp ủy, Ban Giám đốc, BCH Công đoàn thống nhất kế hoạch định biên lao động', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (147, 'TCNS', 'Gửi hồ sơ đề nghị phê duyệt định biên lao động lên Hội Sở chính trên cơ sở nội dung thống nhất tại cuộc họp liên tịch', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (148, 'TCNS', 'Căn cứ định biên được phê duyệt đăng ký nhu cầu tuyển dụng và có kế hoạch tuyển dụng', 1, 9.7::numeric, 9.7::numeric, NULL::text),
  (149, 'TCNS', 'Tiến hành các thủ tục trước khi thực hiện tuyển dụng (trình kế hoạch, phương án, hình thức tuyển dụng, thành lập Hội đồng tuyển dụng)', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (150, 'TCNS', 'Thông báo tuyển dụng (Báo đài, Website, VPĐT, dán thông báo tại Trụ sở chi nhánh...)', 1, 7.9::numeric, 7.9::numeric, NULL::text),
  (151, 'TCNS', 'Tiếp nhận Hồ sơ, chọn lựa ứng viên và trình Hội đồng tuyển dụng danh sách thí sinh đạt tiêu chí', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (152, 'TCNS', 'Tổ chức thi vòng 2 (thi viết): Chuẩn bị hồ sơ, tài liệu, địa điểm thi, tổng hợp đề thi (nếu có).', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (153, 'TCNS', 'Công bố kết quả thi vòng 2: Tổng hợp kết quả, biên bản và thông báo trong nội bộ, thông báo trên phương tiện truyền thông, thông báo cho thí sinh trúng tuyển.', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (154, 'TCNS', 'Tổ chức thi vòng 3 (phỏng vấn): Chuẩn bị hồ sơ, tài liệu, địa điểm thi, tổng hợp đề thi (nếu có).', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (155, 'TCNS', 'Công bố kết quả thi vòng 3: Tổng hợp kết quả, biên bản và thông báo trong nội bộ, thông báo trên phương tiện truyền thông, thông báo cho thí sinh trúng tuyển.', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (156, 'TCNS', 'Gửi HO kết quả tuyển dụng, trình Giám đốc ra quyết định tuyển dụng, ký kết hợp đồng và xếp lương cho cho cán bộ mới', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (157, 'TCNS', 'Thông báo gặp mặt và phân công cán bộ mới', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (158, 'TCNS', 'Cập nhật dữ liệu trên chương trình QLNS và lưu hồ sơ tuyển dụng theo quy định', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (159, 'TCNS', 'Công bố danh sách thí sinh thi tuyển tập trung có nguyện vọng vào làm việc tại Chi nhánh (trường hợp tuyển dụng tập trung)', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (160, 'TCNS', 'Lên kế hoạch đào tạo (tháng, quý, năm).', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (161, 'TCNS', 'Theo dõi cập nhật kịp thời các chương trình đào tạo của Hội sở chính', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (162, 'TCNS', 'Thực hiện các thủ tục cử cán bộ tham gia đào tạo (thông báo khóa học, tổng hợp và trình cán bộ tham gia, đăng ký trên phần mềm, ....)', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (163, 'TCNS', 'Thực hiện các thủ tục triển khai đào tạo (Trình tổ chức khóa học, liên lạc đối tác, thông báo khóa học, mượn hội trường....).', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (164, 'TCNS', 'Tổ chức và quản lý lớp học theo đúng quy chế đào tạo của BIDV và của đơn vị.', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (165, 'TCNS', 'Thực hiện thanh toán chi phí và phân bổ chi phí liên quan tới đào tạo.', 1, 5.5::numeric, 5.5::numeric, NULL::text),
  (166, 'TCNS', 'Cập nhật chứng chỉ đào tạo trên chương trình QLNS và lưu hồ sơ cán bộ', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (167, 'TCNS', 'Báo cáo, đề xuất về công tác đào tạo (theo khóa học, theo định kỳ hoặc theo yêu cầu của lãnh đạo)', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (168, 'TCNS', 'Thực hiện công tác chấm công (đôn đốc, theo dõi và lưu hồ sơ chấm công, nghỉ phép, nghỉ chế độ BHXH, nghỉ KL... của các phòng hàng tháng, thực hiện chấm công của phòng TCHC và Ban giám đốc.', 1, 5.5::numeric, 5.5::numeric, NULL::text),
  (169, 'TCNS', 'Thực hiện thu chi lương hàng tháng: Lập bảng kê thu chi lương, truy thu, truy lĩnh lương, thực hiện thu chi lương, các khoản khác (BHXH, thuế, thu các quỹ,…) trên chương trình Tính toán và quản lý dữ liệu lương, thu nhập tập trung.', 1, 8.2::numeric, 8.2::numeric, NULL::text),
  (170, 'TCNS', 'Thực hiện công tác thu chi khác: Chi động viên đối với cán bộ nhân các ngày Lễ, Tết, kỷ niệm; Chi bổ sung quỹ thu nhập, chi làm thêm giờ, truy thu truy lĩnh khác...', 1, 8.2::numeric, 8.2::numeric, NULL::text),
  (171, 'TCNS', 'Theo dõi cập nhật lao động bình quân, hệ số lương bảo hiểm bình quân, lương vị trí bình quân, hệ số lương chi nhánh (tháng/quý/năm).', 1, 5.5::numeric, 5.5::numeric, NULL::text),
  (172, 'TCNS', 'Theo dõi và tổng hợp thu nhập của cán bộ hàng tháng phục vụ tính thuế thu nhập cá nhân.', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (173, 'TCNS', 'Theo dõi xếp lương, điều chỉnh lương, nâng bậc lương định kỳ đối với cán bộ và thực hiện các thủ tục xếp lương, điều chỉnh lương, nâng bậc lương đinh kỳ đối với cán bộ.', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (174, 'TCNS', 'Lập các báo cáo liên quan tới tiền lương (các báo cáo phối hợp liên phòng, báo cáo Ban lãnh đạo, báo cáo TSC, báo cáo lao động tiền lương phục vụ hội nghị, hội thảo, Đảng, công đoàn...)', 1, 82.0::numeric, 82.0::numeric, NULL::text),
  (175, 'TCNS', 'Tham gia vận hành chương trình nhân sự: nhập các dữ liệu liên quan đến công tác tiền lương (Cấp, bậc, hệ số sau khi xếp lương định kỳ,…)', 1, 6.4::numeric, 6.4::numeric, NULL::text),
  (176, 'TCNS', 'Theo dõi và khai báo tăng giảm bảo hiểm trên Chương trình bảo hiểm đối với cán bộ mới, cán bộ nghỉ thai sản, nghỉ ốm đau…', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (177, 'TCNS', 'Thanh toán chế độ bảo hiểm hàng tháng (trích nộp BH theo quy định, thanh toán ốm đau, thai sản...)', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (178, 'TCNS', 'Tính tạm ứng và đóng tiền bảo hiểm hàng tháng', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (179, 'TCNS', 'Chốt sổ BH/ Thay đổi thẻ BHYT', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (180, 'TCNS', 'Hướng dẫn cán bộ trong công tác BHXH, BHYT, BHTN', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (181, 'TCNS', 'Thực hiện các báo cáo và lưu hồ sơ', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (182, 'TCNS', 'Cập nhật thay đổi danh sách cán bộ đóng bảo hiểm BIDV BIC, BIDV Care theo kế hoạch hoặc theo yêu cầu và gửi danh sách sang BIC.', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (183, 'TCNS', 'Cập nhật thay đổi danh sách người thân đóng bảo hiểm BIDV BIC, BIDV Care theo kế hoạch hoặc theo yêu cầu và gửi danh sách sang BIC.', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (184, 'TCNS', 'Thực hiện thanh toán chi phí và phân tách chi phí tới các đơn vị (BIC CARE, BIDV CARE,…)', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (185, 'TCNS', 'Hướng dẫn cán bộ trong công tác BH BIC, BH BIDV Care', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (186, 'TCNS', 'Có kế hoạch, thông báo, hướng dẫn công tác thi đua khen thưởng', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (187, 'TCNS', 'Phối hợp với các phòng liên quan trong việc nhận xét, đánh giá ,đề xuất và hoàn thiện hồ sơ thi đua khen thưởng', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (188, 'TCNS', 'Tổ chức họp Hội đồng Thi đua khen thưởng xét duyệt đối với các trường hợp đề xuất; Có ý kiến tham mưu đối với danh sách TĐKT đảm bảo đúng quy định. Hoàn thành biên bản thi đua khen thưởng với danh sách TĐKT được Hội đồng phê duyệt.', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (189, 'TCNS', 'Thông báo kết quả Thi đua khen thưởng tới các Cá nhân/đơn vị', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (190, 'TCNS', 'Trực tiếp thực hiện các thủ tục ra quyết định khen thưởng hoặc phối hợp ra quyết định khen thưởng trong thẩm quyền của Giám đốc', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (191, 'TCNS', 'Gửi đề xuất khen thưởng lên HO đối với khen thưởng vượt thẩm quyền của Giám đốc', 1, 8.8::numeric, 8.8::numeric, NULL::text),
  (192, 'TCNS', 'Phối hợp với HO hoàn thiện các hồ sơ khen thưởng cho tập thể, cá nhân', 1, 8.8::numeric, 8.8::numeric, NULL::text),
  (193, 'TCNS', 'Tiếp nhận và chuyển giao các chứng nhận khen thưởng hoặc phối hợp trong công tác tổ chức khen thưởng.', 1, 5.2::numeric, 5.2::numeric, NULL::text),
  (194, 'TCNS', 'Tổng hợp báo cáo công tác thi đua khen thưởng theo kế hoạch hoặc theo yêu cầu của lãnh đạo', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (195, 'TCNS', 'Tư vấn, đề xuất đảm bảo công tác thi đua khen thưởng được công bằng, hiệu quả.', 1, 82.0::numeric, 82.0::numeric, NULL::text),
  (196, 'TCNS', 'Lưu hồ sơ khen thưởng theo quy định', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (197, 'TCNS', 'Hướng dẫn và triển khai các thủ tục ký, tạm hoãn HĐLĐ, nghỉ không lương, Chấm dứt HĐLĐ đối với cán bộ', 1, 7.3::numeric, 7.3::numeric, NULL::text),
  (198, 'TCNS', 'Theo dõi danh sách cán bộ đang tạm hoãn HĐLĐ, nghỉ không lương và tiếp nhận cán bộ đi làm trở lại', 1, 4.0::numeric, 4.0::numeric, NULL::text),
  (199, 'TCNS', 'Theo dõi và đánh giá năng lực cán bộ', 1, 8.8::numeric, 8.8::numeric, NULL::text),
  (200, 'TCNS', 'Thực hiện rà soát và hoàn tất các thủ tục liên quan đến chế độ người lao động khi được điều động đến và đi đơn vị khác cùng hệ thống (giấy thôi trả lương, quyết định tiếp nhận/chuyển công tác, bàn giao hồ sơ cán bộ…)', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (201, 'TCNS', 'Phối hợp thực hiện, rà soát, đề xuất thay đổi liên quan tới mô hình tổ chức (thành lập, giải thể, thay đổi)', 1, 82.0::numeric, 82.0::numeric, NULL::text),
  (202, 'TCNS', 'Phối hợp thực hiện, rà soát, đề xuất thay đổi liên quan tới chức năng nhiệm vụ các phòng/ban', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (203, 'TCNS', 'Ban hành các quyết định về Mô hình tổ chức, chức năng nhiệm vụ của các phòng ban.', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (204, 'TCNS', 'Cập nhật dữ liệu liên quan đến mô hình tổ chức trên chương trình QLNS', 1, 6.7::numeric, 6.7::numeric, NULL::text),
  (205, 'TCNS', 'Thực hiện công tác tổng hợp sáng kiến cấp cơ sở, tổ chức họp Hội đồng sáng kiến, trình cấp có thẩm quyền phê duyệt và gửi đề xuất sáng kiến Cấp hệ thống', 1, 10.0::numeric, 10.0::numeric, NULL::text),
  (206, 'TCNS', 'Công tác kỷ luật', 1, 8.8::numeric, 8.8::numeric, NULL::text),
  (207, 'TCNS', 'Công tác cổ phần cổ phiếu', 1, 4.3::numeric, 4.3::numeric, NULL::text),
  (208, 'TCNS', 'Soạn thảo QĐ thành lập tổ trên cơ sở đề xuất của các phòng', 1, 4.3::numeric, 4.3::numeric, NULL::text),
  (209, 'TCNS', 'Có kế hoạch khám sức khỏe cho cán bộ.', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (210, 'TCNS', 'Thực hiện các thủ tục khám sức khỏe cho cán bộ (trình chủ chương, thông báo tới cán bộ, hướng dẫn và tổng hợp yêu cầu,...).', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (211, 'TCNS', 'Thực hiện các thủ tục đấu thầu và chọn lựa đơn vị khám sức khỏe cho cán bộ.', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (212, 'TCNS', 'Phối hợp đơn vị được chọn tổ chức khám sức khỏe cho cán bộ.', 1, 5.8::numeric, 5.8::numeric, NULL::text),
  (213, 'TCNS', 'Thanh toán các chi phí liên quan tới khám sức khỏe cho cán bộ', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (214, 'TCNS', 'Tổng hợp báo cáo và đề xuất', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (215, 'TCNS', 'Có kế hoạch mua sắm trang phục cho cán bộ.', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (216, 'TCNS', 'Thực hiện các thủ tục mua sắm trang phục cho cán bộ (trình chủ chương, thông báo tới cán bộ, hướng dẫn và tổng hợp yêu cầu,...).', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (217, 'TCNS', 'Thực hiện các thủ tục đấu thầu và chọn lựa đơn vị cung cấp trang phục cho cán bộ.', 1, 8.5::numeric, 8.5::numeric, NULL::text),
  (218, 'TCNS', 'Thanh toán các chi phí liên quan tới mua sắm trang phục cho cán bộ', 1, 7.0::numeric, 7.0::numeric, NULL::text),
  (219, 'HCVP', 'Lập kế hoạch mua sắm, trang bị TS, CCLĐ', 2, 10.0::numeric, 10.0::numeric, NULL::text),
  (220, 'HCVP', 'Lập kế hoạch kiểm kê TS, CCLĐ', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (221, 'HCVP', 'Lập kế hoạch thanh lý TS, CCLĐ', 2, 10.0::numeric, 10.0::numeric, NULL::text),
  (222, 'HCVP', 'Lập kế hoạch bảo trì, bảo dưỡng TS, CCLĐ', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (223, 'HCVP', 'Đề xuất sửa chữa TS, CCLĐ', 2, 8.5::numeric, 8.5::numeric, NULL::text),
  (224, 'HCVP', 'Triển khai các thủ tục mua sắm TS, CCLĐ', 2, 10.0::numeric, 10.0::numeric, NULL::text),
  (225, 'HCVP', 'Triển khai các thủ tục kiểm kê TS, CCLĐ', 2, 8.5::numeric, 8.5::numeric, NULL::text),
  (226, 'HCVP', 'Triển khai các thủ tục thanh lý TS, CCLĐ', 2, 10.0::numeric, 10.0::numeric, NULL::text),
  (227, 'HCVP', 'Triển khai các thủ tục sửa chữa TS, CCLĐ', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (228, 'HCVP', 'Triển khai các thủ tục bảo trì, bảo dưỡng TS, CCLĐ', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (229, 'HCVP', 'Theo dõi quản lý TS,CCLĐ theo đúng quy định, đảm bảo cân đối giữa sổ sách và thực tế', 2, 5.5::numeric, 5.5::numeric, NULL::text),
  (230, 'HCVP', 'Thực hiện các thủ tục giao nhận TS, CCLĐ đúng theo quy định về Quản lý sử dụng TS của BIDV, lưu đầy đủ hồ sơ liên quan.', 2, 5.2::numeric, 5.2::numeric, NULL::text),
  (231, 'HCVP', 'Chủ động và phối hợp trong công tác đánh giá hiện trạng TS, CCLĐ, có biện pháp xử lý sau đánh giá', 2, 8.8::numeric, 8.8::numeric, NULL::text),
  (232, 'HCVP', 'Thực hiện các báo cáo về TS, CCLĐ theo yêu cầu của lãnh đạo', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (233, 'HCVP', 'Thực hiện các thủ tục thanh toán các chi phí liên quan tới mua sắm, sửa chữa TS, CCLĐ', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (234, 'HCVP', 'Thực hiện các thủ tục thanh toán các chi phí liên quan tới thuê mua TS', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (235, 'HCVP', 'Thực hiện các thủ tục thanh toán các chi phí liên quan tới sử dụng dịch vụ phục vụ hoạt động kinh doanh', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (236, 'HCVP', 'Thực hiện tốt nhiệm vụ tại các Tổ mua sắm, nghiệm thu, tổ thẩm định theo quyết định của Giám đốc', 2, 8.8::numeric, 8.8::numeric, NULL::text),
  (237, 'HCVP', 'Lưu hồ sơ TS, CCLĐ theo quy định', 2, 4.0::numeric, 4.0::numeric, NULL::text),
  (238, 'HCVP', 'Có kế hoạch trong công tác đầu tư xây dựng cơ bản (sửa chữa, thiết kế, trang bị cơ sở vật chất, nội ngoại thất...)', 2, 8.5::numeric, 8.5::numeric, NULL::text),
  (239, 'HCVP', 'Triển khai các thủ tục cải tạo, sửa chữa cơ sở vật chất', 2, 10.0::numeric, 10.0::numeric, NULL::text),
  (240, 'HCVP', 'Giám sát việc sửa chữa, trang bị nội ngoại thất theo kế hoạch và theo phát sinh được Ban lãnh đạo phê duyệt', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (241, 'HCVP', 'Chủ động và phối hợp trong công tác đánh giá hiện trạng cơ sở vật chất tuân thủ nhận diện thương hiệu và có biện pháp, đề xuất sau đánh giá', 2, 8.8::numeric, 8.8::numeric, NULL::text),
  (242, 'HCVP', 'Thực hiện các báo cáo về Đầu tư xây dựng cơ bản theo yêu cầu của lãnh đạo', 2, 58.0::numeric, 58.0::numeric, NULL::text),
  (243, 'HCVP', 'Thực hiện tốt nhiệm vụ tại Ban quản lý công trình theo quyết định của Giám đốc', 2, 8.8::numeric, 8.8::numeric, NULL::text),
  (244, 'HCVP', 'Lưu hồ sơ đầu tư xây dựng cơ bản theo quy định', 2, 4.0::numeric, 4.0::numeric, NULL::text),
  (245, 'HCVP', 'Lập kế hoạch mua sắm và sử dụng VPP, Ấn chỉ thường', 2, 8.8::numeric, 8.8::numeric, NULL::text),
  (246, 'HCVP', 'Thực hiện các thủ tục mua sắm VPP và Ấn chỉ thường theo kế hoạch và theo phát sinh được Ban lãnh đạo phê duyệt', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (247, 'HCVP', 'Theo dõi và quản lý kho ấn chỉ đảm bảo cân đối giữa sổ sách và thực tế', 2, 5.8::numeric, 5.8::numeric, NULL::text),
  (248, 'HCVP', 'Thực hiện các thủ tục giao nhận đúng quy định và lưu đầy đủ hồ sơ liên quan', 2, 5.2::numeric, 5.2::numeric, NULL::text),
  (249, 'HCVP', 'Thực hiện thanh toán các chi phí liên quan tới VPP, Ấn chỉ thường', 2, 5.5::numeric, 5.5::numeric, NULL::text),
  (250, 'HCVP', 'Chủ động và phối hợp tốt trong công tác đánh giá hiệu quả sử dụng VPP và Ấn chỉ thường', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (251, 'HCVP', 'Thực hiện báo cáo và phối hợp báo cáo theo yêu cầu của lãnh đạo', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (252, 'HCVP', 'Thực hiện tốt nhiệm vụ khi tham gia Tổ mua sắm, tổ nghiệm thu, Tổ thẩm định theo quyết định của Giám đốc', 2, 8.8::numeric, 8.8::numeric, NULL::text),
  (253, 'HCVP', 'Lưu hồ sơ mua sắm theo quy định', 2, 4.0::numeric, 4.0::numeric, NULL::text),
  (254, 'HCVP', 'Thực hiện công tác hậu cần khi lãnh đạo đi công tác(Lo ăn ở, đặt vé máy bay....)', 2, 5.5::numeric, 5.5::numeric, NULL::text),
  (255, 'HCVP', 'Lập kế hoạch đối với các khoản chi tiêu hành chính, công tác lễ tân khánh tiết, hội nghị, hội thảo.', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (256, 'HCVP', 'Thực hiện các thủ tục tạm ứng và hoàn tạm ứng đúng quy định', 2, 6.1::numeric, 6.1::numeric, NULL::text),
  (257, 'HCVP', 'Thực hiện chi tiêu theo quy định', 2, 4.6::numeric, 4.6::numeric, NULL::text),
  (258, 'HCVP', 'Đầu mối hoặc phối hợp thực hiện công tác hậu cần, tổ chức hội nghị, hội thảo, công tác lễ tân (giấy mời, quà tặng, hội trường, backrop, chụp ảnh, địa điểm...)', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (259, 'HCVP', 'Phối hợp thực hiện các bảng, biển, decal đảm bảo theo nhận diện thương hiệu (không bao gồm các gói thầu liên quan tới tuân thủ nhận diện thương hiệu và KGGD của BIDV)', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (260, 'HCVP', 'Thực hiện các báo cáo nhận diện thương hiệu theo yêu cầu', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (261, 'HCVP', 'Thanh quyết toán các khoản chi tiêu theo quy định', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (262, 'HCVP', 'Lưu hồ sơ nhận diện thương hiệu theo quy định', 2, 4.0::numeric, 4.0::numeric, NULL::text),
  (263, 'HCVP', 'Có kế hoạch, phương án đảm bảo an ninh, an toàn đối với người và tài sản của Chi nhánh và thực hiện các báo cáo liên quan.', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (264, 'HCVP', 'Phối hợp với chính quyền địa phương, đối tác về dịch vụ an ninh (công an, công ty cung cấp dịch vụ an ninh bảo vệ...) đảm bảo an toàn nơi làm việc (trụ sở chính và các PGD) và công tác vận chuyển tài sản có giá theo quy định của BIDV', 2, 8.8::numeric, 8.8::numeric, NULL::text),
  (265, 'HCVP', 'Có kế hoạch, phương án đảm bảo PCCC theo đúng quy định về an toàn PCCC tại Trụ sở chi nhánh và các PGD.', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (266, 'HCVP', 'Triển khai công tác PCCC tại chi nhánh (diễn tập, đào tạo, truyền thông, quán triệt…tới các tập thể và cá nhân thuộc Chi nhánh)', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (267, 'HCVP', 'Phối hợp với các phòng nghiệp vụ, các đơn vị chức năng về PCCC đảm bảo hồ sơ PCCC đầy đủ, đúng quy định và các báo cáo liên quan.', 2, 7.3::numeric, 7.3::numeric, NULL::text),
  (268, 'HCVP', 'Có kế hoạch thực hiện công tác Quốc phòng tuân thủ theo quy định của nhà nước.', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (269, 'HCVP', 'Tổ chức thực hiện hoặc phối hợp thực hiện công tác an ninh quốc phòng, dân quân tự vệ, quân nhân tại đơn vị và các báo cáo liên quan.', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (270, 'HCVP', 'Lưu hồ sơ theo quy định', 2, 4.0::numeric, 4.0::numeric, NULL::text),
  (271, 'HCVP', 'Quản lý và sử dụng con dấu của cơ quan theo đúng quy định (có sổ theo dõi bàn giao, sử dụng con dấu chính xác, đúng thẩm quyền, đúng văn bản...)', 2, 6.1::numeric, 6.1::numeric, NULL::text),
  (272, 'HCVP', 'Đầu mối tiếp nhận Văn bản đi, Văn bản đến (bao gồm cả thư bảo lãnh) và mở sổ theo dõi đối với các loại văn bản trên', 2, 5.2::numeric, 5.2::numeric, NULL::text),
  (273, 'HCVP', 'Thực hiện các thủ tục chuyển phát văn bản đến đúng nơi quy định (trên VPĐT, dịch vụ chuyển phát, trình lãnh đạo phê duyệt...)', 2, 6.4::numeric, 6.4::numeric, NULL::text),
  (274, 'HCVP', 'Đầu mối tiếp nhận thư, chuyển phát nhanh từ các đơn vị dịch vụ và chuyển đến đúng nơi theo yêu cầu.', 2, 5.2::numeric, 5.2::numeric, NULL::text),
  (275, 'HCVP', 'Lưu hồ sơ, văn bản văn thư theo quy định', 2, 5.2::numeric, 5.2::numeric, NULL::text),
  (276, 'HCVP', 'Tuân thủ việc điều động của lãnh đạo trong việc vận chuyển người và tài sản của đơn vị', 2, 5.5::numeric, 5.5::numeric, NULL::text),
  (277, 'HCVP', 'Thực hiện lái xe an toàn trong quá trình vận chuyển (an toàn giao thông, an toàn cho người và tài sản)', 2, 7.0::numeric, 7.0::numeric, NULL::text),
  (278, 'HCVP', 'Tuân thủ về quy định quản lý và sử dụng tài sản lưu động của đơn vị (tiết kiệm, hiệu quả, đúng mục đích...)', 2, 5.5::numeric, 5.5::numeric, NULL::text),
  (279, 'HCVP', 'Thực hiện thanh toán các chi phí liên quan tới công tác vận chuyển', 2, 5.8::numeric, 5.8::numeric, NULL::text),
  (280, 'HCVP', 'Lưu hồ sơ về công tác vận chuyển theo quy định', 2, 4.0::numeric, 4.0::numeric, NULL::text),
  (281, 'HCVP', 'Theo dõi và phân công công tác, ủy quyền của Ban lãnh đạo', 2, 6.7::numeric, 6.7::numeric, NULL::text),
  (282, 'HCVP', 'Thực hiện công tác hậu cần khi lãnh đạo tiếp khách đối nội, đối ngoại….', 2, 5.2::numeric, 5.2::numeric, NULL::text),
  (283, 'HCVP', 'Nghiên cứu và xây dựng quy trình, quy định nội bộ', 2, 88.0::numeric, 88.0::numeric, NULL::text),
  (284, 'CNTT', 'Cấp 4_Quản trị, vận hành các ứng dụng phần mềm phân tán cài đặt tại Chi nhánh gồm: Phần mềm nghiệp vụ (BDS, TF, Cilent Access, Quản lý chữ ký, Report Viewer...); Phần mềm khác (Office, bộ gõ Tiếng Việt, phần mềm của hệ thống camera các loại, phần mềm chấm công...); Các phần mềm liên quan đến phần cứng (Driver các thiết bị của PCi, driver máy in)…', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (285, 'CNTT', 'Cấp 4_Quản trị hệ thống AD tại Chi nhánh (theo chính sách đã được phê duyệt)', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (286, 'CNTT', 'Cấp 4_Quản lý hệ thống thiết bị đầu cuối tại chi nhánh (máy in, máy quét, máy photo...)', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (287, 'CNTT', 'Cấp 4_Thực hiện công tác trực kỹ thuật, xử lý sự cố hệ thống các máy móc thiết bị Công nghệ thông tin và các chương trình phần mềm ứng dụng tại Chi nhánh.', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (288, 'CNTT', 'Cấp 4_Phối hợp với phòng TCHC, KHTC trong việc điều chuyển thiết bị trong và ngoài Chi nhánh và quản lý tài sản về tin học.', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (289, 'CNTT', 'Cấp 4_Phối hợp với phòng TCHC, KHTC trong việc xác định thiết bị cần thanh lý.', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (290, 'CNTT', 'Cấp 4_Phối hợp với phòng TCHC quản lý việc vào ra cơ quan của thiết bị bảo hành.', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (291, 'CNTT', 'Cấp 4_Hỗ trợ việc bảo trì định kỳ hàng năm các thiết bị tin học của các phòng.', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (292, 'CNTT', 'Cấp 4_Hỗ trợ kỹ thuật từ các phòng ban và giải quyết các sự cố', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (293, 'CNTT', 'Cấp 4_Đầu mối đăng ký, rà soát user tra cứu thông tin tín dụng CIC cho các đơn vị tại Chi nhánh', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (294, 'CNTT', 'Cấp 4_Hỗ trợ sử dụng các ứng dụng truy cập từ Internet qua MobiIron', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (295, 'CNTT', 'Cấp 4_Phối hợp với Trung tâm CNTT xử lý sự cố hệ thống BDS/TF', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (296, 'CNTT', 'Cấp 4_Tổ chức phối hợp chuyển đổi BDS/TF dự phòng định kỳ 2 lần/1 năm', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (297, 'CNTT', 'Cấp 4_Thực hiện rà soát virus thủ công (hash file) đối với các Virus đặc biệt nghiêm trọng phát sinh nhưng chưa được cập nhật trên hệ thống Virus.', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (298, 'CNTT', 'Cấp 4_Rà soát hệ thống máy trạm, hệ thống Internet, cập nhật bản vá hệ điều hành, bản update BIOS… theo yêu cầu của TTCNTT', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (299, 'CNTT', 'Cấp 4_Phối hợp xử lý sự cố về mạng truyền thông tại Chi nhánh, PGD và ATM', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (300, 'CNTT', 'Cấp 4_Phối hợp với TT CNTT thực hiện các công việc trong quá trình triển khai các dự án/phần mềm ứng dụng có liên quan khi có yêu cầu', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (301, 'CNTT', 'Cấp 5_Thực hiện lưu trữ, bảo mật, phục hồi dữ liệu Camera và các chương trình ứng dụng và xử lý các sự cố kỹ thuật tại Chi nhánh.', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (302, 'CNTT', 'Cấp 5_Quản trị vận hành hệ thống camera tại ATM', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (303, 'CNTT', 'Cấp 5_Quản lý, theo dõi, vận hành cơ sở hạ tầng tại Chi nhánh bao gồm: Nguồn điện (UPS), điều hoà, camera giám sát và hệ thống an ninh và tổng đài VoIP, các thiết bị chuyển mạch Router/Switch, hệ thống chống sét lan truyền.', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (304, 'CNTT', 'Cấp 5_Cập nhật và kiểm tra thường xuyên công tác phòng chống virus tại các máy trạm thông qua phần mềm quản trị tập trung (McAffee)', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (305, 'CNTT', 'Cấp 5_Tổ chức cài đặt, lưu trữ, bảo mật, phục hồi dữ liệu, xử lý các sự cố kỹ thuật và lập hồ sơ theo dõi đối với hệ thống phần mềm, máy trạm, mạng, thiết bị ngoại vi tại Chi nhánh theo quy định.', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (306, 'CNTT', 'Cấp 5_Mua sắm, triển khai hệ thống wifi tại CN', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (307, 'CNTT', 'Cấp 5_Vận hành hệ thống kiểm soát kết nối Internet tại Chi nhánh', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (308, 'CNTT', 'Cấp 5_Hỗ trợ cho các cán bộ nghiệp vụ và khách hàng sử dụng các dịch vụ có tiện ích/ứng dụng Công nghệ thông tin', 5, 5.8::numeric, 5.8::numeric, NULL::text),
  (309, 'CNTT', 'Cấp 5_Quản lý hệ thống mạng LAN, kênh truyền nội tình tại Chi nhánh (lắp đặt hub, kéo cáp, bấm cáp..), hệ thống Wifi', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (310, 'CNTT', 'Cấp 5_Quản lý các kênh truyền mạng WAN kết nối từ Chi nhánh vể Trung tâm CNTT và các PGD/ATM', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (311, 'CNTT', 'Cấp 5_Cải tạo lại hệ thống mạng/điện/điện thoại/camera cho các phòng/PGD', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (312, 'CNTT', 'Cấp 5_Thực hiện kiểm tra, đánh giá tình trạng hoạt động của các thiết bị CNTT, cập nhật hồ sơ, lý lịch của máy móc thiết bị CNTT tại Chi nhánh và các tham mưu đề xuất (nếu có)', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (313, 'CNTT', 'Cấp 5_Đầu mối sửa chữa, bảo hành các thiết bị tin học, đường truyền thông, Internet tại Chi nhánh và các Phòng giao dịch, đảm bảo giao dịch an toàn, thông suốt', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (314, 'CNTT', 'Cấp 5_Thực hiện triển khai chính sách ATBM CNTT tới các bộ phận theo hướng dẫn', 5, 5.8::numeric, 5.8::numeric, NULL::text),
  (315, 'CNTT', 'Cấp 5_Lập báo cáo An toàn thông tin liên qua đến CNTT, báo cáo ISO liên quan đến CNTT theo hướng dẫn', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (316, 'CNTT', 'Cấp 5_Triển khai thiết bị CNTT PGD số tại CN khi được hỗ trợ trực tiếp từ cấp cao hơn', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (317, 'CNTT', 'Cấp 5_Quản trị các thiết bị tại PGD số, quản lý phần mềm triển khai tại PGD số theo hướng dẫn', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (318, 'CNTT', 'Cấp 5_Thực hiện công tác mua thiết bị phục vụ hoạt động tại Chi nhánh (cung cấp các yêu cầu kỹ thuật, cấu hình cần mua sắm)', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (319, 'CNTT', 'Cấp 5_Cài đặt cấu hình bảng điện tử, màn hình Led hiển thị tỷ giá tại Trụ sở Chi nhánh và các phòng Giao dịch', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (320, 'CNTT', 'Cấp 5_Giới thiệu sản phẩm, hướng dẫn sử dụng sản phẩm CNTT cho khách hàng', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (321, 'CNTT', 'Cấp 6_Chủ động đề xuất, tham mưu, tổ chức triển khai hoạt động CNTT tại chi nhánh phục vụ hoạt động kinh doanh đặc thù của đơn vị.', 5, 76.0::numeric, 76.0::numeric, NULL::text),
  (322, 'CNTT', 'Cấp 6_Quản trị các máy khác phục vụ công việc của riêng Chi nhánh (máy chủ truyền nhận file, web nội bộ)', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (323, 'CNTT', 'Cấp 6_Thực hiện các công tác liên quan khác về duy trì, thiết lập hạ tầng phần cứng tại Chi nhánh.', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (324, 'CNTT', 'Cấp 6_Quản trị hệ thống kiểm soát kết nối Internet tại Chi nhánh', 5, 5.8::numeric, 5.8::numeric, NULL::text),
  (325, 'CNTT', 'Cấp 6_Xây dựng hệ thống mạng/điện/điện thoại/camera phục vụ mở mới PGD', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (326, 'CNTT', 'Cấp 6_Hướng dẫn, đào tạo, hỗ trợ, kiểm tra giám sát việc thực hiện, tuân thủ các quy định và quy trình của BIDV trong lĩnh vực công nghệ thông tin tại Chi nhánh', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (327, 'CNTT', 'Cấp 6_Tổ chức triển khai chính sách ATBM CNTT tới các bộ phận', 5, 82.0::numeric, 82.0::numeric, NULL::text),
  (328, 'CNTT', 'Cấp 6_Lập báo cáo và đánh giá An toàn thông tin liên qua đến CNTT, báo cáo ISO liên quan đến CNTT', 5, 70.0::numeric, 70.0::numeric, NULL::text),
  (329, 'CNTT', 'Cấp 6_Triển khai thiết bị CNTT PGD số tại CN', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (330, 'CNTT', 'Cấp 6_Quản trị các thiết bị tại PGD số, quản lý phần mềm triển khai tại PGD số', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (331, 'CNTT', 'Cấp 6_Hướng dẫn và hỗ trợ khách hàng khi triển khai sản phẩm dịch vụ cho khách hàng doanh nghiệp (Security, iBank, Thu chi hộ điện tử…)', 5, 5.8::numeric, 5.8::numeric, NULL::text),
  (332, 'CNTT', 'Cấp 6_Khảo sát khách hàng mở kết nối với các đối tác (Thanh toán hóa đơn, Thu hộ…)', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (333, 'CNTT', 'Cấp 6_ Phối hợp với các đơn vị, bộ phận quản lý ATM thực hiện cập nhật, bảo trì, khắc phục lỗi các máy ATM tại chi nhánh.', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (334, 'CNTT', 'Cấp 6_Xây dựng chương trình hỗ trợ nghiệp vụ cho các phòng theo yêu cầu của Ban Giám đốc, các phòng', 5, 88.0::numeric, 88.0::numeric, NULL::text),
  (335, 'CNTT', 'Cấp 6_Định kỳ tháng, quý lấy số liệu tần suất giao dịch, hiệu quả giao dịch, hoạt động của các đơn vị phục vụ chấm hoàn thành nhiệm vụ theo BSC và KPI', 5, 7.0::numeric, 7.0::numeric, NULL::text),
  (336, 'CNTT', 'Cấp 6_Kết xuất dữ liệu hỗ trợ nghiệp vụ cho các phòng khi có phát sinh', 5, 10.0::numeric, 10.0::numeric, NULL::text),
  (337, 'CNTT', 'Cấp 6_Cấu hình POS cho các Phòng để triển khai lắp đặt cho các đơn vị chấp nhận thẻ', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (338, 'CNTT', 'Cấp 6_Quản trị và hỗ trợ máy tính kết nối Internet (truyền nhận file với NHNN, đối tác,…)', 5, 4.0::numeric, 4.0::numeric, NULL::text),
  (339, 'CNTT', 'Cấp 6_Tham gia phối hợp trong công tác kiểm tra nội bộ nội bộ tại Chi nhánh và đoàn kiểm tra ngoài, ISO.', 5, 8.5::numeric, 8.5::numeric, NULL::text),
  (340, 'CNTT', 'Tham mưu, đề xuất với cấp có thẩm quyền về kế hoạch ứng dụng công nghệ thông tin, về những vấn đề liên quan đến công nghệ thông tin tại Chi nhánh và những vấn đề cần kiến nghị với BIDV.', 5, 88.0::numeric, 88.0::numeric, NULL::text),
  (341, 'HCVP', 'Quản lý xe ô tô được phân giao', 2, 50.0::numeric, 50.0::numeric, NULL::text),
  (342, 'HCVP', 'Bảo quản xe và các giấy tờ xe liên quan đảm bảo không để mất mát, hư hỏng', 2, 30.0::numeric, 30.0::numeric, NULL::text),
  (343, 'HCVP', 'Định kỳ bảo dưỡng, bảo trì xe ô tô, kiểm tra các thông số kỹ thuật', 2, 20.0::numeric, 20.0::numeric, NULL::text),
  (344, 'HCVP', 'Đề xuất biện pháp khắc phục đảm bảo xe luôn sẵn sàng nhận nhiệm vụ', 2, 20.0::numeric, 20.0::numeric, NULL::text),
  (345, 'HCVP', 'Đề xuất mua bảo hiểm cho xe ô tô theo quy định', 2, 20.0::numeric, 20.0::numeric, NULL::text),
  (346, 'HCVP', 'Đánh số chứng từ và đóng chứng từ của Phòng QLNB', 2, 20.0::numeric, 20.0::numeric, NULL::text),
  (347, 'HCVP', 'Hỗ trợ vận chuyển và sắp xếp kho chứng từ', 2, 30.0::numeric, 30.0::numeric, NULL::text),
  (348, 'HCVP', 'Đề xuất, khởi tạo thanh toán chi phí xăng xe, chi phí bảo trì, bảo dưỡng đối với xe ô tô đang trực tiếp quản lý', 2, 20.0::numeric, 20.0::numeric, NULL::text),
  (349, 'TAPVU', 'Vệ sinh, sắp xếp bàn ghế; chuẩn bị nước uống, cốc/chén; kiểm tra phòng trước và thu dọn sau cuộc họp', 6, 10.0::numeric, 10.0::numeric, NULL::text),
  (350, 'TAPVU', 'Vệ sinh phòng làm việc Ban giám đốc; chuẩn bị nước uống và bảo đảm không gian sạch sẽ, ngăn nắp', 6, 5.0::numeric, 5.0::numeric, NULL::text),
  (351, 'TAPVU', 'Theo dõi giấy vệ sinh, nước rửa tay, túi rác, hóa chất, dụng cụ vệ sinh; báo cáo nhu cầu bổ sung kịp thời', 6, 5.0::numeric, 5.0::numeric, NULL::text),
  (352, 'TAPVU', 'Chuẩn bị trà, nước phục vụ Ban Giám đốc, khách và các cuộc họp/hội nghị theo yêu cầu', 6, 5.0::numeric, 5.0::numeric, NULL::text),
  (353, 'TAPVU', 'Thực hiện các công việc phục vụ, vệ sinh khác theo phân công phù hợp với chức năng, nhiệm vụ', 6, 10.0::numeric, 10.0::numeric, NULL::text),
  (354, 'TAPVU', 'Sắp xếp, bày biện đồ lễ trang nghiêm tại Ban thờ, đảm bảo đúng quy định và trang phục', 6, 10.0::numeric, 10.0::numeric, NULL::text),
  (355, 'HDDT', 'DANG Tham mưu chương trình, kế hoạch công tác; chuẩn bị nội dung phục vụ Đảng ủy, Ban Thường vụ, các Chi bộ', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (356, 'HDDT', 'DANG Tiếp nhận, trình, phát hành và theo dõi văn bản đến/đi; soạn thảo thông báo, nghị quyết, báo cáo, chương trình công tác', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (357, 'HDDT', 'DANG Chuẩn bị tài liệu, chương trình, giấy mời; tổng hợp nội dung; hoàn thiện biên bản, nghị quyết/kết luận và theo dõi thực hiện sau họp', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (358, 'HDDT', 'DANG Theo dõi danh sách, hồ sơ, thông tin đảng viên; chuyển sinh hoạt Đảng; cập nhật biến động và thực hiện các thủ tục liên quan', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (359, 'HDDT', 'DANG Theo dõi nguồn phát triển Đảng; hồ sơ quần chúng ưu tú; kết nạp Đảng; quản lý đảng viên dự bị; công nhận đảng viên chính thức', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (360, 'HDDT', 'DANG Theo dõi, đăng ký lớp nhận thức về Đảng, lớp đảng viên mới, bồi dưỡng lý luận chính trị và nghiệp vụ công tác Đảng', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (361, 'HDDT', 'DANG Theo dõi chương trình kiểm tra, giám sát; chuẩn bị hồ sơ, tài liệu và tổng hợp kết quả thực hiện', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (362, 'HDDT', 'DANG Thực hiện kiểm điểm, đánh giá, xếp loại tổ chức Đảng và đảng', 7, 10.0::numeric, NULL::numeric, NULL::text),
  (363, 'HDDT', 'DANG Tổng hợp thành tích; lập hồ sơ đề nghị khen thưởng tổ chức Đảng, đảng viên; theo dõi kết quả khen thưởng', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (364, 'HDDT', 'DANG Sắp xếp, lưu trữ hồ sơ đảng viên, nghị quyết, biên bản, báo cáo và tài liệu công tác Đảng; bảo đảm bảo mật', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (365, 'HDDT', 'DANG Tổng hợp báo cáo định kỳ, chuyên đề, đột xuất; theo dõi và đôn đốc các Chi bộ thực hiện chế độ báo cáo', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (366, 'HDDT', 'DANG Theo dõi chương trình công tác, nhiệm vụ được giao; đôn đốc các Chi bộ/đơn vị và tổng hợp tiến độ, kết quả thực hiệ', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (367, 'HDDT', 'DANG Phối hợp tổ chức đại hội, hội nghị, lễ kết nạp, trao Huy hiệu Đảng, chương trình về nguồn và các hoạt động chính trị', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (368, 'HDDT', 'DANG Cập nhật dữ liệu, hồ sơ và thực hiện các nghiệp vụ trên các hệ thống/phần mềm công tác Đảng theo quy định', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (369, 'HDDT', 'DANG Thực hiện các nhiệm vụ phát sinh theo chỉ đạo của Đảng ủy, Bí thư/Phó Bí thư và yêu cầu của Đảng ủy cấp trên', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (370, 'HDDT', 'DANG Theo dõi danh sách đảng viên, mức đóng và số đảng phí phải thu của từng đảng viên theo quy định', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (371, 'HDDT', 'DANG Thông báo, hướng dẫn, đôn đốc đảng viên thực hiện nộp đảng phí đầy đủ, đúng thời hạn', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (372, 'HDDT', 'DANG Theo dõi, cập nhật và đối chiếu tình trạng nộp đảng phí của đảng viên trên hệ thống/ứng dụng được triển khai', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (373, 'HDDT', 'DANG Đối chiếu số phải thu, thực thu, số đã nộp và số còn phải thu; xử lý hoặc báo cáo các trường hợp chênh lệch', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (374, 'HDDT', 'DANG Xác định số đảng phí được để lại và số phải nộp cấp trên; thực hiện thủ tục nộp theo quy định', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (375, 'HDDT', 'DANG Theo dõi các khoản thu, chi từ nguồn tài chính của Chi bộ; bảo đảm chi đúng nội dung, thẩm quyền và nguồn kinh phí', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (376, 'HDDT', 'DANG Kiểm tra hồ sơ, chứng từ; thực hiện thanh toán các khoản chi phục vụ hoạt động của Chi bộ sau khi được phê duyệt', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (377, 'HDDT', 'DANG Theo dõi số dư tiền, kinh phí được để lại và tình hình sử dụng nguồn tài chính của Chi bộ', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (378, 'HDDT', 'DANG Cập nhật sổ thu – chi, sổ theo dõi đảng phí và các bảng đối chiếu liên quan theo quy định', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (379, 'HDDT', 'DANG Thu thập, kiểm tra, sắp xếp và lưu trữ chứng từ thu – chi, chứng từ nộp đảng phí và các hồ sơ tài chính liên quan', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (380, 'HDDT', 'DANG Chuẩn bị số liệu phục vụ báo cáo, công khai tình hình thu – chi và sử dụng đảng phí trước Chi ủy/Chi bộ theo quy định', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (381, 'HDDT', 'DANG Tổng hợp số liệu, lập báo cáo/quyết toán tài chính Chi bộ cuối kỳ, cuối năm hoặc theo yêu cầu', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (382, 'HDDT', 'DANG Chuẩn bị sổ sách, chứng từ, bảng kê và số liệu phục vụ công tác kiểm tra tài chính Đảng', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (383, 'HDDT', 'DANG Phối hợp cập nhật tăng, giảm, chuyển sinh hoạt Đảng để điều chỉnh danh sách và nghĩa vụ đóng đảng phí', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (384, 'HDDT', 'DANG Cung cấp số liệu và thực hiện các nhiệm vụ tài chính, đảng phí khác theo phân công của Bí thư/Chi ủy', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (385, 'HDDT', 'CONGDOAN Theo dõi, hạch toán các khoản thu kinh phí, đoàn phí; đối chiếu số phải thu, đã thu và số phải nộp cấp trên', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (386, 'HDDT', 'CONGDOAN Tiếp nhận, kiểm tra hồ sơ thanh toán; thực hiện chi đúng đối tượng, nội dung, định mức và nguồn kinh phí', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (387, 'HDDT', 'CONGDOAN Kiểm tra tính đầy đủ, hợp lệ của chứng từ; sắp xếp, lưu trữ hồ sơ thu, chi, thanh toán theo quy định', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (388, 'HDDT', 'CONGDOAN Phối hợp xây dựng dự toán thu – chi hằng năm; theo dõi tình hình thực hiện và đề xuất điều chỉnh khi cần thiết', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (389, 'HDDT', 'CONGDOAN Theo dõi kinh phí theo từng nguồn, nội dung và chương trình; kiểm soát mức sử dụng so với dự toán được duyệt', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (390, 'HDDT', 'CONGDOAN Tổng hợp số liệu, lập báo cáo quyết toán định kỳ/năm; đối chiếu số liệu trước khi trình phê duyệt và gửi Công đoàn cấp trên', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (391, 'HDDT', 'CONGDOAN Lập các báo cáo thu – chi, tồn quỹ, tình hình sử dụng kinh phí và các báo cáo định kỳ/đột xuất theo yêu cầu', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (392, 'HDDT', 'CONGDOAN Thực hiện thủ tục tài chính cho các chương trình thăm hỏi, phúc lợi, hiếu hỷ, nghỉ mát, văn hóa – thể thao, nữ công, an sinh xã hội và các hoạt động khác', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (393, 'HDDT', 'CONGDOAN Chuẩn bị số liệu phục vụ công khai tài chính; cung cấp số liệu cho Ban Chấp hành, Ban Thường vụ và các bộ phận có liên quan', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (394, 'HDDT', 'CONGDOAN Cập nhật quy định; cung cấp số liệu, hồ sơ và thực hiện các nhiệm vụ tài chính – kế toán khác theo phân công của BCH/Ban Thường vụ Công đoàn', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (395, 'HDDT', 'DOAN Xây dựng chương trình, kế hoạch công tác Đoàn (quý, năm)', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (396, 'HDDT', 'DOAN Tổ chức họp BCH, họp chi đoàn, sinh hoạt Đoàn định kỳ', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (397, 'HDDT', 'DOAN Tổ chức đại hội, hội nghị tổng kết công tác Đoàn', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (398, 'HDDT', 'DOAN Kết nạp đoàn viên mới, giới thiệu đoàn viên ưu tú cho Đảng', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (399, 'HDDT', 'DOAN Quản lý danh sách đoàn viên, thu nộp đoàn phí', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (400, 'HDDT', 'DOAN Đánh giá, xếp loại đoàn viên và tổ chức Đoàn', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (401, 'HDDT', 'DOAN Báo cáo định kỳ lên Đoàn cấp trên', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (402, 'HDDT', 'DOAN Tuyên truyền, sinh hoạt chuyên đề, học tập chính trị', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (403, 'HDDT', 'DOAN Đăng tin, bài, hình ảnh hoạt động trên kênh nội bộ, fanpage, Zalo', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (404, 'HDDT', 'DOAN Tổ chức hoạt động tình nguyện, hiến máu, từ thiện, về nguồn, bảo vệ môi trường', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (405, 'HDDT', 'DOAN Tổ chức giải thể thao, văn nghệ, hội thi, hội diễn', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (406, 'HDDT', 'DOAN Tổ chức kỷ niệm ngày lễ (8/3, 20/10, 20/11, Trung thu...), du lịch, team building', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (407, 'HDDT', 'DOAN Phát động thi đua, thi nghiệp vụ, phong trào sáng kiến gắn với nhiệm vụ chuyên môn', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (408, 'HDDT', 'DOAN Đào tạo kỹ năng mềm, chia sẻ kinh nghiệm cho đoàn viên', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (409, 'HDDT', 'DOAN Thăm hỏi, hỗ trợ, tặng quà đoàn viên (ốm đau, hiếu hỷ, sinh nhật, lễ tết)', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (410, 'HDDT', 'DOAN Soạn thảo văn bản, thông báo, biên bản họp, lưu trữ hồ sơ Đoàn', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (411, 'HDDT', 'DOAN Quản lý quỹ Đoàn, thu chi, quyết toán, công khai tài chính', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (412, 'HDDT', 'DOAN Chuẩn bị hậu cần, hội trường, trang trí, âm thanh cho sự kiện', 7, 3.0::numeric, NULL::numeric, NULL::text),
  (413, 'HDDT', 'Các công việc khác theo chỉ đạo của cấp trên độ phức tạp cao', 7, 10.0::numeric, NULL::numeric, NULL::text),
  (414, 'HDDT', 'Các công việc khác theo chỉ đạo của cấp trên độ phức tạp trung bình', 7, 5.0::numeric, NULL::numeric, NULL::text),
  (415, 'HDDT', 'Các công việc khác theo chỉ đạo của cấp trên độ phức tạp thấp', 7, 3.0::numeric, NULL::numeric, NULL::text);

update _new_cv n set ma_cv = x.ma_cv
from (select seq, prefix || '-' || lpad((row_number() over (partition by prefix order by seq))::text, 3, '0') as ma_cv from _new_cv) x
where x.seq = n.seq;

-- 3) Ghép việc cũ <-> việc mới theo (mảng, tên chuẩn hoá, thứ tự xuất hiện nếu trùng tên)
create temp table _old_cv on commit drop as
select jc.id, jc.ma_cv as ma_cv_cu, mc.ma_mang, pg_temp.norm_ten(jc.ten_cong_viec) as k,
       row_number() over (partition by mc.ma_mang, pg_temp.norm_ten(jc.ten_cong_viec) order by jc.ma_cv) as rn
from job_catalog jc join mang_cv mc on mc.id = jc.mang_cv_id;

create temp table _new_k on commit drop as
select seq, ma_mang, pg_temp.norm_ten(ten) as k,
       row_number() over (partition by ma_mang, pg_temp.norm_ten(ten) order by seq) as rn
from _new_cv;

create temp table _map on commit drop as
select o.id as old_id, n.seq
from _old_cv o join _new_k n on n.ma_mang = o.ma_mang and n.k = o.k and n.rn = o.rn;

-- Giải phóng toàn bộ mã cũ (ma_cv là UNIQUE) trước khi gán mã mới
update job_catalog set ma_cv = 'CU-' || ma_cv where ma_cv not like 'CU-%';

-- 3a) Việc cũ còn dùng -> cập nhật tại chỗ, giữ nguyên id
update job_catalog jc set
  ma_cv = n.ma_cv, ten_cong_viec = n.ten, mang_cv_id = mc.id,
  diem_can_bo = n.diem_can_bo, diem_kiem_soat = n.diem_kiem_soat,
  diem_truong_phong = NULL, diem_pgd = NULL, diem_gd = NULL,
  tan_suat = n.tan_suat, active = true
from _map m
join _new_cv n on n.seq = m.seq
join mang_cv mc on mc.ma_mang = n.ma_mang
where jc.id = m.old_id;

-- 3b) Việc mới chưa có -> thêm
insert into job_catalog (ma_cv, ten_cong_viec, mang_cv_id, diem_can_bo, diem_kiem_soat, tan_suat, active)
select n.ma_cv, n.ten, mc.id, n.diem_can_bo, n.diem_kiem_soat, n.tan_suat, true
from _new_cv n
join mang_cv mc on mc.ma_mang = n.ma_mang
where n.seq not in (select seq from _map);

-- 3c) Việc cũ không còn trong danh sách mới
update job_catalog jc set active = false
where jc.id not in (select old_id from _map)
  and exists (select 1 from daily_log dl where dl.job_catalog_id = jc.id);

delete from job_catalog jc
where jc.id not in (select old_id from _map)
  and not exists (select 1 from daily_log dl where dl.job_catalog_id = jc.id);

-- 4) Phân công mảng cho cán bộ theo sheet "Cán bộ"
create temp table _cb (ma_cbnv text, ma_mang int) on commit drop;
insert into _cb (ma_cbnv, ma_mang) values
  ('157251', 1),
  ('157251', 2),
  ('157251', 3),
  ('157251', 4),
  ('157251', 5),
  ('157251', 6),
  ('157251', 7),
  ('157251', 8),
  ('169422', 1),
  ('169422', 2),
  ('169422', 3),
  ('169422', 4),
  ('169422', 5),
  ('169422', 6),
  ('169422', 7),
  ('169422', 8),
  ('157279', 1),
  ('157279', 2),
  ('157279', 3),
  ('157279', 4),
  ('157279', 5),
  ('157279', 6),
  ('157279', 7),
  ('157279', 8),
  ('157280', 1),
  ('157280', 2),
  ('157280', 3),
  ('157280', 4),
  ('157280', 5),
  ('157280', 6),
  ('157280', 7),
  ('157280', 8),
  ('146999', 1),
  ('146999', 2),
  ('146999', 3),
  ('146999', 4),
  ('146999', 5),
  ('146999', 6),
  ('146999', 7),
  ('146999', 8),
  ('157267', 1),
  ('157267', 2),
  ('157267', 3),
  ('157267', 4),
  ('157267', 5),
  ('157267', 6),
  ('157267', 7),
  ('157267', 8),
  ('157275', 1),
  ('157275', 2),
  ('157275', 3),
  ('157275', 4),
  ('157275', 5),
  ('157275', 6),
  ('157275', 7),
  ('157275', 8),
  ('183881', 1),
  ('183881', 2),
  ('183881', 3),
  ('183881', 4),
  ('183881', 5),
  ('183881', 6),
  ('183881', 7),
  ('183881', 8),
  ('157761', 1),
  ('157761', 2),
  ('157761', 3),
  ('157761', 4),
  ('157761', 5),
  ('157761', 6),
  ('157761', 7),
  ('157761', 8),
  ('157764', 1),
  ('157764', 2),
  ('157764', 3),
  ('157764', 4),
  ('157764', 5),
  ('157764', 6),
  ('157764', 7),
  ('157764', 8),
  ('157765', 1),
  ('157765', 2),
  ('157765', 3),
  ('157765', 4),
  ('157765', 5),
  ('157765', 6),
  ('157765', 7),
  ('157765', 8),
  ('157760', 1),
  ('157760', 2),
  ('157760', 3),
  ('157760', 4),
  ('157760', 5),
  ('157760', 6),
  ('157760', 7),
  ('157760', 8),
  ('157763', 1),
  ('157763', 2),
  ('157763', 3),
  ('157763', 4),
  ('157763', 5),
  ('157763', 6),
  ('157763', 7),
  ('157763', 8);

delete from employee_mang_cv emc
using employees e
where e.id = emc.employee_id
  and e.ma_cbnv in (select ma_cbnv from _cb)
  and emc.mang_cv_id not in (
    select mc.id from _cb c join mang_cv mc on mc.ma_mang = c.ma_mang where c.ma_cbnv = e.ma_cbnv
  );

insert into employee_mang_cv (employee_id, mang_cv_id)
select e.id, mc.id
from _cb c
join employees e on e.ma_cbnv = c.ma_cbnv
join mang_cv mc on mc.ma_mang = c.ma_mang
on conflict (employee_id, mang_cv_id) do nothing;

-- 5) Màn Hôm nay: trả về tần suất thật (trước đây luôn NULL) để lọc theo Tần suất
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

commit;

-- ============================================================================
-- KIỂM TRA SAU KHI CHẠY (chỉ đọc). Mong đợi: viec_dang_dung = 415,
-- viec_ngung_dung = số việc cũ đã có lịch sử nhưng không còn trong danh sách mới,
-- so_phan_cong_mang = 104 (13 cán bộ x 8 mảng).
-- ============================================================================
select
  (select count(*) from job_catalog where active) as viec_dang_dung,
  (select count(*) from job_catalog where not active) as viec_ngung_dung,
  (select count(*) from job_catalog where active and tan_suat is not null) as viec_co_tan_suat,
  (select count(*) from employee_mang_cv) as so_phan_cong_mang;
