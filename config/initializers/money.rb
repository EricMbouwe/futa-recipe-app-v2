Money.default_currency = Money::Currency.new("EUR")
Money.locale_backend = :i18n
Money.rounding_mode = BigDecimal::ROUND_HALF_EVEN

class Money
  # The available currency ISO 4217 codes.
  #
  # Returns an Array of Strings.
  def self.currency_codes
    @@currency_codes ||= Money::Currency.all.map(&:iso_code)
  end

  # Overrides `Money#to_hash` method.
  #
  # Returns a Hash.
  def to_hash
    {
        value: self.cents,
        currency: self.currency.iso_code,
    }
  end
end

MoneyRails.configure do |config|
  # set the default currency
  config.default_currency = :eur
end
