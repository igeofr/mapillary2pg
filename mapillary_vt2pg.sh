#!/bin/sh
# ------------------------------------------------------------------------------
# 2022 Florian Boret
# https://github.com/igeofr/mapillary2pg
# CC BY-SA 4.0 : https://creativecommons.org/licenses/by-sa/4.0/deed.fr
#-------------------------------------------------------------------------------

# VARIABLES DATES
export DATE_YM=$(date "+%Y%m")
export DATE_YMD=$(date "+%Y%m%d")

# LECTURE DU FICHIER DE CONFIGURATION
. './config.env'

# REPERTOIRE DE TRAVAIL
cd $REPER
echo $REPER

# https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
long2xtile(){
 long=$1
 zoom=$2
 echo -n "${long} ${zoom}" | awk '{ xtile = ($1 + 180.0) / 360 * 2.0^$2;
  printf("%d", xtile ) }'
}

lat2ytile() {
 lat=$1;
 zoom=$2;
 ytile=`echo "${lat} ${zoom}" | awk -v PI=3.14159265358979323846 '{
   tan_x=sin($1 * PI / 180.0)/cos($1 * PI / 180.0);
   ytile = (1 - log(tan_x + 1/cos($1 * PI/ 180))/PI)/2 * 2.0^$2;
   printf("%d", ytile ) }'`;
 echo -n "${ytile}";
}

XMIN=$(long2xtile $V_XMIN $V_ZOOM)
XMAX=$(long2xtile $V_XMAX $V_ZOOM)
YMIN=$(lat2ytile $V_YMIN $V_ZOOM)
YMAX=$(lat2ytile $V_YMAX $V_ZOOM)
echo $XMIN $YMIN $XMAX $YMAX

echo 'Debut Mapillary'

Z=$V_ZOOM
file=$REPER'/'$DATE_YMD'_SEQUENCE.gpkg'
rm $REPER'/'$DATE_YMD'_SEQUENCE.'*
for X in $(seq $XMIN $XMAX);do
   for Y in $(seq $YMIN $YMAX);do
      MVTFILE=${Z}'_'${X}'_'${Y}'.pbf'
      URL="https://tiles.mapillary.com/maps/vtp/mly1_public/2/$Z/$X/$Y?access_token=$TOKEN"
      mkdir $REPER'/tuiles/'${DATE_YMD}
      mkdir $REPER'/tuiles/'${DATE_YMD}'/'${Z}
      mkdir $REPER'/tuiles/'${DATE_YMD}'/'${Z}'/'${X}
      mkdir $REPER'/tuiles/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}
      curl -w "%{http_code}" $URL --max-time 120 --connect-timeout 60 -o $REPER'/tuiles/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVTFILE

      ogr2ogr -progress -f 'GPKG' -update -append --debug ON -lco SPATIAL_INDEX=YES $file $REPER'/tuiles/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVTFILE --debug on -oo x=${X} -oo y=${Y} -oo z=${Z}

   done
done

# FIN DE FUSION DES DONNEES ET DE L'INTEGRATION DANS PG
echo 'Fin Mapillary'
