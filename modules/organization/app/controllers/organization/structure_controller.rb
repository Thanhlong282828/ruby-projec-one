module Organization
  class StructureController < ApplicationController
    def tree
      @tree = HrmOrganization::Application::Queries::Structure.new.call(actor: current_user, view: :tree)
      @nodes = flatten_tree(@tree)
    end
    def headcount
      @rows = HrmOrganization::Application::Queries::Structure.new.call(actor: current_user, view: :headcount)
    end
    private
    def flatten_tree(nodes, depth = 0)
      nodes.flat_map { |node| [ node.merge(depth: depth) ] + flatten_tree(node[:children], depth + 1) }
    end
  end
end
