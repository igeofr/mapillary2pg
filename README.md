# mapillary2pg

Importer les données Mapillary dans PostgreSQL/PostGIS (images et objets)

- [mapillary2pg.sh](https://github.com/igeofr/mapillary2pg/blob/main/mapillary2pg.sh) permet de télécharger et d'intégrer des [entités Mapillary](https://www.mapillary.com/developer/api-documentation/#entities) dans PostgreSQL/PostGIS (attention le nombre d'entités par requête est limité)
- [mapillary_vt2pg.sh](https://github.com/igeofr/mapillary2pg/blob/main/mapillary_vt2pg.sh) permet le téléchargement des [tuiles vectorielles de Mapillary](https://www.mapillary.com/developer/api-documentation/#vector-tiles) pour une intégration des données dans PostgreSQL/PostGIS

  - Niveau 14 : images et sequences
  - Niveau 12 : sequences uniquement

**Les scripts sont perfectibles et nécessitent encore un travail d'amélioration**

## Pour aller plus loin

- [API Mapillary](https://www.mapillary.com/developer/api-documentation/)
- [ogr2ogr](https://gdal.org/programs/ogr2ogr.html)

## Autres liens 

- [Traces Mapillary dans les GPS Garmin](https://blog.velocarte66.fr/fr/node/374)
- [Python script for downloading data from Mapillary API v4 in a bounding box](https://gist.github.com/cbeddow/28e5d043a46ba34ea91f7b66564307d4)

## Licence

[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.fr)

## Le mot de la fin

Merci de me faire remonter : les erreurs et/ou les problèmes que vous rencontrez.
