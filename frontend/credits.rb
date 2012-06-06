# #!/usr/bin/env ruby
#
# GnomeCanvas based 'scrolling credits' display widget
#
# Copyright (c) 2004 Geoff Youngs
#
# You can redistribute it and/or modify it under the terms of
# the Ruby's licence.

# require 'gnomecanvas2'

class ScrollingText #< Gnome::Canvas
	LineHeight= 16
	ScrollSpeed= [50,1]

	def initialize(lines)
		super(true)
		i= 0
		@width= 20
		@height= 20
		@lines = lines.map { |t|
			i += 1
            font = "Sans 8"
            #color = "black"
            color = 0xffffffff
            if t.match(/^\/b/)
                t.sub!(/^\/b/, "")
                font = "Sans Bold 8"
            end
            if t.match(/^\/c/)
                t.sub!(/^\/c/, "")
                color = 0xff0000ff
            end
			#font = if t =~ /for:$/ || t =~ /The fabu/ then  "Sans Bold 8" else "Sans 8" end
			Gnome::CanvasText.new(root,
                        		  {:text => t,
                        		    :x => (@width/2),
                        		    :y => (i * LineHeight),
                        		    :font => font,
                        		    :anchor => Gtk::ANCHOR_N,
                                    :fill_color_rgba => color})
                        		    #:fill_color => "black"})
		}

		@offset = nil

		signal_connect_after('hide') {|w,e| stop() }
		signal_connect_after('show') {|w,e| start() }
		signal_connect_after('size-allocate') { |w,e|
			@width = allocation.width
			@height= allocation.height

			set_size(@width,@height)
			set_scroll_region(0,0,@width,@height)
			@lines.each do |t|
				t.x = (@width / 2)
			end
			@offset = @height / 2 if @offset.nil?
			update_text()
		}

	end

	def start
		@tid= Gtk::timeout_add(ScrollSpeed.first) do
			@offset -= ScrollSpeed.last
			@offset = @height - LineHeight if @lines.all?{ |t| t.y < 0}
			update_text()
		end unless @tid
	end

	def stop
		Gtk::timeout_remove(@tid) if @tid
		@tid = nil
	end

	def update_text()
		@lines.each_with_index do |t,i|
			t.y = (i* LineHeight) + @offset

			if t.y < LineHeight
				col = 0xff * [t.y,LineHeight].min / LineHeight
				col = 0 if col < 0
				t.fill_color_rgba= col unless t.fill_color_rgba == col
			elsif t.y > (@height - (LineHeight*2))
				col = 0xff * [((@height-LineHeight)-t.y),LineHeight].min / LineHeight
				col = 0 if col < 0
				t.fill_color_rgba= col unless t.fill_color_rgba == col
			else
				t.fill_color_rgba= 0xff
			end
		end
	end
end

class Credits

    def Credits.show_credits
        dlg = Gtk::Dialog.new("CDs DB v#{Cdsdb::VERSION}", nil, Gtk::Dialog::MODAL, [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT])
        dlg.set_default_size(400,220)

        canvas = ScrollingText.new([
            "/bSources version: #{Cdsdb::VERSION}",
            "/bDatabase version: #{Cfg::instance.db_version}",
            "/bSQLite3 version: #{`sqlite3 --version`.split(" ")[0]}",
            "/bRuby version: #{`ruby -v`.split(" ")[1]}",
            '',
            '/bWith thanks to:', '',
            '/bThe Linux Kernel Developers for:',
            'Linux 2.6',
            '/bThe GTK development team for:',
            'GTK+ 2.4',
            '/bYukihiro Matsumoto for:',
            'Ruby',
            '/bRuby-GNOME2 Developers for:',
            'Ruby-GNOME2',
            '/bSQLite Developers for:',
            'SQLite',
            '/bGStreamer Developers for:',
            'GStreamer',
            '',
            '/b/cThe fabulous disasters developers team:',
            'marc',
            'albert',
            'didier'])

        dlg.vbox.add(canvas)
        dlg.show_all
        dlg.run
        canvas.stop
        dlg.destroy
    end

end
