class Voter
  # Substring search over encrypted names. Deterministic encryption can only
  # match a whole field, so each save stores HMAC digests of the name's
  # substrings. A query word is one digest, and Postgres array containment
  # finds the rows. The digests are not the name.
  module NameSearch
    MAX_INDEXED_LENGTH = 64

    module_function

    def apply(relation, query)
      words = query.to_s.squish.downcase.split
      return relation.none if words.empty?

      if words.all? { |word| indexable_word?(word) }
        with_tokens(relation, words)
      else
        verify(relation, query, words)
      end
    end

    def tokens_for(searchable)
      pieces = searchable.to_s.split.flat_map { |word| indexed_pieces(word) }.uniq
      pieces.map { |piece| blind_token(piece) }.sort
    end

    def searchable_from(first_name:, middle_name: nil, last_name: nil, native_first_name: nil, native_middle_name: nil, native_last_name: nil)
      english = [ first_name, middle_name, last_name ].compact_blank.join(" ")
      native = [ native_first_name, native_middle_name, native_last_name ].compact_blank.join(" ")
      [ english, native ].compact_blank.join(" ").downcase
    end

    def indexable_word?(word)
      word.length >= 2 && word.length <= MAX_INDEXED_LENGTH
    end

    # Bound parameters, not interpolated SQL. The values are HMAC digests.
    def with_tokens(relation, words)
      tokens = words.map { |word| blind_token(word) }.uniq
      relation.where("voters.name_search_tokens @> ARRAY[?]::text[]", tokens)
    end

    # One-character words are too common to index. Narrow with the other words,
    # then confirm the same way the in-memory matcher does.
    def verify(relation, query, words)
      indexable = words.select { |word| indexable_word?(word) }
      narrowed = indexable.empty? ? relation : with_tokens(relation, indexable)
      ids = narrowed.unscope(:order, :includes, :select).distinct.pluck(Arel.sql("voters.id"))
      matched = []
      ids.each_slice(500) do |slice|
        Voter.where(id: slice).select(
          :id, :first_name, :middle_name, :last_name,
          :native_first_name, :native_middle_name, :native_last_name
        ).each do |voter|
          matched << voter.id if voter.matches_name?(query)
        end
      end
      relation.where(id: matched)
    end

    def indexed_pieces(word)
      chars = word.chars
      return [] if chars.length < 2

      limit = [ chars.length, MAX_INDEXED_LENGTH ].min
      pieces = []
      chars.length.times do |start_at|
        finish_at = [ start_at + limit - 1, chars.length - 1 ].min
        ((start_at + 1)..finish_at).each do |end_at|
          pieces << chars[start_at..end_at].join
        end
      end
      pieces << word if chars.length > MAX_INDEXED_LENGTH
      pieces
    end

    def blind_token(value)
      key = ActiveRecord::Encryption.config.deterministic_key.to_s
      raise "Missing deterministic encryption key" if key.blank?

      OpenSSL::HMAC.hexdigest("SHA256", key, value.to_s)[0, 32]
    end
  end
end
