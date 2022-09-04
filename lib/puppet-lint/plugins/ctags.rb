# require 'debug'

PuppetLint.new_check(:ctags) do
  def check
    # class/define
    (class_indexes + defined_type_indexes).each do |class_idx|
      class_token = class_idx[:tokens].first
      name_token = class_token.next_token_of(%i[NAME FUNCTION_NAME])
      next unless name_token

      notify :warning, {
        message: name_token.value,
        line: name_token.line,
        column: name_token.column
      }
      notify :warning, {
        message: "#{name_token.prev_code_token.value}[#{name_token.value}]",
        line: name_token.line,
        column: name_token.column
      }
    end

    # resource
    tokens.select { |token| token.type == :COLON }.each do |colon_token|
      prev_code_token = colon_token.prev_code_token
      resource_name_tokens = []
      case prev_code_token.type
      when :RBRACK
        while prev_code_token.type != :LBRACK
          resource_name_tokens.push(prev_code_token) if prev_code_token.type == :SSTRING
          prev_code_token = prev_code_token.prev_code_token
        end
      when :SSTRING
        resource_name_tokens.push(prev_code_token)
      end

      resource_name_tokens.each do |resource_name_token|
        resource_name = resource_name_token.value.delete_prefix('::')

        resource_type_token = resource_name_token.prev_token_of(:LBRACE).prev_code_token
        resource_type = resource_type_token.value.delete_prefix('::')

        notify :warning, {
          message: "#{resource_type.capitalize}['#{resource_name}']",
          line: resource_name_token.line,
          column: resource_name_token.column
        }
      end
    end

    # topscope variables
    tokens.select { |token| token.type == :VARIABLE }.each do |token|
      local_variables = []
      (class_indexes + defined_type_indexes).each do |idx|
        idx[:tokens].select { |t| t.type == :VARIABLE }.each do |v|
          local_variables.push(v) if v.next_code_token.type == :EQUALS
        end
      end
      next unless token.next_code_token.type == :EQUALS && !local_variables.include?(token)

      notify :warning, {
        message: "$#{token.value}",
        line: token.line,
        column: token.column
      }
    end

    # TODO: file, template
  end
end
