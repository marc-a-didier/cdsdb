# encoding: utf-8

#
# Ratings and tags that appear in popup menus & tree views
#

module Qualifiers
    RATINGS = ["Non qualifié", "A chier", "Bouseux", "Limite", "Décent", "Cool", "Top fuel", "Transcendant", "Sublimissime"]
    TAGS = ["Girly", "Live", "Fun", "Calmos", "Oï!", "Destroy!", "Pur binaire", "Instrumental", "Banned", "1234!"]

    # Absolutly not used anywhere...
    TAG_GIRLY        = 1
    TAG_LIVE         = 2
    TAG_FUN          = 4
    TAG_CALMOS       = 8
    TAG_OI           = 16
    TAG_DESTROY      = 32
    TAG_BINAIRE      = 64
    TAG_INSTRUMENTAL = 128
    TAG_BANNED       = 256
    TAG_1234         = 512
end
