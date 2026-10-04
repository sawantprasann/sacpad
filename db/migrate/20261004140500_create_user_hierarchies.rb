class CreateUserHierarchies < ActiveRecord::Migration[8.1]
  def change
    # closure_tree closure table for the self-referential users tree (unlimited depth, §3.2).
    create_table :user_hierarchies, id: false do |t|
      t.bigint :ancestor_id, null: false
      t.bigint :descendant_id, null: false
      t.integer :generations, null: false
    end

    add_index :user_hierarchies, [ :ancestor_id, :descendant_id, :generations ],
      unique: true, name: "user_anc_desc_idx"
    add_index :user_hierarchies, [ :descendant_id ], name: "user_desc_idx"
  end
end
