# require 'debug'

PuppetLint.new_check(:ctags) do
  def check
    # class/define
    (class_indexes + defined_type_indexes).each do |class_idx|
      class_token = class_idx[:tokens].first
      name_token = class_token.next_token_of(%i[NAME FUNCTION_NAME])
      next unless name_token

      class_name = name_token.value.delete_prefix('::')

      notify :warning, {
        message: "#{class_name}\t#{path}\t#{name_token.line}",
        line: name_token.line,
        column: name_token.column
      }
      notify :warning, {
        message: "::#{class_name}\t#{path}\t#{name_token.line}",
        line: name_token.line,
        column: name_token.column
      }
      notify :warning, {
        message: "#{name_token.prev_code_token.value.capitalize}['#{class_name}']\t#{path}\t#{name_token.line}",
        line: name_token.line,
        column: name_token.column
      }
      notify :warning, {
        message: "#{name_token.prev_code_token.value.capitalize}['::#{class_name}']\t#{path}\t#{name_token.line}",
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
        next if resource_type == 'class'

        notify :warning, {
          message: "#{resource_type.capitalize}['#{resource_name}']\t#{path}\t#{resource_name_token.line}",
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
        message: "$#{token.value}\t#{path}\t#{token.line}",
        line: token.line,
        column: token.column
      }
      notify :warning, {
        message: "$::#{token.value}\t#{path}\t#{token.line}",
        line: token.line,
        column: token.column
      }
    end

    # file/template/epp
    tokens.select { |token| token.type == :FUNCTION_NAME }.each do |token|
      next unless %w[template file epp].include?(token.value) && token.prev_code_token.type == :FARROW

      file_token = token.next_code_token.next_code_token
      next unless %i[SSTRING STRING].include?(file_token.type)

      file = file_token.value
      parts = file.split('/', 2)

      dirname = if token.value == 'epp'
                  'templates'
                else
                  "#{token.value}s"
                end
      module_path = path.split('/manifests/')[0]
      possible_paths = [
        "#{module_path}/#{dirname}/#{parts[1]}",
        "#{module_path}/../#{parts[0]}/#{dirname}/#{parts[1]}",
        "#{module_path}/../../forge/#{parts[0]}/#{dirname}/#{parts[1]}",
        "#{module_path}/../../modules/#{parts[0]}/#{dirname}/#{parts[1]}",
        "#{module_path}/../../profiles/#{parts[0]}/#{dirname}/#{parts[1]}",
        "#{module_path}/../../services/#{parts[0]}/#{dirname}/#{parts[1]}"
      ]
      possible_paths.each do |p|
        next unless File.exist?(p)

        notify :warning, {
          message: "#{file}\t#{p}\t1",
          line: token.line,
          column: token.column
        }
        break
      end
    end

    # file source
    tokens.select { |token| %i[SSTRING STRING].include?(token.type) }.each do |token|
      next unless token.prev_code_token.type == :FARROW && token.value.start_with?('puppet:///')

      file = token.value.split('puppet:///modules/', 2)[1]
      parts = file.split('/', 2)
      dirname = path.split('/manifests/')[0]
      possible_paths = [
        "#{dirname}/files/#{parts[1]}",
        "#{dirname}/../#{parts[0]}/files/#{parts[1]}",
        "#{dirname}/../../forge/#{parts[0]}/files/#{parts[1]}",
        "#{dirname}/../../modules/#{parts[0]}/files/#{parts[1]}",
        "#{dirname}/../../profiles/#{parts[0]}/files/#{parts[1]}",
        "#{dirname}/../../services/#{parts[0]}/files/#{parts[1]}"
      ]
      possible_paths.each do |p|
        next unless File.exist?(p)

        notify :warning, {
          message: "#{token.value}\t#{p}\t1",
          line: token.line,
          column: token.column
        }
        break
      end
    end

    # TODO: class params hieradata keys
  end
end
