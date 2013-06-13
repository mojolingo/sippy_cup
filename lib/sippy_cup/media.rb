module SippyCup
  class Media
    VALID_STEPS = %w{silence dtmf}.freeze

    def initialize
      @sequence = []
    end

    def <<(input)
      get_step input # validation
      @sequence << input
    end

    def compile!
      @sequence.each do |input|
        action, value = get_step input
        
        case action
        when 'silence'
          # value is the duration in milliseconds
          # append that many milliseconds of silent RTP audio
        when 'dtmf'
          # value is the DTMF digit to send
          # append that RFC2833 digit
        else
        end
      end
    end
  private
    def get_step(input)
      action, value = item.split ':'
      raise "Invalid Sequence: #{item}" unless VALID_STEPS.include? action

      action, item
    end
  end
end
