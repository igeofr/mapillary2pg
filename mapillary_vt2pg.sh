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

#-------------------------------------------------------------------------------
# BBOX ET IDENTIFICATION DES TUILES
# Source : https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
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

#-------------------------------------------------------------------------------
# IMAGE ET SEQUENCE
echo 'Debut du traitement des données de Mapillary'

file=$REPER'/'$DATE_YMD'_MAPILLARY_VT_IMAGE_SEQUENCE.gpkg'
rm $REPER'/'$DATE_YMD'_MAPILLARY_VT_IMAGE_SEQUENCE.'*
file_pt=$REPER'/'$DATE_YMD'_MAPILLARY_VT_POINT_DETETE.gpkg'
rm $REPER'/'$DATE_YMD'_MAPILLARY_VT_POINT_DETECTE.'*

Z=$V_ZOOM
for X in $(seq $XMIN $XMAX);do
   for Y in $(seq $YMIN $YMAX);do

      MVTFILE=${Z}'_'${X}'_'${Y}'.pbf'
      
      #-------------------------------------------------------------------------------
      URL="https://tiles.mapillary.com/maps/vtp/mly1_public/2/$Z/$X/$Y?access_token=$TOKEN"

      mkdir $REPER'/tuiles/tuiles_image_sequence/'${DATE_YMD}
      mkdir $REPER'/tuiles/tuiles_image_sequence/'${DATE_YMD}'/'${Z}
      mkdir $REPER'/tuiles/tuiles_image_sequence/'${DATE_YMD}'/'${Z}'/'${X}
      mkdir $REPER'/tuiles/tuiles_image_sequence/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}

      # TELECHARGEMENT DES TUILES
      curl -w "%{http_code}" $URL --max-time 120 --connect-timeout 60 -o $REPER'/tuiles/tuiles_image_sequence/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVTFILE

      # FUSION EN GPKG
      ogr2ogr \
      -progress \
      -f 'GPKG' \
      -update -append \
      --debug ON \
      -lco SPATIAL_INDEX=YES \
      $file \
      $REPER'/tuiles/tuiles_image_sequence/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVTFILE sequence image \
      -nlt PROMOTE_TO_MULTI \
      -oo x=${X} -oo y=${Y} -oo z=${Z}

      #-------------------------------------------------------------------------------
      URL_PT="https://tiles.mapillary.com/maps/vtp/mly_map_feature_point/2/$Z/$X/$Y?access_token=$TOKEN"

      mkdir $REPER'/tuiles/tuiles_point_detecte/'${DATE_YMD}
      mkdir $REPER'/tuiles/tuiles_point_detecte/'${DATE_YMD}'/'${Z}
      mkdir $REPER'/tuiles/tuiles_point_detecte/'${DATE_YMD}'/'${Z}'/'${X}
      mkdir $REPER'/tuiles/tuiles_point_detecte/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}

      # TELECHARGEMENT DES TUILES
      curl -w "%{http_code}" $URL_PT --max-time 120 --connect-timeout 60 -o $REPER'/tuiles/tuiles_point_detecte/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVTFILE

      # FUSION EN GPKG
      ogr2ogr \
      -progress \
      -f 'GPKG' \
      -update -append \
      --debug ON \
      -lco SPATIAL_INDEX=YES \
      $file_pt \
      $REPER'/tuiles/tuiles_point_detecte/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVTFILE point \
      -nlt PROMOTE_TO_MULTI \
      -oo x=${X} -oo y=${Y} -oo z=${Z}

   done
done
#-------------------------------------------------------------------------------
echo 'Import dans PG'

# IMPORT PG
ogr2ogr \
    -append \
    -f "PostgreSQL" PG:"host='$C_HOST' user='$C_USER' dbname='$C_DBNAME' password='$C_PASSWORD' schemas='$C_SCHEMA'" \
    -nln 'mapillary_vt_sequence' \
    -s_srs 'EPSG:3857' \
    -t_srs 'EPSG:2154' \
    $file 'sequence' \
    -where "captured_at>$DATE_DEBUT_T" \
    -dialect SQLITE \
    --config OGR_TRUNCATE YES \
    --debug ON \
    --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_vt_sequence.log'

ogr2ogr \
    -append \
    -f "PostgreSQL" PG:"host='$C_HOST' user='$C_USER' dbname='$C_DBNAME' password='$C_PASSWORD' schemas='$C_SCHEMA'" \
    -nln 'mapillary_vt_image' \
    -s_srs 'EPSG:3857' \
    -t_srs 'EPSG:2154' \
    $file 'image' \
    -where "captured_at>$DATE_DEBUT_T" \
    -dialect SQLITE \
    --config OGR_TRUNCATE YES \
    --debug ON \
    --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_vt_image.log'

ogr2ogr \
    -append \
    -f "PostgreSQL" PG:"host='$C_HOST' user='$C_USER' dbname='$C_DBNAME' password='$C_PASSWORD' schemas='$C_SCHEMA'" \
    -nln 'mapillary_vt_point' \
    -s_srs 'EPSG:3857' \
    -t_srs 'EPSG:2154' \
    $file_pt 'point' \
    -where "captured_at>$DATE_DEBUT_T" \
    -dialect SQLITE \
    --config OGR_TRUNCATE YES \
    --debug ON \
    --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_vt_point.log'

echo 'Fin du traitement des données de Mapillary'
