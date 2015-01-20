
module PListExporter

    def self.export_to_xspf(list_store, plist_name)
        xdoc = REXML::Document.new << REXML::XMLDecl.new("1.0", "UTF-8", "no")

        xdoc.add_element("playlist", {"version"=>"1", "xmlns"=>"http://xspf.org/ns/0/"})
        xdoc.root.add_element("creator").text = "CDsDB #{Cdsdb::VERSION}"
        tracklist = xdoc.root.add_element("trackList")

        list_store.each do |model, path, iter|
            next if iter[PListsWindow::TT_DATA].setup_audio_file == AudioStatus::NOT_FOUND
            track = REXML::Element.new("track")
            # In xspf specs, file name must be URI style formatted.
            track.add_element("location").text = URI::escape("file://"+iter[PListsWindow::TT_DATA].audio_file)
            tracklist << track
        end

        fname = CFG.music_dir+"Playlists/#{plist_name}.cdsdb.xspf"
        File.open(fname, "w") { |file| MyFormatter.new.write(xdoc, file) }
    end

    def self.do_export_to_m3u(list_store, plist_name)
        file = File.new(CFG.music_dir+"Playlists/#{plist_name}.cdsdb.m3u", "w")
        file << "#EXTM3U\n"
        list_store.each { |model, path, iter|
            file << iter[PListsWindow::TT_DATA].audio_file+"\n" unless iter[PListsWindow::TT_DATA].setup_audio_file == AudioStatus::NOT_FOUND
        }
        file.close
    end

    def self.export_to_pls(list_store, plist_name)
        counter = 0
        file = File.new(CFG.music_dir+"Playlists/#{plist_name}.cdsdb.pls", "w")
        file << "[playlist]\n\n"
        list_store.each { |model, path, iter|
            next if iter[PListsWindow::TT_DATA].setup_audio_file == AudioStatus::NOT_FOUND
            counter += 1
            file << "File#{counter}=#{URI::escape("file://"+iter[PListsWindow::TT_DATA].audio_file)}\n" <<
                    "Title#{counter}=#{iter[PListsWindow::TT_DATA].track.stitle}\n" <<
                    "Length#{counter}=#{iter[PListsWindow::TT_DATA].track.ilength/1000}\n\n"
        }
        file << "NumberOfEntries=#{counter}\n\n" << "Version=2\n"
        file.close
    end

    def self.export_to_device(mc, list_store)
        dlg = ExportDialog.new
        exp = ExportParams.new
        return if dlg.run(exp) == Gtk::Dialog::RESPONSE_CANCEL # Run is auto-destroying

        list_store.each do |model, path, iter|
            next if iter[PListsWindow::TT_DATA].setup_audio_file == AudioStatus::NOT_FOUND

            audio_file = iter[PListsWindow::TT_DATA].audio_file

            dest_file = exp.remove_genre ? audio_file.sub(/^#{exp.src_folder}[0-9A-Za-z ']*\//, exp.dest_folder) : audio_file.sub(/^#{exp.src_folder}/, exp.dest_folder)
            dest_file = dest_file.make_fat_compliant if exp.fat_compat
            if File.exists?(dest_file)
                puts "Export: file #{dest_file} already exists."
            else
                puts "Export: copying #{audio_file} to #{dest_file}"
                File.mkpath(File.dirname(dest_file))
                file_size = File.size(audio_file)
                curr_size = 0
                inf  = File.new(audio_file, "rb")
                outf = File.new(dest_file, "wb")
                dl_id = mc.tasks.new_upload(File.basename(audio_file))
                while (data = inf.read(128*1024))
                    curr_size += data.size
                    mc.tasks.update_file_op(dl_id, curr_size, file_size)
                    outf.write(data)
                    Gtk.main_iteration while Gtk.events_pending?
                end
                mc.tasks.end_file_op(dl_id, audio_file, 0)
            end
        end
    end
end
