class KeywordDictionary < Dictionary

  private

  def dictionary_filepath
    File.join(Rails.root, "config", "dictionaries", "keywords.yml")
  end

end
