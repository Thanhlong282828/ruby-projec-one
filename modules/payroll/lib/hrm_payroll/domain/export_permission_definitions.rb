module HrmPayroll
  module Domain
    class ExportPermissionDefinitions
      DEFINITIONS = {
        "payroll.exports.notify" => "Gửi thông báo snapshot bảng lương",
        "payroll.exports.read" => "Xem tệp xuất bảng lương company",
        "payroll.exports.create" => "Tạo snapshot CSV bảng lương đã chốt",
        "payroll.exports.download" => "Tải tệp xuất bảng lương nhạy cảm"
      }.freeze
      def self.for_role(role) = role == "admin" ? DEFINITIONS.keys : []
    end
  end
end
