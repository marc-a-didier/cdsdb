#!/usr/bin/env ruby

#require 'musicbrainz' !! A explorer!!

require 'gtk2'

begin
    require 'ruby-prof'
rescue LoadError
    puts "--- Warning: could not load ruby-prof ---"
end


require 'singleton'
require 'fileutils'
require 'find'
require 'socket'
require 'date'

require 'sqlite3'
#require 'arrayfields'
require 'logger'
require 'taglib2'
#require 'TagLib'
require 'yaml'
#require 'xml'
require 'rexml/document'
require 'gst'
require 'uri'
require 'cgi'

require '../shared/uiconsts'
require '../shared/cfg'
require '../shared/dbintf'
require '../shared/dbclassintf'
require '../shared/dbcachemgr'
require '../shared/utils'
require '../shared/dbutils'
require '../shared/trackinfos'
require '../shared/audiolink'

require './multi_drag_treeview'

require './uicachemgr'
require './uiutils'

require './topwindow'
require './dbselectordialog'
require './plistswindow'
require './stats'
require './sqlgenerator'

require './prefs'
# require './filterprefs' # To remove ASAP
require './filterwindow'
require './playerwindow'
require './pqueuewindow'
require './cdeditorwindow'
require './memoswindow'
# require './mcdbdialog'
# require './filtergeneratordialog'
require './prefsdialog'
require './audiodialog'
require './playhistorydialog'
require './credits'
require './exportdialog'
require './searchdialog'
require './chartswindow'
require './recentitemsdialog'
require './trkplistsdialog'
require './datechooser'

require './musicclient'

require './taskswindow'

require './uimodules'
require './dbuiclass'

require './dbreorderer'

require './genericbrowser'
require './artistsbrowser'
require './recordsbrowser'
require './tracksbrowser'
require './mainwindow'
require './mastercontroller'

require './my_rr_lib'


# DONE: implementer un player via gstreamer (quand la doc sera a jour!)
# DONE: generation de playlist
# DONE: Classer la muse direct via le genre dans ~/Music apres le rip
# DONE: ajouter le no de sequence dans l'index pour les tracks
# DONE: sauver les infos de toutes les fenetres dans des prefs via xml plutot que yaml

# DONE: mettre une play queue dans le player
# DONE: ramener les couvertures de disques via la lib ruby/aws (amazon web services)
# DONE: shuffle des play lists
# DONE: voir pour les styles (changement de font, etc...)
# DONE: editeur du disque retourne par la recherche sur le net (ajout des segments)

# DONE: ajouter une icone dans la barre (comme rhythmbox & amarok)
# DONE: ajouter un compteur played et faire des play lists automatiques en fonction via les genres
# DONE: selection aleatoire de morceaux
# DONE: utilitaires de recherche des fichiers dont on trouve pas un match dans la base

# DONE: client/serveur : jouer les morceaux situes sur une autre machine

# DONE: generer les stats en html
# DONE: export de play lists vers un media (ipod, archos, ...)
# DONE: notification quand commence un nouveau morceau
# DONE: outil de recherche des morceaux, segs ou disques

# DONE: multiple selection on tracks tv
# DONE: filter artists view by genre, tags, ...
# DONE: mode admin/user (disable add, delete, update...)
# DONE: mettre un flag jaune dans les tracks si le morceau est trouve mais pas au bon endroit
# DONE: utiliser le drag/drop depuis les tracks pour alimenter les play lists plutot qu'un submenu

# DONE: Regler le probleme de la double indexation quand on edite un titre de morceau
#       dans le treeview (supprimer l'index du segment avant edition)

# DONE: Assignement des segments avec des noms vides?
# DONE: Verif de l'existence d'un titre maintenant que les segments n'ont plus de titre.

# DONE: Modif automatique du fichier audio quand on modifie un titre

# DONE: Perfectionner le système de génération des play lists: baser p.ex. sur le top des genres
#	et assigner un poids au genre.
#	Etudier un système de bannissement.
#	Assigner un poids linéaire ou logarithmique.
#	Poids pour les tags également?
#	Ajouter un interval de dates

# DONE: cliquer sur le temps du player modifie l'affichage (remaining time).

# DONE: agrandir l'image du disque quand on clique dessus.
# DONE: Assigner l'image d'un disque en faisant un drag/drop sur l'image.

# DONE: Assigner un ordre de preference des morceaux dans un disque
# DONE: Ajouter un flag local aux playlists pour savoir si les modifs doivent etre
#       repercutees sur le serveur (surtout pour les generated playlists).
# DONE: stats: artistes par pays
# DONE: generer play list depuis les charts
# DONE: negotiate database version when updating the db from client.
# DONE: add a menu entry to update db track length from music file length when cd index is rotten!
# DONE: Implement a server method to renumber play lists when changed
# DONE: Add an item to the track popup to download track if on server
# DONE: remplacer la check box active? du filtre par expanded? de l'expander.
# DONE: mettre une option dans view pour cacher la premiere colonne (ref) des tv?
# DONE: mettre le device du cd (/dev/cdrom, /dev/sr0, ...) dans les prefs
# DONE: tester de passer par gtk::builder plutot que libglade2
# DONE: tree view dans la liste des artistes avec vue par genre et autre???
# DONE: voir pour le filtre: virer l'ancienne version et voir comment remplacer pour la gen. playlists
# DONE: regrouper tous les tabs dans un seul? Remplacer les boutons par un popup sur un bouton.
#       Laisser des tabs pour les comments? ou les virer et faire une fenetre qui les affiche
#       et reste instantiee avec un toggle quelconque?
# DONE: voir si pour le filtre ajouter un message quand une fenetre est activee pour dire quelconque
#       c'est elle qui recoit le message quand le filtre est applique plutot que de mettre un menu
#       dans les fenetres susceptibles d'etre filtrees.
# DONE: URGENT!!! voir pour le save du memo et si le to_widgets a encore un sens pour la main window
# DONE: add a download from server item in the record/segment popup menu
# DONE: remove the oldest played tracks from menus and make the recently played tracks filterable
# DONE: Voir le probleme du remplissage des titres depuis le net avec la nouvelle version de rr lib
# DONE: URGENT: voir le bug de l'expand des records quand on est pas dans All ??? hallucination???
#       Hallucination, de toute evidence...

# DONE: trier la vue artistes par date d'ajout plutot que d'avoir un recently ripped/added records...
# DONE: database cleanup. remove iiscompile, iisinset, isetof --- keep isetorder to may be append the
#       order to the disc name ([CD 1] for ex.).
# DONE: enlever le hostname de logtracks et remplacer par une ref sur une table de hostname
#       automatiquement remplie??? Ca sauverait des bytes...
#       Et virer le champ rlogtrack qui sert a rien...???
# DONE: ajouter rating & never played dans la view des artistes???

# DONE: add a reload menu entry in artists popup
# DONE: Corriger le bug des charts!!!
# DONE: faire une fenetre avec des checks box pour selectionner les stats qu'on veut
#       et ajouter des stats sur les tracks tagees et qualifiees.

# DONE: Ajouter un mecanisme trace qui par sur stdout par defaut ou un fichier plutot que balancer des
#       puts n'importe ou.

# DONE: What did WE play on that day (24th of november, as example...)

# DONE: Faire pour la base comme pour les images: une map qui enregistre une dbclass pour
#       chaque entree qu'on veut cacher + sa pix_key!!!

# DONE: Dans la vue des artistes, ajouter un sous-viveau avec vue par artiste ou record



#
# ^^^       ^^^
# |||  DONE |||
#

# TODO: Use isetorder to may be append the order to the disc name ([CD 1] for ex.).
#       N.B. For this to work, must add a disc number in the cd editor window since it's not yet in the db...

# TODO: ajouter un tag 'a checker' quand un disque est mal rippe (ex: MM Vol.13)

# TODO: ajouter un index sur rtrack dans logtracks pour voir si ca accelere les requetes pour les charts

# TODO: desimbriquer la main window du master controller pour en faire une top window comme les autres.

# TODO: piger comment on envoie un delete event a une fenetre!!!

# TODO: utilitaire pour transferer l'historique des morceaux quand on change de medium (mp3->cd, p.e.)
# TODO: Mettre une couleur differente pour chaque nouvelle lettre dans la liste des artistes???

# TODO: s'inscrire comme client sur le serveur pour recevoir les updates des morceaux joues???

# TODO: Colorer les artistes en fonction du nombre d'ecoutes, genre vert au rouge???

# TODO: Trouver un moyen de disabler les signaux emis quand on fait une recherche incrementale!!!
# TODO: remplacer les strings drag-data-get par un TrackMgr!!!

# TODO: deplacer les covers dans le dir des morceaux. suffixer avec f pour front, b pour back, etc...
#       mettre le numero du morceau pour les covers individuelles.
# TODO: autoriser des poids negatifs pour le filtre histoire de favoriser les morceaux les moins joues.



# Peu realistes:
#   TODO: splitter les genres en deux styles: principal et sous-categorie (punk + rock, metal + black, ...)
#   TODO: Chercher le genre de musique sur le net (via Wikipedia)?
#   TODO: faire un serveur web plutot que de se faire chier avec une base sql locale?


#
# Main changes for v0.8.0
#
# - Port to ruby 1.9.x
# - SQLite3 ruby lib now returns columns with native type rather than strings
# - Re-ported lastest version of RubyRipper rr_lib
# - Removed dependancies on GTK obsoleted packages, mainly libglade2 by using GTK Builder
# - One glade file per dialog
# - Removed the tabs in main window, replaced by status lines in each browser
# - New memo window, replacing the memo in tabs
# - DB editors grouped in one global tabbed editor
# - Filter window applicates on the most recent focused filterable window (main, charts, recent...)
# - Old filter generator window removed, filter prefs class removed along
# - Play list generation integrated within the filter window
# - Artist tree view is now hierarchical and gives several filters
# - May show/hide db references in tree views
#

class Cdsdb

    VERSION = "0.8.3"

    def has_arg(arg)
        ARGV.each { |the_arg| return true if the_arg == arg }
        return false
    end

    def initialize
        CFG.set_admin_mode(has_arg("--admin"))

        CDSDB.execute("PRAGMA synchronous=OFF;")

        Thread.abort_on_exception = true

        MasterController.new
    end

end


Cdsdb.new
Gtk.main
