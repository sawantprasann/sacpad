module FormHelper
  # Render a searchable select dropdown for large collections
  # Usage: searchable_collection_select(f, :village_id, Village.order(:name), :id, :name)
  def searchable_collection_select(f, method, collection, value_method, text_method, options = {})
    field_options = options.delete(:field_options) || {}
    label_text = options.delete(:label) || method.to_s.humanize

    content_tag :div, data: { controller: "searchable-select" } do
      # Label
      label = f.label method, label_text, class: "block text-sm font-medium text-gray-700 dark:text-gray-300"

      # Search input
      search_input = content_tag :input, nil,
        type: "text",
        placeholder: "Search #{label_text.downcase}...",
        data: { target: "searchable-select.input", action: "searchable-select#search" },
        class: "mt-1 block w-full rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-white"

      # Clear button
      clear_btn = content_tag :button, "Clear",
        type: "button",
        data: { action: "searchable-select#clearSearch" },
        class: "mt-1 text-xs text-blue-600 hover:underline dark:text-blue-400"

      # Select field
      select = f.collection_select method, collection, value_method, text_method,
        field_options.merge(include_blank: "Select an option"),
        class: "mt-1 block w-full rounded-lg border border-gray-300 px-3 py-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white",
        data: { target: "searchable-select.select" }

      label + search_input + clear_btn + select
    end
  end
end
