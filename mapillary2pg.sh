#!/bin/sh
# ------------------------------------------------------------------------------

# VARIABLES DATES
export DATE_YM=$(date "+%Y%m")
export DATE_YMD=$(date "+%Y%m%d")

# LECTURE DU FICHIER DE CONFIGURATION
. './config.env'

# REPERTOIRE DE TRAVAIL
cd $REPER
echo $REPER

# EXTRACTION DES COORDONNEES DE L'EMPRISE
Y1=$(echo $BBOX | cut -c 9-16)
echo $Y1
Y2=$(echo $BBOX | cut -c 26-33)
echo $Y2

X1=$(echo $BBOX | cut -c 1-7)
echo $X1
X2=$(echo $BBOX | cut -c 18-24)
echo $X2

# COMPTER LE NOMBRE D'ITERATIONS NECESSAIRES
sizeX=$(echo "scale=0; ($X2 - $X1)/$PAS" | bc)
echo $sizeX
sizeY=$(echo "scale=0; ($Y2 - $Y1)/$PAS" | bc)
echo $sizeY

# EXTRACTION DES DONNEES PAR ITERATION
x=1
while [ $x -le $sizeX ]
do
  echo "X $x times"
  vBBOX_X1=$(echo "scale=4; ($X1+(($x-1)*$PAS))" | bc)
  echo $vBBOX_X1
  vBBOX_X2=$(echo "scale=4; ($X1+($x*$PAS))" | bc)
  echo $vBBOX_X2
  x=$(( $x + 1 ))

#------------------------------
  y=1
  while [ $y -le $sizeY ]
  do
    echo "Y $y times"
    vBBOX_Y1=$(echo "scale=4; ($Y1+(($y-1)*$PAS))" | bc)
    echo $vBBOX_Y1
    vBBOX_Y2=$(echo "scale=4; ($Y1+($y*$PAS))" | bc )
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


    # PERMET DE RECUPERER LA POSITION DES IMAGES
    # Ajouter &limit=5 pour restreindre l'extraction
    DIR_IMG=$REPER'/images/'$DATE_YMD
    if [ -d "$DIR_IMG" ]; then
      echo "Le répertoire $DIR_IMG existe"
    else
      mkdir $REPER'/images/'$DATE_YMD
    fi
    rm $REPER'/images/'$DATE_YMD'/'*
    wget 'https://graph.mapillary.com/images?access_token='$TOKEN'&fields=id,geometry,captured_at,exif_orientation&start_captured_at='$DATE_DEBUT'&bbox='$vBBOX -O $REPER'/images/'$DATE_YMD'/'$DATE_YMD'_images_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
    find $REPER'/images/'$DATE_YMD | xargs grep -l '{"data":\[\]}' | xargs -I {} rm -rf {}
    sed -i -e 's/"data":/"type": "FeatureCollection", "features":/g' $REPER'/images/'$DATE_YMD'/'$DATE_YMD'_images_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
    sed -i -e 's/"id"/"type": "Feature","id"/g' $REPER'/images/'$DATE_YMD'/'$DATE_YMD'_images_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'

    #ogrinfo -ro -al -so \
    #    -oo AUTODETECT_TYPE=YES \
    #    -oo AUTODETECT_WIDTH=YES \
    #    -oo HEADERS=YES \
    #    $REPER'/objets/'$DATE_YMD'/'$DATE_YMD'_images_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'

    # PERMET DE RECUPERER LA POSITION DES OBJETS
    DIR_OBJ=$REPER'/objets/'$DATE_YMD
    if [ -d "$DIR_OBJ" ]; then
      echo "Le répertoire $DIR_OBJ existe"
    else
      mkdir $REPER'/objets/'$DATE_YMD
    fi
    rm $REPER'/objets/'$DATE_YMD'/'*
    wget 'https://graph.mapillary.com/map_features?access_token='$TOKEN'&fields=id,geometry,object_value,object_type,images&start_last_seen_at='$DATE_DEBUT'&bbox='$vBBOX -O $REPER'/objets/'$DATE_YMD'/'$DATE_YMD'_objets_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
    find $REPER'/objets/'$DATE_YMD | xargs grep -l '{"data":\[\]}' | xargs -I {} rm -rf {}
    sed -i -e 's/"data":/"type": "FeatureCollection", "features":/g' $REPER'/objets/'$DATE_YMD'/'$DATE_YMD'_objets_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'
    sed -i -e 's/"id"/"type": "Feature","id"/g' $REPER'/objets/'$DATE_YMD'/'$DATE_YMD'_objets_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'

    # INFORMATIONS
    #ogrinfo -ro -al -so \
    #    -oo AUTODETECT_TYPE=YES \
    #    -oo AUTODETECT_WIDTH=YES \
    #    -oo HEADERS=YES \
    #    $REPER'/objets/'$DATE_YMD'/'$DATE_YMD'_objets_'$sBBOX_X1'_'$sBBOX_Y1'_'$sBBOX_X2'_'$sBBOX_Y2'.geojson'

  done
#-----------------------------
done
# ------------------------------------------------------------------------------
# DEBUT DE FUSION DES DONNEES ET DE L'INTEGRATION DANS PG
echo 'Debut Mapillary PG'

file=$REPER'/images/'$DATE_YMD'_IMAGES.gpkg'
rm $REPER'/images/'$DATE_YMD'_IMAGES.'*

for i in $(ls $REPER'/images/'$DATE_YMD'/'*'.geojson')
  do
    echo "merge $i"
    ogr2ogr -progress -f 'GPKG' -update -append --debug ON -lco SPATIAL_INDEX=YES $file $i $(basename "${i%.*}") -nln $DATE_YMD'_IMAGES' -nlt POINT
  done

# IMPORT PG
ogr2ogr \
    -append \
    -f "PostgreSQL" PG:"host='$C_HOST' user='$C_USER' dbname='$C_DBNAME' password='$C_PASSWORD' schemas=ref_mapillary" \
    -nln 'mapillary_images' \
    -s_srs 'EPSG:4326' \
    -t_srs 'EPSG:2154' \
    $file \
    -dialect SQLITE \
    --config OGR_TRUNCATE YES \
    --debug ON \
    --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_images.log'

# ------------------------------------------------------------------------------
file=$REPER'/objets/'$DATE_YMD'_OBJETS.gpkg'
rm $REPER'/objets/'$DATE_YMD'_OBJETS.'*

for i in $(ls $REPER'/objets/'$DATE_YMD'/'*'.geojson')
  do
    echo "merge $i"
    ogr2ogr -progress -f 'GPKG' -update -append --debug ON -lco SPATIAL_INDEX=YES $file $i $(basename "${i%.*}") -nln $DATE_YMD'_OBJETS' -nlt POINT
  done

# IMPORT PG
ogr2ogr \
    -append \
    -f "PostgreSQL" PG:"host='$C_HOST' user='$C_USER' dbname='$C_DBNAME' password='$C_PASSWORD' schemas=ref_mapillary" \
    -nln 'mapillary_objets' \
    -s_srs 'EPSG:4326' \
    -t_srs 'EPSG:2154' \
    $file \
    -dialect SQLITE \
    --config OGR_TRUNCATE YES \
    --debug ON \
    --config CPL_LOG './'$REPER_LOGS'/'$DATE_YMD'_mapillary_objets.log'

# FIN DE FUSION DES DONNEES ET DE L'INTEGRATION DANS PG
echo 'Fin Mapillary PG'
