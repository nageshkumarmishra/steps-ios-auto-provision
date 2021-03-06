# Log
class Log
  @verbose = true

  class << self
     attr_accessor :verbose
  end

  def self.info(str)
    puts("\n\e[34m#{str}\e[0m")
  end

  def self.print(str)
    puts(str.to_s)
  end

  def self.success(str)
    puts("\e[32m#{str}\e[0m")
  end

  def self.warn(str)
    puts("\e[33m#{str}\e[0m")
  end

  def self.error(str)
    puts("\e[31m#{str}\e[0m")
  end

  def self.debug(str)
    puts(str.to_s) if @verbose
  end

  def self.secure_value(value)
    return '' if value.empty?
    '***'
  end
end
