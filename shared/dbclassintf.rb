
module DBClass

    module SQLintf

        def initialize(params = {})
            reset
            set_fields(params)
        end

        # Initialize struct members from their names: if it begins with r or i, initialize as an int
        # and as a string if it begins with s or m.
        def reset
            self.members.each_with_index { |member, i|
                # i == 0 means first field, that is the primary key which is set to nil to tell that the entry is not valid
                if i == 0
                    self[i] = nil
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

        def set_fields(params = {})
            params.each { |key, value| self[key] = value }
            return self
        end

        def tbl_name
            return self.members[0][1..-1]+"s"
        end

        def primary_key
            return self.members[0]
        end

        def generate_where_on_pk
            return "WHERE #{primary_key}=#{self[0]}"
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
            DBUtils.client_sql(sql) unless sql.empty?
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
            return self[0]
        end

        def disp_value(val)
            valid? ? val : nil
        end

        def select_by_field(field, value, opts = :case_sensitive)
            if opts == :case_insensitive
                row = DBIntf.get_first_row("SELECT * FROM #{tbl_name} WHERE LOWER(#{field})=LOWER(#{value.to_sql});")
            else
                row = DBIntf.get_first_row("SELECT * FROM #{tbl_name} WHERE #{field}=#{value.to_sql};")
            end
            row.nil? ? reset : load_from_row(row)
            return valid?
        end

        def select_all
            DBIntf.execute("SELECT * FROM #{tbl_name}") do |row|
                load_from_row(row)
                yield(self) #if block_given?
            end
        end

        def count_references(from_table)
            return DBIntf.get_first_value("SELECT COUNT(#{primary_key}) FROM #{from_table} WHERE #{primary_key}=#{self[0]}")
        end
    end


    Artist = Struct.new(:rartist, :sname, :swebsite, :rorigin, :mnotes) do

        include SQLintf

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


    Record = Struct.new(:rrecord, :icddbid, :rartist, :stitle, :iyear, :rlabel,
                        :rgenre, :rmedia, :rcollection, :iplaytime, :isetorder, :isetof,
                        :scatalog, :mnotes, :idateadded, :idateripped, :iissegmented, :irecsymlink,
                        :ipeak, :igain) do

        include SQLintf

        def add_new(rartist)
            reset
            self.rrecord = get_last_id+1
            self.rartist = rartist
            self.stitle = "New record"
            self.idateadded = Time.now.to_i
            return sql_add
        end

        def segmented?
            return self.iissegmented == 1
        end

        def compile?
            return self.rartist == 0
        end
    end


    Segment = Struct.new(:rsegment, :rrecord, :rartist, :iorder, :stitle, :iplaytime, :mnotes) do

        include SQLintf

        def add_new(rartist, rrecord)
            reset
            self.rsegment = get_last_id+1
            self.rrecord = rrecord
            self.rartist = rartist
            self.iorder = DBIntf.get_first_value("SELECT MAX(iorder)+1 FROM segments WHERE rrecord=#{rrecord}")
            self.iorder = self.iorder.nil? ? 1 : self.iorder.to_i
            self.stitle = "New segment"
            return sql_add
        end

        # Loads values from the first segment of a given record
        def first_segment(rrecord)
            return load_from_row(DBIntf.get_first_row("SELECT * FROM segments WHERE rrecord=#{rrecord};"))
        end
    end


    Track = Struct.new(:rtrack, :rsegment, :rrecord, :iorder, :iplaytime, :stitle, :mnotes, :isegorder,
                       :iplayed, :irating, :itags, :ilastplayed, :ipeak, :igain) do

        include SQLintf

        def add_new(rrecord, rsegment)
            reset
            self.rtrack = get_last_id+1
            self.rrecord = rrecord
            self.rsegment = rsegment
            self.iorder = DBIntf.get_first_value("SELECT MAX(iorder)+1 FROM tracks WHERE rrecord=#{rrecord}")
            self.iorder = self.iorder.nil? ? 1 : self.iorder.to_i
            self.stitle = "New track"
            return sql_add
        end

        def banned?
            return (self.itags & Qualifiers::TAGS_BANNED) != 0
        end
    end


    Filter = Struct.new(:rfilter, :sname, :sjsondata) do

        include SQLintf

        def add_new
            reset
            self.rfilter = get_last_id+1
            self.sname = 'New filter'
            self.sjsondata = '{"filter":{}}'
            return sql_add
        end
    end


    Host = Struct.new(:rhost, :sname) do

        include SQLintf

        def add_new(params = {})
            reset.set_fields(params)
            self.rhost = get_last_id+1
            return sql_add
        end
    end


    LogTracks = Struct.new(:rtrack, :idateplayed, :rhost) do

        include SQLintf

        # Must be overriden since this table has no pk
        def tbl_name
            return "logtracks"
        end
    end

    PList = Struct.new(:rplist, :sname, :iislocal, :idatecreated, :idatemodified) { include SQLintf }

    Genre = Struct.new(:rgenre, :sname) { include SQLintf }

    Label = Struct.new(:rlabel, :sname) { include SQLintf }

    Media = Struct.new(:rmedia, :sname) { include SQLintf }

    Collection = Struct.new(:rcollection, :sname) { include SQLintf }

    Origin = Struct.new(:rorigin, :sname) { include SQLintf }


    KEY_NAME_TO_CLASS_MAP = { :rartist => Artist, :rplist => PList, :rgenre => Genre, :rlabel => Label,
                              :rmedia => Media, :rcollection => Collection, :rorigin => Origin }

    def self.class_from_symbol(key)
        return KEY_NAME_TO_CLASS_MAP[key]
    end
end
