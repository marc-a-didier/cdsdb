
# Add some very useful methods to the String class
class String
    def to_sql
        return "'"+self.gsub(/'/, "''")+"'"
    end

    def check_plural(quantity)
        return quantity < 2 ? self : self+'s'
    end

    def to_ms_length
        m, s, ms = self.split(/[:,\.]/)
        return m.to_i*60*1000+s.to_i*1000+ms.to_i
    end

    # Replaces \n in string with true lf to display in memo
    def to_memo
        return self.gsub(/\\n/, "\n")
    end

    # Replaces lf in string with litteral \n to store in the db
    def to_dbstring
        return self.gsub(/\n/, '\n')
    end

    # Not a good idea to introduce a dep on CGI...
    def to_html
        return CGI::escapeHTML(self)
    end

    def to_html_bold
        return '<b>'+self.to_html+'</b>'
    end

    def to_html_italic
        return '<i>'+self.to_html+'</i>'
    end

    def clean_path
        return self.gsub(/\//, '_')
    end

    def make_fat_compliant
        return self.gsub(/[\*|\?|\\|\:|\<|\>|\"|\|]/, '_')
    end

    # When parsed, a date string has no time zone info, so it's set to UTC by DateTime.parse()
    # The resulting Integer (time_t) from parse...to_i is in UTC.
    # Then when Time.at(Integer) is called, it returns the time in LOCAL time so it adds/removes
    # the time zone diff to the returned Time.
    # So when the time_t is displayed via to_std_date via Time.at() it is offset of the time zone,
    # and the result is wrong.
    # To compensate and get back on our feet the time zone is substracted from the parsed date.
    def to_date_from_utc
        begin
            return DateTime.parse(self).to_time.to_i-Time.now.utc_offset
        rescue ArgumentError
            return 0
        end
    end

    # Returns the DATE of the string at 00:00 local time (utc offset is set)
    def to_date
        begin
            return Time.at(Date.parse(self).to_time).to_i
        rescue ArgumentError
            return 0
        end
    end


    # Colorization of ANSI console
    def colorize(color_code)
        "\e[#{color_code}m#{self}\e[0m"
    end

    def black;   colorize(30); end
    def red;     colorize(31); end
    def green;   colorize(32); end
    def brown;   colorize(33); end
    def blue;    colorize(34); end
    def magenta; colorize(35); end
    def cyan;    colorize(36); end
    def gray;    colorize(37); end

    def bold;    colorize(1);  end
    def blink;   colorize(5);  end
    def invert;  colorize(7);  end
end


class Integer
    alias :to_sql :to_s
end

class Float
    alias :to_sql :to_s
end



class Numeric

    SEC_MS_LENGTH  = 1000
    MIN_MS_LENGTH  = 60*SEC_MS_LENGTH
    HOUR_MS_LENGTH = 60*MIN_MS_LENGTH

    def to_ms_length
        m  = self/MIN_MS_LENGTH
        s  = (self-m*MIN_MS_LENGTH)/SEC_MS_LENGTH
        ms = self % SEC_MS_LENGTH
        return sprintf('%02d:%02d.%03d', m, s, ms)
    end

    def to_hr_length
        h = self/HOUR_MS_LENGTH
        m = (self-h*HOUR_MS_LENGTH)/MIN_MS_LENGTH
        s = (self-h*HOUR_MS_LENGTH-m*MIN_MS_LENGTH)/SEC_MS_LENGTH
        return sprintf('%02d:%02d:%02d', h, m, s)
    end

    def to_day_length
        h = self/HOUR_MS_LENGTH
        d = h/24
        h = h-(d*24)
        r = self - d*24*HOUR_MS_LENGTH - h*HOUR_MS_LENGTH
        m = r / MIN_MS_LENGTH
        s = (r - m*MIN_MS_LENGTH)/SEC_MS_LENGTH
        return sprintf('%d %s, %02d:%02d:%02d', d, 'day'.check_plural(d), h, m, s)
    end

    def to_sec_length
        m  = self/60
        s  = self%60
        return sprintf('%02d:%02d', m, s)
    end

    def to_std_date(zero_msg = 'Unknown')
        return self == 0 ? zero_msg : Time.at(self).strftime('%a %b %d %Y %H:%M:%S')
    end
end
