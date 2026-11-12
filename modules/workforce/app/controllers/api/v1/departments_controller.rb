module Api # Api: Namespace dành cho API.
  module V1 # V1: Phiên bản API thứ nhất.
    class DepartmentsController < BaseController # DepartmentsController: Controller quản lý phòng ban | < BaseController: Kế thừa Controller cha. | Tương đương Laravel: namespace App\Http\Controllers\Api\V1; class DepartmentsController extends Controller { }
      before_action :set_record, only: [ :show, :update, :destroy ] # before_action — chạy trước một số Action | Rails sẽ gọi set_record trước khi thực hiện show, update hoặc destroy. | Ví dụ khi client gửi: GET /api/v1/departments/10 |
      #      Luồng thực hiện:  Tương tự việc kết hợp middleware, route model binding và authorization trong Laravel, nhưng ở đây được triển khai bằng callback Controller.
      #      Request
      #        |
      #        v
      #     before_action :set_record
      #        |
      #        +-- FindDepartment
      #        |
      #        +-- authorize @record
      #        |
      #        v
      #     show
      #        |
      #        v
      #     JSON Response

      # 4. Phân tích bảo mật                                         < quan trọng
      # Trong Controller này có hai cơ chế đáng chú ý:
      # Thứ nhất: actor: current_user.                          <
      #       actor: current_user
      # > Controller truyền người dùng hiện tại cho Query/Command để tầng Application có thể thực hiện kiểm tra quyền và giới hạn dữ liệu theo công ty.
      # > Nhưng truyền actor không tự động bảo đảm Query/Command đã kiểm tra quyền.
      # Thứ hai: authorize @record.                             <
      #       def set_record
      #         @record = HrmWorkforce::Application::Queries::FindDepartment.new.call(
      #           actor: current_user,
      #           id: params[:id]
      #         )
      #         authorize @record
      #       end
      # Với Pundit, authorize @record mặc định suy ra tên phương thức Policy từ tên Action đang chạy.
      #         Action	    Policy mặc định
      #         show	      show?
      #         update    	update?
      #         destroy	    destroy?

      # Tuy nhiên, index và create không gọi authorize trực tiếp trong đoạn code này. Vì vậy cần kiểm tra BaseController, ListDepartments và CreateDepartment để xác nhận chúng đã kiểm soát quyền.
      # Đối với hệ thống HRM đa công ty, FindDepartment cũng cần giới hạn bản ghi theo tenant, không chỉ dựa vào ID. Không thể xác nhận điều này chỉ từ Controller.
      def index # index — lấy danh sách phòng ban
        records = HrmWorkforce::Application::Queries::ListDepartments.new.call(actor: current_user, page: params[:page])
        render json: { data: records }
        # ListDepartments: Query lấy danh sách phòng ban.      Ví dụ:                                 Tương đương Laravel về mặt kiến trúc:
        # .new: Khởi tạo đối tượng Query.                        GET /api/v1/departments?page=2           public function index(Request $request, ListDepartments $query)
        # .call(...): Thực thi Query.                                                                     {
        # actor: current_user: Truyền người dùng hiện tại.                                                   $records = $query->handle( auth()->user(),$request->query('page') );
        # page: params[:page]: Truyền số trang từ request.                                                   return response()->json([ 'data' => $records ]);
        # render json: Trả dữ liệu JSON.                                                                  }
        # >  Lưu ý: Controller chỉ truyền tham số page. Cách phân trang thực tế nằm trong ListDepartments, không thể kết luận từ Controller rằng nó sử dụng LIMIT/OFFSET hay bao nhiêu bản ghi mỗi trang.
      end
      def show # show — xem chi tiết phòng ban
        render json: { data: @record } # @record là instance variable đã được gán trong set_record.
        # Có hai công việc:
        #       FindDepartment tìm phòng ban theo ID.
        #       authorize @record kiểm tra quyền truy cập bằng Pundit.
        # Theo quy ước của Pundit, khi authorize @record  được gọi trong action show, nó thường kiểm tra show? trong Policy tương ứng với model của @record.
        # Nếu không có quyền, Pundit có thể phát sinh Pundit::NotAuthorizedError.
      end
      def create # create — tạo phòng ban | Đây là Command, vì nó thay đổi dữ liệu.
        record = HrmWorkforce::Application::Commands::CreateDepartment.new.call(actor: current_user, attributes: record_params) # record_params lấy dữ liệu từ:  def record_params = HrmWorkforce::Application::Requests::DepartmentRequest.read(params)
        render json: { data: record }, status: :created
        # Tức là Controller không trực tiếp viết Strong Parameters mà chuyển cho DepartmentRequest.read(params).
        # Ví dụ request:
        #     POST /api/v1/departments
        #     Content-Type: application/json
        #     {
        #       "name": "Human Resources"
        #     }#
        # Nếu Command thực hiện thành công, Controller trả về HTTP 201 Created.#
        # Tuy nhiên, việc validate, kiểm tra quyền tạo và lưu dữ liệu phải xem code bên trong CreateDepartment và DepartmentRequest.
      end
      def update # update — cập nhật phòng ban
        HrmWorkforce::Application::Commands::UpdateDepartment.new.call(actor: current_user, record: @record, attributes: record_params)
        render json: { data: @record }
        # Điểm khác với create là:
        #       - create nhận attributes để tạo bản ghi mới.
        #       - update nhận cả record: @record và attributes để cập nhật bản ghi đã tìm thấy.
        # @record được lấy và kiểm tra quyền trước đó bởi set_record.
        # Một chi tiết cần chú ý: Controller không sử dụng giá trị trả về của UpdateDepartment. Nó render lại @record, nên Command cần cập nhật đối tượng này hoặc bảo đảm trạng thái của nó đã được làm mới nếu muốn JSON phản ánh dữ liệu mới.
      end
      def destroy # destroy — xóa phòng ban
        if HrmWorkforce::Application::Commands::DeleteDepartment.new.call(actor: current_user, record: @record)
          head :no_content
        else
          render json: { error: "dependent_records", details: @record.errors.full_messages }, status: :conflict
        end
        # Đây là Action xử lý hai trường hợp.
        #       Command trả về truthy                                     204
        #       head :no_content trả HTTP 204, không có JSON body.
        #       Command trả về false hoặc nil                             409
        #       Trả HTTP 409 Conflict cùng thông tin lỗi dependent_records.
        # Ví dụ phản hồi khi xóa thất bại:
        #             {
        #               "error": "dependent_records",
        #               "details": [
        #                 "Cannot delete record because dependent records exist"
        #               ]
        #             }
        # Đây là ví dụ minh họa. Nội dung details thực tế lấy từ @record.errors.full_messages.
        # Điểm quan trọng: Controller đang giả định Command trả về false/nil khi có bản ghi phụ thuộc. Nếu Command phát sinh exception thay vì trả về false, nhánh else sẽ không tự động chạy.
      end
      private
      def set_record
        @record = HrmWorkforce::Application::Queries::FindDepartment.new.call(actor: current_user, id: params[:id])
        authorize @record
      end
      def record_params = HrmWorkforce::Application::Requests::DepartmentRequest.read(params)
    end
  end
end
# Đây là REST API Controller quản lý phòng ban (Departments) trong project Ruby on Rails HRM của bạn.
# Điểm đáng chú ý là Controller này đang sử dụng kiến trúc CQRS (Command Query Responsibility Segregation), tương tự cách bạn từng xây dựng các module Laravel với Controller → Command/Query → Repository → Database.
# Controller không trực tiếp gọi Department.create!, Department.where hay Department.destroy. Thay vào đó, nó chuyển công việc cho các Command và Query.
# 1. Sơ đồ kiến trúc
#           Frontend / API Client
#                    |
#                    v
#           Api::V1::DepartmentsController
#                    |
#                    +---- QUERY (Đọc dữ liệu)
#                    |       |
#                    |       +-- ListDepartments
#                    |       +-- FindDepartment
#                    |
#                    +---- COMMAND (Thay đổi dữ liệu)
#                    |       |
#                    |       +-- CreateDepartment
#                    |       +-- UpdateDepartment
#                    |       +-- DeleteDepartment
#                    |
#                    +---- REQUEST
#                    |       |
#                    |       +-- DepartmentRequest
#                    |
#                    +---- AUTHORIZATION
#                            |
#                            +-- Pundit Policy#
#

# Đây là các thành phần được Controller gọi. Việc chúng có sử dụng Repository, Service hay ActiveRecord bên trong hay không còn phụ thuộc code triển khai của từng Command/Query.

# Bảng tổng hợp CRUD và CQRS
# Action	                           Thành phần xử lý           HTTP thành công
# index                             	ListDepartments Query	       200
# show	                             FindDepartment Query	        200
# create                             CreateDepartment Command	    201
# update                             UpdateDepartment Command	    200
# destroy                            DeleteDepartment Command	    204
# destroy thất bại theo nhánh else	 DeleteDepartment Command	    409
