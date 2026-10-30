# Phonetic Latin-to-native spelling for names saved in English.
# "Wagholi" becomes a Devanagari spelling when the Lok Sabha language is Marathi.
# A hand-corrected native name is kept; this only fills a blank one.
class NativeScript
  LOCALES = %w[mr].freeze

  SCRIPTS = {
    "mr" => {
      halant: "्",
      vowels: [
        [ "aa", "आ", "ा" ], [ "ai", "ऐ", "ै" ], [ "au", "औ", "ौ" ],
        [ "ee", "ई", "ी" ], [ "ii", "ई", "ी" ], [ "oo", "ऊ", "ू" ], [ "uu", "ऊ", "ू" ],
        [ "a", "आ", "ा" ], [ "i", "इ", "ि" ], [ "u", "उ", "ु" ],
        [ "e", "ए", "े" ], [ "o", "ओ", "ो" ]
      ],
      consonants: [
        [ "ksh", "क्ष" ], [ "kh", "ख" ], [ "gh", "घ" ], [ "chh", "छ" ], [ "ch", "च" ],
        [ "jh", "झ" ], [ "th", "थ" ], [ "dh", "ध" ], [ "ph", "फ" ], [ "bh", "भ" ],
        [ "sh", "श" ], [ "ng", "ङ" ], [ "ny", "ञ" ],
        [ "k", "क" ], [ "g", "ग" ], [ "c", "च" ], [ "j", "ज" ],
        [ "t", "त" ], [ "d", "द" ], [ "n", "न" ], [ "p", "प" ], [ "b", "ब" ],
        [ "m", "म" ], [ "y", "य" ], [ "r", "र" ], [ "l", "ल" ],
        [ "v", "व" ], [ "w", "व" ], [ "s", "स" ], [ "h", "ह" ],
        [ "q", "क" ], [ "f", "फ" ], [ "z", "ज" ]
      ]
    }
  }.freeze

  def self.transliterate(text, locale)
    script = SCRIPTS[locale.to_s]
    source = text.to_s.strip
    return if script.nil? || source.blank?

    converted = source.gsub(/[A-Za-z]+/) { |word| convert_word(word.downcase, script) }
    return if converted.blank? || converted.casecmp?(source)

    converted
  end

  def self.convert_word(word, script)
    vowels = script[:vowels]
    consonants = script[:consonants]
    out = +""
    index = 0
    after_consonant = false

    while index < word.length
      consonant = match(consonants, word, index)
      if consonant
        out << consonant[1]
        index += consonant[0].length
        vowel = match(vowels, word, index)
        if vowel
          out << vowel[2]
          index += vowel[0].length
        end
        after_consonant = true
        next
      end

      vowel = match(vowels, word, index)
      if vowel
        out << (after_consonant ? vowel[2] : vowel[1])
        after_consonant = false
        index += vowel[0].length
        next
      end

      after_consonant = false
      out << word[index]
      index += 1
    end

    out
  end
  private_class_method :convert_word

  def self.match(table, word, index)
    table.find { |key,| word[index, key.length] == key }
  end
  private_class_method :match
end
