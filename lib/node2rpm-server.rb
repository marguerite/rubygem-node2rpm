dir = File.basename(__FILE__, File.extname(__FILE__))
path = File.join(File.dirname(File.expand_path(__FILE__)), dir)
Dir.glob(path + '/*').each do |i|
  require dir + '/' + File.basename(i) if File.basename(i).end_with?('.rb')
end
