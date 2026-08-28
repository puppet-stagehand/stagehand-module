PuppetLint.new_check(:variable_contains_upcase) do
  def check
    tokens.select do |r|
      Set[:VARIABLE, :UNENC_VARIABLE].include? r.type
    end.each do |token|
      next unless /[A-Z]/.match?(token.value.gsub(/\[.+?\]/, ''))

      notify :warning, {
        message: 'variable contains a capital letter',
        line: token.line,
        column: token.column,
        token: token,
      }
    end
  end

  def fix(problem)
    problem[:token].value.downcase!
  end
end
