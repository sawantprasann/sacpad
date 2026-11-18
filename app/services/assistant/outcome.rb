module Assistant
  Outcome = Struct.new(:body, :tool_name, :arguments, :draft, :link_path, :link_label, keyword_init: true)
end
