# !/usr/bin/ruby

# require 'sqlite3'
# require 'dbintf'
# require 'dbutils'
# require 'utils'

class DBClassIntf

    attr_accessor :dbs

private
    def initialize_copy(orig)
        @dbs = orig.dbs.clone
    end


public
    # Creates a new orm mapper from the given struct
    # Generates getters and setters from struct members which may be referenced as
    # @dbs.member or self.member in subclasses.
    def initialize(dbs)
        @dbs = dbs
        @tbl_name = @dbs.members[0][1..-1]+"s"
        @dbs.members.each { |member| self.class.class_eval("def #{member}; return @dbs.#{member}; end") }
        @dbs.members.each { |member| self.class.class_eval("def #{member}=(val); @dbs.#{member}=val; end") }
        reset
    end

    # Initialize struct members from their names: if it begins with r or i, initialize as an int
    # and as a string if it begins with s or m.
    def reset
        @dbs.members.each_with_index { |member, i|
            # i == 0 means first field, that is the primary key which is set to -1 to tell that the entry is not valid
            if i == 0
                @dbs[i] = -1
            else
                case member.to_s[0]
                    when "r", "i" then @dbs[i] = 0  # r or i
                    when "s", "m" then @dbs[i] = "" # s or m
                    when "f"      then @dbs[i] = 0.0
                    else
                        puts "Unknow data type"
                        raise
                end
            end
        }
        return self
    end

    def generate_where_on_pk
        return "WHERE #{@dbs.members[0].to_s}=#{@dbs[0]}"
    end

    def generate_insert
        sql = "INSERT INTO #{@tbl_name} VALUES ("
        @dbs.each { |value| sql += value.to_sql+"," }
        return sql[0..-2]+");" # Remove last ,
    end

    def generate_update
        old = self.clone.sql_load
        sql = "UPDATE #{@tbl_name} SET "
        @dbs.each_with_index { |value, i| sql += @dbs.members[i].to_s+"="+value.to_sql+"," if value != old.dbs[i] }
        return sql[-1] == " " ? "" : sql[0..-2]+" "+generate_where_on_pk+";"
#         sql = sql[0..-2]+" "+generate_where_on_pk+";" if sql[-1] != " " # Remove last ,
#         return sql
    end

    # Set class attributes from a full sqlite3 row
    def load_from_row(row)
        row.each_with_index { |val, i| @dbs[i] = val } # @dbs[i].kind_of?(Numeric) ? val.to_i : val }
        return self
    end

    # Load a full sqlite3 row from the pk field
    def sql_load
        row = CDSDB.get_first_row("SELECT * FROM #{@tbl_name} #{generate_where_on_pk};")
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
        DBUtils.client_sql("DELETE FROM #{@tbl_name} #{generate_where_on_pk};")
        return self
    end

    def ref_load(ref_val)
        @dbs[0] = ref_val
        return sql_load
    end

    def get_last_id
        id = CDSDB.get_first_value("SELECT MAX(#{@dbs.members[0].to_s}) FROM #{@tbl_name};")
        return id.nil? ? 0 : id.to_i
    end

    def valid?
        return @dbs[0] != -1
    end

    def ==(object)
        return @dbs == object.dbs
    end

    def [](index)
        return @dbs[index]
    end

    def clone_dbs(object)
        @dbs = object.dbs.clone
        return self
    end

    def disp_value(val)
        valid? ? val : nil
    end
end

ArtistDBS = Struct.new(:rartist, :sname, :swebsite, :rorigin, :mnotes)

class ArtistDBClass < DBClassIntf

    def initialize
        super(ArtistDBS.new)
    end

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

RecordDBS = Struct.new(:rrecord, :icddbid, :rartist, :stitle, :iyear, :rlabel,
                       :rgenre, :rmedia, :rcollection, :iplaytime, :isetorder, :isetof,
                       :scatalog, :mnotes, :idateadded, :idateripped, :iissegmented, :irecsymlink,
                       :fpeak, :fgain)

class RecordDBClass < DBClassIntf

    def initialize
        super(RecordDBS.new)
    end

    def add_new(rartist)
        reset
        @dbs.rrecord = get_last_id+1
        @dbs.rartist = rartist
        @dbs.stitle = "New record"
        @dbs.idateadded = Time.now.to_i
        @dbs.fpeak = 0.0
        @dbs.fgain = 0.0
        return sql_add
    end

    def segmented?
        return @dbs.iissegmented == 1
    end

    def compile?
        return @dbs.rartist == 0
    end
end

SegmentDBS = Struct.new(:rsegment, :rrecord, :rartist, :iorder, :stitle, :iplaytime, :mnotes)

class SegmentDBClass < DBClassIntf


    def initialize
        super(SegmentDBS.new)
    end

    def add_new(rartist, rrecord)
        reset
        @dbs.iorder = CDSDB.get_first_value("SELECT MAX(iorder)+1 FROM segments WHERE rrecord=#{rrecord}")
        @dbs.iorder = @dbs.iorder.nil? ? 1 : @dbs.iorder.to_i
        @dbs.rsegment = get_last_id+1
        @dbs.rrecord = rrecord
        @dbs.rartist = rartist
        @dbs.stitle = "New segment"
        return sql_add
    end

    # Loads values from the first segment of a given record
    def first_segment(rrecord)
        return load_from_row(CDSDB.get_first_row("SELECT * FROM segments WHERE rrecord=#{rrecord};"))
    end
end

TrackDBS = Struct.new(:rtrack, :rsegment, :rrecord, :iorder, :iplaytime, :stitle, :mnotes, :isegorder,
                      :iplayed, :irating, :itags, :ilastplayed, :fpeak, :fgain)

class TrackDBClass < DBClassIntf

    def initialize
        super(TrackDBS.new)
    end

    def add_new(rrecord, rsegment)
        reset
        @dbs.iorder = CDSDB.get_first_value("SELECT MAX(iorder)+1 FROM tracks WHERE rrecord=#{rrecord}")
        @dbs.iorder = @dbs.iorder.nil? ? 1 : @dbs.iorder.to_i
        @dbs.rtrack = get_last_id+1
        @dbs.rrecord = rrecord
        @dbs.rsegment = rsegment
        @dbs.stitle = "New track"
        @dbs.fpeak = 0.0
        @dbs.fgain = 0.0
        return sql_add
    end

    def banned?
        return (self.itags & UIConsts::TAGS_BANNED) != 0
    end
end


PListDBS = Struct.new(:rplist, :sname, :iislocal, :idatecreated, :idatemodified)

class PListDBClass < DBClassIntf
    def initialize
        super(PListDBS.new)
    end
end


GenreDBS = Struct.new(:rgenre, :sname)

class GenreDBClass < DBClassIntf
    def initialize
        super(GenreDBS.new)
    end
end


LabelDBS = Struct.new(:rlabel, :sname)

class LabelDBClass < DBClassIntf
    def initialize
        super(LabelDBS.new)
    end
end


MediaDBS = Struct.new(:rmedia, :sname)

class MediaDBClass < DBClassIntf
    def initialize
        super(MediaDBS.new)
    end
end


CollectionDBS = Struct.new(:rcollection, :sname)

class CollectionDBClass < DBClassIntf
    def initialize
        super(CollectionDBS.new)
    end
end


OriginDBS = Struct.new(:rorigin, :sname)

class OriginDBClass < DBClassIntf
    def initialize
        super(OriginDBS.new)
    end
end


FilterDBS = Struct.new(:rfilter, :sname, :sxmldata)

class FilterDBClass < DBClassIntf
    def initialize
        super(FilterDBS.new)
    end
end
