require "lono"
require "byebug"

class Lono::Cfn::Base
  include Lono::Cfn::AwsServices
  include Lono::Cfn::Util

  def initialize(stack_name, options={})
    @stack_name = stack_name
    @options = options
    @project_root = options[:project_root] || '.'
    Lono::ProjectChecker.check(@project_root) unless options[:lono] # already ran checker in lono generate

    @template_name = options[:template] || @stack_name
    @param_name = options[:param] || @template_name
    @template_path = get_source_path(@template_name, :template)
    @param_path = get_source_path(@param_name, :param)
    puts "Using template: #{@template_path}" unless @options[:mute_using]
    puts "Using parameters: #{@param_path}" unless @options[:mute_using]
  end

  def run
    params = generate_all
    save_stack(params) # defined in the sub class
  end

  def generate_all
    generate_templates if @options[:lono]
    check_for_errors
    generate_params(mute: @options[:mute_params])
  end

  def generate_templates
    Lono::Template::DSL.new(
      project_root: @project_root,
      pretty: true
    ).run
  end

  def generate_params(options={})
    generator_options = {
      project_root: @project_root,
      path: @param_path,
      allow_no_file: true
    }.merge(options)
    generator = Lono::Param::Generator.new(@param_name, generator_options)
    generator.generate  # Writes the json file in CamelCase keys format
    generator.params    # Returns Array in underscore keys format
  end

  def check_for_errors
    errors, warns = check_files
    unless errors.empty?
      puts "Please double check the command you ran.  There were some errors."
      puts "ERROR: #{errors.join("\n")}".colorize(:red)
      exit
    end
    unless warns.empty?
      puts "Please double check the command you ran.  There were some warnings."
      puts "WARN: #{warns.join("\n")}".colorize(:yellow)
    end
  end

  def check_files
    errors, warns = [], []
    unless File.exist?(@template_path)
      warns << "Template file missing: could not find #{@template_path}"
    end
    if @options[:param] && !File.exist?(@param_path)
      warns << "Parameters file missing: could not find #{@param_path}"
    end
    [errors, warns]
  end

  # if existing in params path then use that
  # if it doesnt assume it is a full path and check that
  # else fall back to convention, which also eventually gets checked in check_for_errors
  #
  # Type - :param or :template
  def get_source_path(path, type)
    if path.nil?
      default_convention_path = convention_path(@stack_name, type)
    else
      # convention path based on the input from the user
      convention_path(path, type)
    end
  end

  def convention_path(name, type)
    path = case type
    when :template
      format = detect_format
      "#{@project_root}/output/#{name}.#{format}"
    when :param
      "#{@project_root}/params/#{name}.txt"
    else
      raise "hell: dont come here"
    end
    path.sub(/^\.\//, '')
  end

  # Returns String with value of "yml" or "json".
  def detect_format
    formats = Dir.glob("#{@project_root}/templates/**/*").
                map { |path| path.sub(/\.erb$/, '') }.
                map { |path| File.extname(path) }.
                reject { |s| s.empty? }. # reject ""
                select { |s| s.include?("yml") || s.include?("json") }.
                uniq
    if formats.size > 1
      puts "ERROR: Detected multiple formats: #{formats.join(", ")}".colorize(:red)
      puts "All the output files must use the same format.  Either all json or all yml."
      exit 1
    elsif formats.size == 1
      formats.first.sub(/^\./,'')
    else
      puts "WARN: Did not detect any template formats. Defaulting to yml.  Please check the config and templates folders.".colorize(:yellow)
      "yml" # default format
    end
  end

  # All CloudFormation states listed here:
  # http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-describing-stacks.html
  def stack_status(stack_name)
    return true if testing_update?
    return false if @options[:noop]

    resp = cfn.describe_stacks(stack_name: stack_name)
    status = resp.stacks[0].stack_status
  end

  def exist_unless_updatable(status)
    return true if testing_update?
    return false if @options[:noop]

    unless status =~ /_COMPLETE$/
      puts "Cannot create a change set for the stack because the #{@stack_name} is not in an updatable state.  Stack status: #{status}"
      quit(1)
    end
  end

  # To allow mocking in specs
  def quit(signal)
    exit signal
  end
end
