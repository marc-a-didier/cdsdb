PRAGMA synchronous=0;
PRAGMA encoding="UTF-8";

BEGIN TRANSACTION;

CREATE TABLE "origins"
(
  "rorigin"  INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"   VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "artists"
(
  "rartist"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"	VARCHAR NOT NULL DEFAULT '',
  "swebsite" VARCHAR  NOT NULL DEFAULT '',
  "rorigin" INTEGER NOT NULL DEFAULT 0 REFERENCES origins(rorigin),
  "mnotes"  VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "collections"
(
  "rcollection"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"	VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "segments"
(
  "rsegment"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "rrecord"	INTEGER NOT NULL DEFAULT 0 REFERENCES records(rrecord),
  "rartist"	INTEGER NOT NULL DEFAULT 0 REFERENCES artists(rartist),
  "iorder"	SMALLINT NOT NULL DEFAULT 0,
  "stitle"	VARCHAR NOT NULL DEFAULT '',
  "iplaytime"	INTEGER NOT NULL DEFAULT 0,
  "mnotes"	VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "labels"
(
  "rlabel"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"	VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "medias"
(
  "rmedia"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"	VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "genres"
(
  "rgenre"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"	VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "records"
(
  "rrecord"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "icddbid"	INTEGER NOT NULL DEFAULT 0,
  "rartist"	INTEGER NOT NULL DEFAULT 0 REFERENCES artists(rartist),
  "stitle"	VARCHAR NOT NULL DEFAULT '',
  "iiscompile"	SMALLINT NOT NULL DEFAULT 0,
  "iyear"	SMALLINT NOT NULL DEFAULT 0,
  "rlabel"	INTEGER NOT NULL DEFAULT 0 REFERENCES labels(rlabel),
  "rgenre"	INTEGER NOT NULL DEFAULT 0 REFERENCES genres(rgenre),
  "rmedia"	INTEGER NOT NULL DEFAULT 0 REFERENCES medias(rmedia),
  "rcollection"	INTEGER NOT NULL DEFAULT 0 REFERENCES collections(rcollection),
  "iplaytime"	INTEGER NOT NULL DEFAULT 0,
  "iisinset"	SMALLINT NOT NULL DEFAULT 0,
  "isetorder"	SMALLINT NOT NULL DEFAULT 0,
  "isetof"	SMALLINT NOT NULL DEFAULT 0,
  "scatalog"	VARCHAR NOT NULL DEFAULT '',
  "mnotes"	VARCHAR NOT NULL DEFAULT '',
  "idateadded" INTEGER NOT NULL DEFAULT 0,
  "idateripped" INTEGER NOT NULL DEFAULT 0,
  "iissegmented"    SMALLINT NOT NULL DEFAULT 0,
  "irecsymlink" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "tracks"
(
  "rtrack"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "rsegment"	INTEGER NOT NULL DEFAULT 0 REFERENCES segments(rsegment),
  "rrecord"	INTEGER NOT NULL DEFAULT 0 REFERENCES records(rrecord),
  "iorder"	SMALLINT NOT NULL DEFAULT 0,
  "iplaytime"	INTEGER NOT NULL DEFAULT 0,
  "stitle"	VARCHAR NOT NULL DEFAULT '',
  "mnotes"	VARCHAR NOT NULL DEFAULT '',
  "isegorder" INTEGER NOT NULL DEFAULT 0,
  "iplayed" INTEGER NOT NULL DEFAULT 0,
  "irating" INTEGER NOT NULL DEFAULT 0,
  "itags" INTEGER NOT NULL DEFAULT 0,
  "ilastplayed" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "plists" (
    "rplist" INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
    "sname" VARCHAR NOT NULL DEFAULT 'New play list',
    "iislocal" INTEGER NOT NULL DEFAULT 0,
    "idatecreated" INTEGER NOT NULL DEFAULT 0,
    "idatemodified" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "pltracks" (
    "rpltrack" INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
    "rplist" INTEGER NOT NULL DEFAULT 0 REFERENCES plists(rplist),
    "rtrack" INTEGER NOT NULL DEFAULT 0 REFERENCES tracks(rtrack),
    "iorder" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "hostnames" (
    "rhostname"     INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
    "shostname"     VARCHAR NOT NULL DEFAULT 'localhost'
);

CREATE TABLE "logtracks" (
    "rtrack"        INTEGER NOT NULL DEFAULT 0 REFERENCES tracks(rtrack),
    "idateplayed"   INTEGER NOT NULL DEFAULT 0,
    "rhostname"     INTEGER NOT NULL DEFAULT 0 REFERENCES hostnames(rhostname)
);

CREATE INDEX "ixartistname" ON "artists"("sname");
CREATE INDEX "ixrecordtitle" ON "records"("stitle");
/*
CREATE INDEX "ixlogrtrack" ON "logtracks"("rtrack");
CREATE INDEX "ixlogdplayed" ON "logtracks"("idateplayed");
*/
COMMIT;