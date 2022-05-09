#!/bin/sh
# ------------------------------------------------------------------------------
# 2022 Florian Boret
# https://github.com/igeofr/mapillary2pg
# CC BY-SA 4.0 : https://creativecommons.org/licenses/by-sa/4.0/deed.fr
#-------------------------------------------------------------------------------

# RECUPERATION DU TYPE DE DATA A INTEGRER (image ou point)
if [ "$#" -ge 1 ]; then
  if [ "$1" = "image" ] || [ "$1" = "point" ] || [ "$1" = "signalisation" ];
  then
    TYPE=$1
    echo $TYPE
  else
  IFS= read -p "Type : " S_TYPE
    if [ "$S_TYPE" = "image" ] || [ "$S_TYPE" = "point" ] || [ "$S_TYPE" = "signalisation" ];
    then
      export TYPE=$S_TYPE
      echo $TYPE
    else
      echo "Erreur de paramètre"
      exit 0
    fi
  fi
else
  IFS= read -p "Type : " S_TYPE
  if [ "$S_TYPE" = "image" ] || [ "$S_TYPE" = "point" ] || [ "$S_TYPE" = "signalisation" ];
  then
    export TYPE=$S_TYPE
    echo $TYPE
  else
    echo "Erreur de paramètre"
    exit 0
  fi
fi

# VARIABLES DATES
export DATE_YM=$(date "+%Y%m")
export DATE_YMD=$(date "+%Y%m%d")

# LECTURE DU FICHIER DE CONFIGURATION
. './config.env'

# REPERTOIRE DE TRAVAIL
cd $REPER
echo $REPER

DATE_EPOCH=date -d $DATE_DEBUT +%s
echo $DATE_EPOCH

#-------------------------------------------------------------------------------
# BBOX ET IDENTIFICATION DES TUILES
# Source : https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
long2xtile(){
 long=$1
 zoom=$2
 echo -n "${long} ${zoom}" | awk '{ xtile = ($1 + 180.0) / 360 * 2.0^$2;
  xtile+=xtile<0?-0.5:0.5;
  printf("%d", xtile ) }'
}
lat2ytile() {
 lat=$1;
 zoom=$2;
 ytile=`echo "${lat} ${zoom}" | awk -v PI=3.14159265358979323846 '{
   tan_x=sin($1 * PI / 180.0)/cos($1 * PI / 180.0);
   ytile = (1 - log(tan_x + 1/cos($1 * PI/ 180))/PI)/2 * 2.0^$2;
   ytile+=ytile<0?-0.5:0.5;
   printf("%d", ytile ) }'`;
 echo -n "${ytile}";
}

XMIN=$(long2xtile $(echo $V_LONG_MIN | sed -e 's/\./,/g') $V_ZOOM)
XMAX=$(long2xtile $(echo $V_LONG_MAX | sed -e 's/\./,/g') $V_ZOOM)
YMIN=$(lat2ytile $(echo $V_LAT_MIN | sed -e 's/\./,/g') $V_ZOOM)
YMAX=$(lat2ytile $(echo $V_LAT_MAX | sed -e 's/\./,/g') $V_ZOOM)
echo $XMIN $YMIN $XMAX $YMAX

#-------------------------------------------------------------------------------
echo 'Debut du traitement des données de Mapillary'

if  [ "$TYPE" = "image" ]; then
  L_TYPE="image_sequence"
  VAR_URL="mly1_public"
  LAYER="sequence image"
elif [ "$TYPE" = "point" ]
then
  L_TYPE="point_detecte"
  VAR_URL="mly_map_feature_point"
  LAYER="point"
elif [ "$TYPE" = "signalisation" ]
then
  L_TYPE="signalisation"
  VAR_URL="mly_map_feature_traffic_sign"
  LAYER="traffic_sign"
fi

file=$REPER'/'$DATE_YMD'_MAPILLARY_VT_'$L_TYPE'.gpkg'
rm $REPER'/'$DATE_YMD'_MAPILLARY_VT_'$L_TYPE'.'*

rm -r -d $REPER'/tuiles/tuiles_'$L_TYPE'/'${DATE_YMD}

Z=$V_ZOOM
for X in $(seq $XMIN $XMAX);do
   for Y in $(seq $YMAX $YMIN);do

      MVT_FILE=${Z}'_'${X}'_'${Y}'.mvt'

      #-------------------------------------------------------------------------------
      URL="https://tiles.mapillary.com/maps/vtp/$VAR_URL/2/$Z/$X/$Y?access_token=$TOKEN"
      #echo "https://tiles.mapillary.com/maps/vtp/$VAR_URL/2/$Z/$X/$Y?access_token=$TOKEN"

      mkdir $REPER'/tuiles/tuiles_'$L_TYPE'/'${DATE_YMD}
      mkdir $REPER'/tuiles/tuiles_'$L_TYPE'/'${DATE_YMD}'/'${Z}
      mkdir $REPER'/tuiles/tuiles_'$L_TYPE'/'${DATE_YMD}'/'${Z}'/'${X}
      mkdir $REPER'/tuiles/tuiles_'$L_TYPE'/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}

      # TELECHARGEMENT DES TUILES
      curl -w "%{http_code}" $URL --max-time 120 --connect-timeout 60 -o $REPER'/tuiles/tuiles_'$L_TYPE'/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVT_FILE

      # FUSION EN GPKG
      ogr2ogr \
      -progress \
      -f 'GPKG' \
      -update -append \
      --debug ON \
      -lco SPATIAL_INDEX=YES \
      $file \
      $REPER'/tuiles/tuiles_'$L_TYPE'/'${DATE_YMD}'/'${Z}'/'${X}'/'${Y}'/'$MVT_FILE $LAYER \
      -nlt PROMOTE_TO_MULTI \
      -oo x=${X} -oo y=${Y} -oo z=${Z}

   done
done
#-------------------------------------------------------------------------------
echo 'Import dans PG'

# IMPORT PG
if  [ "$TYPE" = "image" ]; then
    ogr2ogr \
        -append \
        -f "PostgreSQL" PG:"service='$C_SERVICE' schemas='$C_SCHEMA'" \
        -nln 'mapillary_vt_sequence' \
        -s_srs 'EPSG:3857' \
        -t_srs 'EPSG:2154' \
        $file 'sequence' \
        -where "captured_at>$DATE_EPOCH" \
        -dialect SQLITE \
        --config OGR_TRUNCATE YES \
        --debug ON \
        --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_vt_sequence.log'
    ogr2ogr \
        -append \
        -f "PostgreSQL" PG:"service='$C_SERVICE' schemas='$C_SCHEMA'" \
        -nln 'mapillary_vt_image' \
        -s_srs 'EPSG:3857' \
        -t_srs 'EPSG:2154' \
        $file 'image' \
        -where "captured_at>$DATE_EPOCH" \
        -dialect SQLITE \
        --config OGR_TRUNCATE YES \
        --debug ON \
        --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_vt_image.log'
elif [ "$TYPE" = "point" ]
then
    ogr2ogr \
        -append \
        -f "PostgreSQL" PG:"service='$C_SERVICE' schemas='$C_SCHEMA'" \
        -nln 'mapillary_vt_point' \
        -s_srs 'EPSG:3857' \
        -t_srs 'EPSG:2154' \
        $file 'point' \
        -where "last_seen_at>$DATE_EPOCH" \
        -dialect SQLITE \
        --config OGR_TRUNCATE YES \
        --debug ON \
        --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_vt_point.log'
elif [ "$TYPE" = "signalisation" ]
then
    ogr2ogr \
        -append \
        -f "PostgreSQL" PG:"service='$C_SERVICE' schemas='$C_SCHEMA'" \
        -nln 'mapillary_vt_signalisation' \
        -s_srs 'EPSG:3857' \
        -t_srs 'EPSG:2154' \
        $file 'traffic_sign' \
        -where "last_seen_at>$DATE_EPOCH" \
        -dialect SQLITE \
        --config OGR_TRUNCATE YES \
        --debug ON \
        --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_vt_signalisation.log'
fi
echo 'Fin du traitement des données de Mapillary'
