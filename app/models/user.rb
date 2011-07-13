class User < Account
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable,
    :ga_otp_authenticatable,
    :yk_otp_authenticatable,
    :registerable,
    :confirmable,
    :recoverable,
    :trackable,
    :validatable,
    :lockable,
    :timeoutable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :password, :password_confirmation, :remember_me, :time_zone, 
    :merchant, :require_ga_otp, :require_yk_otp

  attr_accessor :captcha,
    :skip_captcha,
    :new_password,
    :new_password_confirmation,
    :current_password

  before_create :generate_name

  has_many :trade_orders,
    :dependent => :destroy

  has_many :purchase_trades,
    :class_name => "Trade",
    :foreign_key => "buyer_id"

  has_many :sale_trades,
    :class_name => "Trade",
    :foreign_key => "seller_id"

  has_many :invoices,
    :dependent => :destroy

  has_many :yubikeys,
    :dependent => :destroy

  validates :email,
    :uniqueness => true,
    :presence => true

  validate :captcha do
    if captcha.nil? and new_record?
      unless skip_captcha
        errors[:captcha] << (I18n.t "errors.answer_incorrect")
      end
    end
  end

  def captcha_checked!
    self.captcha = true
  end

  # Generates a new receiving address if it hasn't already been refreshed during the last hour
  def generate_new_address
    unless last_address_refresh && last_address_refresh > DateTime.now.advance(:hours => -1)
      self.last_address_refresh = DateTime.now
      self.bitcoin_address = Bitcoin::Client.instance.get_new_address(id.to_s)
      save
    end
  end

  def bitcoin_address
    super or (generate_new_address && super)
  end

  def confirm!
    super
    UserMailer.registration_confirmation(self).deliver
  end

  def account
    puts " *** Deprecated getter"
    name
  end

  def account=(a)
    puts " *** Deprecated setter"
    self.name = a
  end

  protected

    def self.find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      account = conditions.delete(:account)
      where(conditions).where(["name = :value OR email = :value", { :value => name }]).first
    end

    def generate_name
      self.name = "BC-U#{"%06d" % (rand * 10 ** 6).to_i}"
    end
end
