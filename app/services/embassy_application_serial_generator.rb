class EmbassyApplicationSerialGenerator
  def self.next
    today  = Date.current
    prefix = "RE-#{today.strftime('%m%d')}-"
    count  = EmbassyApplication.where("serial LIKE ?", "#{prefix}%").count
    "#{prefix}#{letter_for(count)}"
  end

  def self.letter_for(n)
    alphabet = ("A".."Z").to_a
    return alphabet[n] if n < 26
    "#{alphabet[(n / 26) - 1]}#{alphabet[n % 26]}"
  end
end
