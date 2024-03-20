class AddLlmCheck < ActiveRecord::Migration[7.0]
  def up
    create_table :llm_object do |t|
      t.references :events, foreign_key: true
      t.datetime :created_at
      t.datetime :updated_at
      t.string :scrape_or_process
      t.string :model
      t.string :prompt
      t.string :input
      t.string :output
    end
    add_reference :events, :llm_object, foreign_key: true
    add_column :events, :open_science, :string, array: true, default: []
    add_column :events, :curation, :bool, default: true
    add_column :materials, :llm_processed, :bool, default: false
  end

  def down
    drop_table :llm_object
    remove_reference :events, :llm_object, foreign_key: true
    remove_column :events, :open_science, :string, array: true, default: []
    remove_column :events, :curation, :bool, default: true
    remove_column :materials, :llm_processed, :bool, default: false
  end
end
