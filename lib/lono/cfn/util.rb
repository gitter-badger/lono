module Lono::Cfn::Util
  def are_you_sure?(action)
    if @options[:sure]
      sure = 'y'
    else
      message = case action
      when :update
        "Are you sure you want to want to update the stack with the changes? (y/N)"
      when :delete
        "Are you sure you want to want to delete the stack? (y/N)"
      end
      puts message
      sure = $stdin.gets
    end

    unless sure =~ /^y/
      puts "Exiting without #{action}"
      exit 0
    end
  end
end
