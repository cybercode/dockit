class Mod < SubCommand
  desc 'build', 'prep and build this service'
  def build
    invoke_default
  end
end
