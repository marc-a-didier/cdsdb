# !/usr/bin/ruby

# require 'sqlite3'
# require 'dbintf'
# require 'dbutils'
# require 'utils'

module DBClassIntf

    def initialize
        reset
    end

    # Initialize struct members from their names: if it begins with r or i, initialize as an int
    # and as a string if it begins with s or m.
    def reset
        self.members.each_with_index { |member, i|
            # i == 0 means first field, that is the primary key which is set to -1 to tell that the entry is not valid
            if i == 0
                self[i] = -1
            else
                self[i] = case member.to_s[0]
                    when "r", "i" then 0  # r or i
                    when "s", "m" then "" # s or m
                    when "f"      then 0.0
                    else
                        raise "Unknow data type"
                end
            end
        }
        return self
    end

    def tbl_name
        return self.members[0][1..-1]+"s"
    end

    def generate_where_on_pk
        return "WHERE #{self.members[0].to_s}=#{self[0]}"
    end

    def generate_insert
        sql = "INSERT INTO #{tbl_name} VALUES ("
        self.each { |value| sql += value.to_sql+"," }
        return sql[0..-2]+");" # Remove last ,
    end

    def generate_update
        old = self.clone.sql_load
        sql = "UPDATE #{tbl_name} SET "
        self.each_with_index { |value, i| sql += self.members[i].to_s+"="+value.to_sql+"," if value != old[i] }
        return sql[-1] == " " ? "" : sql[0..-2]+" "+generate_where_on_pk+";"
    end

    # Set class attributes from a full sqlite3 row
    def load_from_row(row)
        row.each_with_index { |val, i| self[i] = val } # @dbs[i].kind_of?(Numeric) ? val.to_i : val }
        return self
    end

    # Load a full sqlite3 row from the pk field
    def sql_load
        row = DBIntf.get_first_row("SELECT * FROM #{tbl_name} #{generate_where_on_pk};")
        return row.nil? ? reset : load_from_row(row)
    end

    def sql_update
        sql = generate_update
        unless sql.empty?
            DBUtils.client_sql(sql)
TRACE.debug("DB update : #{sql}".red)
        end
        return self
    end

    def sql_add
        DBUtils.client_sql(generate_insert)
        return self
    end

    def sql_del
        DBUtils.client_sql("DELETE FROM #{tbl_name} #{generate_where_on_pk};")
        return self
    end

    def ref_load(ref_val)
        self[0] = ref_val
        return sql_load
    end

    def get_last_id
        id = DBIntf.get_first_value("SELECT MAX(#{self.members[0].to_s}) FROM #{tbl_name};")
        return id.nil? ? 0 : id.to_i
    end

    def valid?
        return self[0] != -1
    end

    def disp_value(val)
        valid? ? val : nil
    end
end

ArtistDBClass = Struct.new(:rartist, :sname, :swebsite, :rorigin, :mnotes) do

    include DBClassIntf

    def add_new
        reset
        self.rartist = get_last_id+1
        self.sname = "New artist"
        return sql_add
    end

    def compile?
        return self.rartist == 0
    end
end

RecordDBClass = Struct.new(:rrecord, :icddbid, :rartist, :stitle, :iyear, :rlabel,
                           :rgenre, :rmedia, :rcollection, :iplaytime, :isetorder, :isetof,
                           :scatalog, :mnotes, :idateadded, :idateripped, :iissegmented, :irecsymlink,
                           :fpeak, :fgain) do

    include DBClassIntf

    def add_new(rartist)
        reset
        self.rrecord = get_last_id+1
        self.rartist = rartist
        self.stitle = "New record"
        self.idateadded = Time.now.to_i
        self.fpeak = 0.0
        self.fgain = 0.0
        return sql_add
    end

    def segmented?
        return self.iissegmented == 1
    end

    def compile?
        return self.rartist == 0
    end
end

SegmentDBClass = Struct.new(:rsegment, :rrecord, :rartist, :iorder, :stitle, :iplaytime, :mnotes) do

    include DBClassIntf

    def add_new(rartist, rrecord)
        reset
        self.iorder = DBIntf.get_first_value("SELECT MAX(iorder)+1 FROM segments WHERE rrecord=#{rrecord}")
        self.iorder = self.iorder.nil? ? 1 : self.iorder.to_i
        self.rsegment = get_last_id+1
        self.rrecord = rrecord
        self.rartist = rartist
        self.stitle = "New segment"
        return sql_add
    end

    # Loads values from the first segment of a given record
    def first_segment(rrecord)
        return load_from_row(DBIntf.get_first_row("SELECT * FROM segments WHERE rrecord=#{rrecord};"))
    end
end

TrackDBClass = Struct.new(:rtrack, :rsegment, :rrecord, :iorder, :iplaytime, :stitle, :mnotes, :isegorder,
                          :iplayed, :irating, :itags, :ilastplayed, :fpeak, :fgain) do

    include DBClassIntf

    def add_new(rrecord, rsegment)
        reset
        self.iorder = DBIntf.get_first_value("SELECT MAX(iorder)+1 FROM tracks WHERE rrecord=#{rrecord}")
        self.iorder = self.iorder.nil? ? 1 : self.iorder.to_i
        self.rtrack = get_last_id+1
        self.rrecord = rrecord
        self.rsegment = rsegment
        self.stitle = "New track"
        self.fpeak = 0.0
        self.fgain = 0.0
        return sql_add
    end

    def banned?
        return (self.itags & Qualifiers::TAGS_BANNED) != 0
    end
end


PListDBClass = Struct.new(:rplist, :sname, :iislocal, :idatecreated, :idatemodified) { include DBClassIntf }

GenreDBClass = Struct.new(:rgenre, :sname) { include DBClassIntf }

LabelDBClass = Struct.new(:rlabel, :sname) { include DBClassIntf }

MediaDBClass = Struct.new(:rmedia, :sname) { include DBClassIntf }

CollectionDBClass = Struct.new(:rcollection, :sname) { include DBClassIntf }

OriginDBClass = Struct.new(:rorigin, :sname) { include DBClassIntf }

FilterDBClass = Struct.new(:rfilter, :sname, :sxmldata) { include DBClassIntf }
