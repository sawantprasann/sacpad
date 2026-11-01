class AddNameSearchTokensToVoters < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    unless column_exists?(:voters, :name_search_tokens)
      add_column :voters, :name_search_tokens, :text, array: true, null: false, default: []
    end

    backfill_name_search_tokens

    add_index :voters, :name_search_tokens,
      using: :gin,
      algorithm: :concurrently,
      if_not_exists: true,
      name: "index_voters_on_name_search_tokens"
  end

  def down
    if index_exists?(:voters, :name_search_tokens, name: "index_voters_on_name_search_tokens")
      remove_index :voters, name: "index_voters_on_name_search_tokens", algorithm: :concurrently
    end
    remove_column :voters, :name_search_tokens if column_exists?(:voters, :name_search_tokens)
  end

  private

  # Names are encrypted, so the digests have to be built in Ruby. One statement
  # per batch avoids a round trip per voter and the development log of every array.
  def backfill_name_search_tokens
    Voter.reset_column_information
    logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil

    scope = Voter.where("cardinality(name_search_tokens) = 0").select(
      :id, :first_name, :middle_name, :last_name,
      :native_first_name, :native_middle_name, :native_last_name
    )
    remaining = scope.except(:select).count
    say "backfilling #{remaining} voters"

    scope.find_in_batches(batch_size: 200) do |voters|
      pairs = voters.filter_map { |voter| token_pair(voter) }
      write_tokens(pairs)
    end
  ensure
    ActiveRecord::Base.logger = logger
  end

  def token_pair(voter)
    tokens = Voter.name_search_tokens_for(
      first_name: voter.first_name,
      middle_name: voter.middle_name,
      last_name: voter.last_name,
      native_first_name: voter.native_first_name,
      native_middle_name: voter.native_middle_name,
      native_last_name: voter.native_last_name
    )
    [ voter.id, tokens ]
  rescue ActiveRecord::Encryption::Errors::Decryption
    say "skipped voter #{voter.id}: name could not be decrypted"
    nil
  end

  def write_tokens(pairs)
    return if pairs.empty?

    conn = Voter.connection
    values = pairs.map { |id, tokens| "(#{id.to_i}, #{quote_tokens(tokens)})" }.join(", ")
    conn.execute(<<~SQL)
      UPDATE voters AS v
      SET name_search_tokens = data.tokens
      FROM (VALUES #{values}) AS data(id, tokens)
      WHERE v.id = data.id
    SQL
  end

  def quote_tokens(tokens)
    quoted = tokens.map { |token| Voter.connection.quote(token) }.join(", ")
    "ARRAY[#{quoted}]::text[]"
  end
end
