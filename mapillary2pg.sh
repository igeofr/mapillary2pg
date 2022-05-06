#!/bin/sh
# ------------------------------------------------------------------------------
# 2022 Florian Boret
# https://github.com/igeofr/mapillary2pg
# CC BY-SA 4.0 : https://creativecommons.org/licenses/by-sa/4.0/deed.fr
#-------------------------------------------------------------------------------

# RECUPERATION DU TYPE DE DATA A INTEGRER (images ou map_features)
if [ "$#" -ge 1 ]; then
  if [ "$1" = "images" ]  || [ "$1" = "map_features" ];
  then
    TYPE=$1
    echo $TYPE
  else
  IFS= read -p "Type : " S_TYPE
  if [ "$S_TYPE" = "images" ]  || [ "$S_TYPE" = "map_features" ];
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
  if [ "$S_TYPE" = "images" ]  || [ "$S_TYPE" = "map_features" ];
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

# VERIFIE l'EXISTENCE D'UN REPERTOIRE
DIR_DATA=$REPER'/'$TYPE'/'$DATE_YMD
echo $DIR_DATA
if [ -d "$DIR_DATA" ]; then
  echo "Le répertoire $DIR_DATA existe"
  rm $DIR_DATA'/'*
else
  mkdir $DIR_DATA
fi

# COORDONNEES DE L'EMPRISE
echo $V_YMIN
echo $V_YMAX
echo $V_XMIN
echo $V_XMAX

# COMPTER LE NOMBRE D'ITERATIONS NECESSAIRES
sizeX=$(echo "scale=0; (($V_XMAX - $V_XMIN)/$PAS)" | bc)
echo $sizeX
sizeY=$(echo "scale=0; (($V_YMAX - $V_YMIN)/$PAS)" | bc)
echo $sizeY

# EXTRACTION DES DONNEES PAR ITERATION
x=1
while [ $x -le $sizeX ]
do
  echo "X $x times"
  vBBOX_X1=$(echo "scale=4; ($V_XMIN+(($x-1)*$PAS))" | bc)
  echo $vBBOX_X1
  vBBOX_X2=$(echo "scale=4; ($V_XMIN+($x*$PAS))" | bc)
  echo $vBBOX_X2
  x=$(( $x + 1 ))

#------------------------------
  y=1
  while [ $y -le $sizeY ]
  do
    echo "Y $y times"
    vBBOX_Y1=$(echo "scale=4; ($V_YMIN+(($y-1)*$PAS))" | bc)
    echo $vBBOX_Y1
    vBBOX_Y2=$(echo "scale=4; ($V_YMIN+($y*$PAS))" | bc )
    echo $vBBOX_Y2
    y=$(( $y + 1 ))

    vBBOX=$vBBOX_X1","$vBBOX_Y1","$vBBOX_X2","$vBBOX_Y2

    sBBOX_X1=$(echo $vBBOX_X1 | sed -e 's/\./_/g')
    echo $sBBOX_X1
    sBBOX_X2=$(echo $vBBOX_X2 | sed -e 's/\./_/g')
    echo $sBBOX_X2
    sBBOX_Y1=$(echo $vBBOX_Y1 | sed -e 's/\./_/g')
    echo $sBBOX_Y1
    sBBOX_Y2=$(echo $vBBOX_Y2 | sed -e 's/\./_/g')
    echo $sBBOX_Y2

#-------------------------------------------------------------------------------
    # ATTRIBUTS A EXTRAIRE
    if  [ "$TYPE" = "images" ]; then
      FIELD="id,geometry,captured_at,exif_orientation"
      F_DATE="start_captured_at"
    elif [ "$TYPE" = "map_features" ]
    then
      FIELD="id,geometry,object_value,object_type,aligned_direction,first_seen_at,last_seen_at"
      F_DATE="start_last_seen_at"
    fi

    # Ajouter &limit=5 pour restreindre l'extraction
    wget 'https://graph.mapillary.com/'$TYPE'?access_token='$TOKEN'&fields='$FIELD'&'$F_DATE'='$DATE_DEBUT'&bbox='$vBBOX -O $REPER'/'$TYPE'/'$DATE_YMD'/'$DATE_YMD'_'$TYPE'_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
    find $REPER'/'$TYPE'/'$DATE_YMD | xargs grep -l '{"data":\[\]}' | xargs -I {} rm -rf {}

    FILE_IMG=$REPER'/'$TYPE'/'$DATE_YMD'/'$DATE_YMD'_'$TYPE'_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
    if [ -f "$FILE_IMG" ]; then
        echo "$FILE_IMG existe."
        sed -i -e 's/"data":/"type": "FeatureCollection", "features":/g' $REPER'/'$TYPE'/'$DATE_YMD'/'$DATE_YMD'_'$TYPE'_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
        sed -i -e 's/"id"/"type": "Feature","id"/g' $REPER'/'$TYPE'/'$DATE_YMD'/'$DATE_YMD'_'$TYPE'_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
    fi

  done
# -----------------------------
done

# DEBUT DE FUSION DES DONNEES ET DE L'INTEGRATION DANS PG
echo 'Debut Mapillary PG'

file=$REPER'/'$TYPE'/'$DATE_YMD'_'$TYPE'.gpkg'
rm $file

for i in $(ls $REPER'/'$TYPE'/'$DATE_YMD'/'*'.geojson')
  do
    echo "merge $i"
    ogr2ogr -progress -f 'GPKG' -update -append --debug ON -lco SPATIAL_INDEX=YES $file $i $(basename "${i%.*}") -nln $DATE_YMD'_'$TYPE -nlt POINT
  done

# IMPORT PG
ogr2ogr \
    -append \
    -f "PostgreSQL" PG:"host='$C_HOST' user='$C_USER' dbname='$C_DBNAME' password='$C_PASSWORD' schemas='$C_SCHEMA'" \
    -nln 'mapillary_'$TYPE \
    -s_srs 'EPSG:4326' \
    -t_srs 'EPSG:2154' \
    $file \
    --config OGR_TRUNCATE YES \
    --debug ON \
    --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_'$TYPE'.log'

# FIN DE FUSION DES DONNEES ET DE L'INTEGRATION DANS PG
echo 'Fin Mapillary PG'
