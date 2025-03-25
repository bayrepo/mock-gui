def sanitize_filename(filename)
  filename = filename.strip
  sanitized = filename.gsub(/[^a-zA-Z0-9_]/, "_")
  sanitized.gsub!(/_+/, "_")
  sanitized.gsub!(/^_+|_+$/, "")
  sanitized
end

def sanitize_rcptname(filename)
  filename = filename.strip
  sanitized = filename.gsub(/[^a-zA-Z0-9_\.]/, "_")
  sanitized.gsub!(/_+/, "_")
  sanitized.gsub!(/^_+|_+$/, "")
  sanitized
end

def check_partname_in_array(filename, search_array)
  fnd = false
  search_array.each do |item|
    if filename.include?(item)
      fnd = true
      break
    end
  end
  fnd
end

def check_safe_path(filename)
  current_dir = Dir.pwd
  home_dir = Dir.home
  filename.start_with?("/etc/mock") || filename.start_with?(current_dir) || filename.start_with?(home_dir)
end

def get_spec_files_in_dir(directory)
  Dir.glob(File.join(directory, "**", "*")).reject { |f| File.directory?(f) }.select { |f| File.extname(f) == ".spec" }.map { |f| f.delete_prefix(directory + "/") }
end

def get_src_rpm_files_in_dir(directory)
  Dir.glob(File.join(directory, "**", "*")).reject { |f| File.directory?(f) }.select { |f| f.end_with?(".src.rpm") }.map { |f| f.delete_prefix(directory + "/") }
end

def get_log_paths(directory)
  Dir.glob(File.join(directory, "**", "*")).reject { |f| File.directory?(f) }.select { |f| File.extname(f) == ".log" }.map { |f| f.delete_prefix(directory + "/") }
end

def get_rpm_paths(directory)
  Dir.glob(File.join(directory, "**", "*")).reject { |f| File.directory?(f) }.select { |f| File.extname(f) == ".rpm" }.map { |f| f.delete_prefix(directory + "/") }
end

def get_log_paths_success(directory)
  Dir.glob(File.join(directory, "**", "*")).reject { |f| File.directory?(f) }.select { |f| File.extname(f) == ".log" }.reject { |f| File.basename(f) == "process.log" }
end

def get_rpms_list(directory)
  Dir.glob(File.join(directory, "**", "*.rpm")).reject { |f| File.directory?(f) || f =~ /repodata\// }.map { |f| f.delete_prefix(directory + "/") }
end
