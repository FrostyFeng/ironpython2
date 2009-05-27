﻿=begin
   Utilities for C# source file generation.
=end

#
# A simple generator. Takes whatever is marked as generated code and replaces it by a value returned by a passed block.
#
def generate(generator)
  file = get_generated_file(generator)
  content = read_file_content(file)
  
  gen_begin = '// *** BEGIN GENERATED CODE ***'
  gen_end = '// *** END GENERATED CODE ***'
  
  content.sub!(/([^\r\n]*)#{Regexp.escape(gen_begin)}.*#{Regexp.escape(gen_end)}/m) do
     "#$1#{gen_begin}\r\n" +
     "#$1// Generated by #{File.basename(generator)}\r\n\r\n" +
     indent(yield, $1) +
     "\r\n\r\n" +
     "#$1#{gen_end}" 
  end  
  
  write_file_content(file, content)
end

#
# Expands templates in the given file.
#
def expand_templates(generator_file)
  file = get_generated_file(generator_file)
  content = read_file_content(file)
  
  eval_metavariables(content)

  expanded_count = 0
  content.gsub!(/(^\s*#if GENERATOR(.*?)^\s*(#else.*?^(.*?)^\s*)?#endif\s*)^\s*#region Generated by(.*?)^\s*#endregion/m) do
    expanded_count += 1
    
    prefix = $1
    generators = $2
    template = $4
    
    generator_class = Class.new(Generator)
    generator_class.class_eval generators
    generator = generator_class.new
    
    generator.template = template
    generator.generated = ""
    generator.generate
    
    "#{prefix}#region Generated by #{generator_file}\r\n#{generator.generated}#endregion"
  end
  
  puts "Templates expanded: #{expanded_count}"
  
  write_file_content(file, content)
end

#
# A subclass is created and instantiated and "generate" method is called for each template.
#
class Generator
  Open = Regexp.escape('/*')
  Close = Regexp.escape('*/')
  ParamStart = Regexp.escape('/*$')
  ParamEnd = Close
  
  attr_accessor :template, :generated
  
  def generate
    t = @template.dup
      
    # $MethodName
    t.gsub!(/#{ParamStart}([A-Za-z0-9]+)#{ParamEnd}/) { send($1) }
    
    # $MethodName{...}
    t.gsub!(/#{ParamStart}([A-Za-z0-9]+)[{]#{ParamEnd}(.*?)#{Open}[}]#{Close}/) { send($1, $2) }
    
    @generated << t
  end
  
  def append_generated str
    @generated << str.gsub!("\n", "\r\n")
  end
end

#
# Helpers
#

def eval_metavariables(content)
  content.match(/\/\*\$\$\*\/([^;]*)/) do
    eval('$' + $1)
    puts $1
  end
end

def get_generated_file(generator)
  generator.sub('Generator.rb', 'Generated.cs')
end

def read_file_content(file)
  File.open(file, "rb") { |f| break f.read }
end

def write_file_content(file, content)
  File.open(file, "wb") { |f| f.write(content) }
rescue
  retry if tf_edit(file) 
  raise
end

def tf_edit(file)
  `tf.exe edit #{file}`
  $?.exitstatus == 0
end

def indent(text, indentation)
  indentation + text.split("\n").join("\r\n" + indentation)
end