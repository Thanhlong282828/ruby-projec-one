module OnboardingHelper
  def onboarding_status_label(status)
    { "draft" => "Bản nháp", "ready" => "Sẵn sàng", "preboarding" => "Trước ngày nhận việc", "in_progress" => "Đang tiếp nhận", "blocked" => "Đang vướng mắc", "probation_review" => "Đánh giá thử việc", "completed" => "Hoàn tất", "cancelled" => "Đã hủy" }.fetch(status, status)
  end
end
