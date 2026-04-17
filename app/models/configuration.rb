class Configuration < ApplicationRecord
  SECRET_SEGMENTS = /(?:^|_)(key|secret|token)(?:_|$)/i

  validates :name, presence: true, uniqueness: true
  after_commit :apply_callbacks

  def self.expect(*names, &block)
    names = names.map(&:to_s)
    expected_names.merge(names)
    case [names, block]
    in [name], nil then self[name]
    in Array, nil then values_at(*names)
    else
      callback = -> { block.call(*values_at(*names)) }
      @callbacks ||= Hash.new { |h, k| h[k] = [] }
      names.each do |name|
        @callbacks[name] << callback
      end
      callback.call
    end
  end

  def self.expected_names = @expected_names ||= Set.new

  def self.callbacks = @callbacks.dup

  def self.all_and_expected
    existing = order(:name).to_a
    existing_names = existing.map(&:name).to_set
    missing = (expected_names - existing_names).sort.map { |name| new(name: name) }
    (existing + missing).sort_by(&:name)
  end
  # -- Hash-like class interface --

  def self.[](name) = find_by(name: name)&.value

  def self.fetch(name, *args, &block)
    name = name.to_s
    where(name:).pluck(:name, :value).to_h.fetch(name, *args, &block)
  end

  def self.values_at(*names)
    names = names.map(&:to_s)
    where(name: names).pluck(:name, :value).to_h.values_at(*names)
  end

  def self.fetch_values(*names, &block)
    names = names.map(&:to_s)
    where(name: names).pluck(:name, :value).to_h.fetch_values(*names, &block)
  end

  def self.each_pair(&block)
    return to_enum(:each_pair) unless block
    find_each { |config| block.call(config.name, config.value) }
  end

  def self.to_h
    pluck(:name, :value).to_h
  end

  def self.to_hash = to_h

  # -- Instance methods --

  def secret? = SECRET_SEGMENTS.match?(name)

  def display_value
    return value unless secret? && value.present? && value.length > 4

    masked = "#{"*" * (value.length - 4)}#{value.last(4)}"
    (masked.length > 40) ? "…#{masked.last(39)}" : masked
  end

  private

  def apply_callbacks = self.class.callbacks&.[](name)&.each(&:call)
end
