module SmarterLogging
  module Extensions

    module String # adding functionality without monkey patching String

      # Create a random String of given length, using given character set
      #
      # Character set is an Array which can contain Ranges, Arrays, Characters
      #
      # Examples
      #
      #     String.random
      #     String.random(10, ['0'..'9','A'..'F'] )
      #     => "3EBF48AD3D"
      #
      #     BASE64_CHAR_SET =  ["A".."Z", "a".."z", "0".."9", '_', '-']
      #     String.random(10, BASE64_CHAR_SET)
      #     => "xM_1t3qcNn"
      #
      #     SPECIAL_CHARS = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "-", "_", "=", "+", "|", "/", "?", ".", ",", ";", ":", "~", "`", "[", "]", "{", "}", "<", ">"]
      #     BASE91_CHAR_SET =  ["A".."Z", "a".."z", "0".."9", SPECIAL_CHARS]
      #     String.random(10, BASE91_CHAR_SET)
      #      => "S(Z]z,J{v;"
      #
      # CREDIT: Tilo Sloboda
      #
      # SEE: https://gist.github.com/tilo/3ee8d94871d30416feba

      def self.random(len=32, character_set = ["A".."Z", "a".."z", "0".."9"])
        chars = character_set.map{|x| x.is_a?(Range) ? x.to_a : x }.flatten
        Array.new(len){ chars.sample }.join
      end

    end
  end
end
