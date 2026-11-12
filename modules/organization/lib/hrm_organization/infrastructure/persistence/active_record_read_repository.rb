require "csv"
module HrmOrganization
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        SOURCE_ASSOCIATIONS = { parent_id: :parent, organization_unit_id: :organization_unit, job_position_id: :job_position, cost_center_id: :cost_center, employee_id: :employee }.freeze
        def branches(actor:, q: nil, status: nil, after: nil)
          Pundit.authorize(actor, ::OrganizationUnit, :index?)
          filters = Domain::Services::BranchFilters.new(q: q, status: status, after: after)
          scope = Pundit.policy_scope!(actor, ::OrganizationUnit).where(unit_type: "branch")
          filtered = scope
          unless filters.q.empty?
            pattern = "%#{ActiveRecord::Base.sanitize_sql_like(filters.q, '!')}%"
            filtered = filtered.where("code LIKE ? ESCAPE '!' OR name LIKE ? ESCAPE '!'", pattern, pattern)
          end
          today = Date.current
          filtered = case filters.status
          when "current" then filtered.where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", today, today)
          when "upcoming" then filtered.where("effective_from > ?", today)
          when "ended" then filtered.where(effective_to: ...today)
          else filtered
          end
          matching = filtered.count
          filtered = filtered.where("id > ?", filters.after) if filters.after
          records = filtered.order(:id).limit(26).to_a
          more = records.length > 25
          records = records.first(25)
          { records: records, total: scope.count, matching: matching,
           next_after: more ? records.last.id : nil, q: filters.q, status: filters.status,
           parents: Pundit.policy_scope!(actor, ::OrganizationUnit).where(unit_type: "company").order(:code).limit(100).pluck(:name, :id) }
        end
        def list(actor:, resource:, page: 1)
          scope = scoped(actor: actor, resource: resource).order(:id)
          Hrm::Pagination.call(scope, page).to_a
        end
        def find!(actor:, resource:, id:) = scoped(actor: actor, resource: resource).find(id)
        def describe(actor:, resource:, record:)
          fields = Domain::Resources.fetch(resource).fetch(:fields).map do |field, (label, kind)|
            value = record.public_send(field)
            source = nil
            if [ :unit, :position, :cost_center, :employee ].include?(kind) && value
              association = SOURCE_ASSOCIATIONS.fetch(field)
              related = record.public_send(association)
              if related
                value = related.respond_to?(:full_name) ? related.full_name : (related.respond_to?(:name) ? related.name : related.title)
                if Pundit.policy!(actor, related).show?
                  source = case kind
                  when :employee then "/employees/#{related.id}"
                  when :unit then "#{Domain::Resources.path('organization_units')}/#{related.id}"
                  when :position then "#{Domain::Resources.path('job_positions')}/#{related.id}"
                  when :cost_center then "#{Domain::Resources.path('cost_centers')}/#{related.id}"
                  end
                end
              end
            elsif kind == :boolean
              value = value ? "Có" : "Không"
            end
            { label: label, value: value, source: source }
          end
          { id: record.id, source: "#{Domain::Resources.path(resource)}/#{record.id}", fields: fields }
        end
        def form(actor:, resource:, id: nil)
          record = id ? find!(actor: actor, resource: resource, id: id) : Domain::Resources.model(resource).new(company_id: actor.company_id)
          Pundit.authorize(actor, record, id ? :update? : :create?)
          options = { unit_type: ::OrganizationUnit::KINDS.map { |value| [ value, value ] }, currency: %w[VND USD EUR JPY SGD AUD GBP].map { |value| [ value, value ] } }
          needed = Domain::Resources.fetch(resource).fetch(:fields).values.map(&:last)
          { unit: ::OrganizationUnit, cost_center: ::CostCenter, position: ::JobPosition }.each do |kind, model|
            next unless needed.include?(kind)
            options[kind] = model.where(company_id: actor.company_id).order(:id).map { |r| [ "#{r.code} — #{r.respond_to?(:name) ? r.name : r.title}", r.id ] }
          end
          options[:employee] = Pundit.policy_scope!(actor, ::Employee).order(:full_name).pluck(:full_name, :id) if needed.include?(:employee)
          { record: record, options: options }
        end
        def tree(actor:)
          units = Pundit.policy_scope!(actor, ::OrganizationUnit).order(:code).to_a
          by_parent = units.group_by(&:parent_id)
          build = ->(parent_id, seen) { Array(by_parent[parent_id]).reject { |r| seen.include?(r.id) }.map { |r| { id: r.id, code: r.code, name: r.name, unit_type: r.unit_type, source: "#{Domain::Resources.path('organization_units')}/#{r.id}", children: build.call(r.id, seen + [ r.id ]) } } }
          build.call(nil, [])
        end
        def headcount(actor:, on:)
          units = Pundit.policy_scope!(actor, ::OrganizationUnit).order(:code).to_a
          positions = Pundit.policy_scope!(actor, ::JobPosition).order(:code).to_a
          occupied = Pundit.policy_scope!(actor, ::EmployeeAssignment).where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", on, on).group(:job_position_id).count
          positions.map do |position|
            unit = units.detect { |u| u.id == position.organization_unit_id }
            filled = occupied.fetch(position.id, 0)
            { id: position.id, code: position.code, title: position.title, unit: unit&.name, unit_source: unit && "#{Domain::Resources.path('organization_units')}/#{unit.id}", approved: position.approved_headcount, occupied: filled, vacant: [ position.approved_headcount - filled, 0 ].max, critical: position.is_critical, source: "#{Domain::Resources.path('job_positions')}/#{position.id}" }
          end
        end
        def export(actor:, resource:)
          # Export permission is independent of list permission, but always company-scoped.
          model = Domain::Resources.model(resource)
          Pundit.authorize(actor, model, :export?)
          fields = Domain::Resources.fetch(resource).fetch(:fields).keys
          CSV.generate do |csv|
            csv << fields
            model.where(company_id: actor.company_id).order(:id).find_each do |record|
              csv << fields.map { |field| safe_cell(record.public_send(field)) }
            end
          end
        end
        private
        def scoped(actor:, resource:)
          relation = Pundit.policy_scope!(actor, Domain::Resources.model(resource))
          links = associations(resource)
          links.empty? ? relation : relation.includes(*links)
        end
        def associations(resource)
          { "cost_centers" => [], "organization_units" => [ :parent, :cost_center ], "job_positions" => [ :organization_unit ], "employee_assignments" => [ :employee, :organization_unit, :job_position ] }.fetch(resource.to_s)
        end
        def safe_cell(value)
          text = value.to_s
          text.match?(/\A[[:space:]]*[=+@-]/) ? "'#{text}" : text
        end
      end
    end
  end
end
