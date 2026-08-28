# frozen_string_literal: true

PuppetLint.new_check(:lookup_in_parameter) do
  def check
    active = false
    tokens.each do |token|
      case token.type
      when :CLASS, :DEFINE
        active = 0 if token.next_code_token.type == :NAME && token.next_code_token.next_code_token.type == :LPAREN
      when :LPAREN
        active += 1 if active
      when :RPAREN
        if active
          active -= 1
          active = false if active.zero?
        end
      when :FUNCTION_NAME
        next unless active
        next unless token.value == 'lookup'

        notify :warning, {
          message: 'lookup used to set the default value of a parameter',
          line: token.line,
          column: token.column,
          token: token,
        }
      end
    end
  end
end
