return if Rails.env.test?
raise "Seeding demo data is disabled in production" if Rails.env.production?
password = ENV.fetch("SEED_ADMIN_PASSWORD")
raise "Seed password needs 12+ characters" if password.length < 12
ActiveRecord::Base.transaction do
  admin = User.find_or_initialize_by(email: "admin@hrm.local")
  admin.assign_attributes(password: password, role: :admin, active: true)
  admin.save!
  departments = { "ENG" => "Công nghệ", "HR" => "Nhân sự & Văn hóa", "OPS" => "Vận hành", "DES" => "Thiết kế" }.map do |code, name|
    Department.find_or_create_by!(code: code) { |department| department.name = name }
  end
  people = [["Nguyễn Minh Anh", "Product Designer"], ["Trần Hoàng Nam", "Backend Engineer"], ["Lê Thảo Linh", "HR Specialist"], ["Phạm Đức Huy", "Operations Lead"], ["Võ Ngọc Mai", "Frontend Engineer"], ["Đặng Gia Bảo", "QA Engineer"]]
  people.each_with_index do |(name, title), index|
    email = "member#{index + 1}@hrm.local"
    user = User.find_or_create_by!(email: email) { |u| u.password = password; u.role = index == 2 ? :hr : :employee }
    Employee.find_or_create_by!(employee_code: "XV%03d" % (index + 1)) do |employee|
      employee.assign_attributes(full_name: name, email: email, job_title: title, department: departments[index % departments.length], user: user, hired_on: Date.new(2026, 1, 5), salary_cents: 18000000 + index * 2000000)
    end
  end
  Candidate.find_or_create_by!(email: "candidate@example.test") { |c| c.full_name = "Bùi Hà Phương"; c.position = "Product Manager"; c.stage = :interview }
end
puts "Seeded admin@hrm.local and member1..6@hrm.local. Password comes from SEED_ADMIN_PASSWORD."
