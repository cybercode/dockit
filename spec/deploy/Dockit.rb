def All < SubCommand
  desc 'build', 'build modules'
  def build
    invoke_service 'mod'
    invoke_default 'svc'
  end
end
