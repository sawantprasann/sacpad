module Assistant
  Outcome = Struct.new(:body, :tool_name, :arguments, :draft, :link_path, :link_label, :details, keyword_init: true)
end
