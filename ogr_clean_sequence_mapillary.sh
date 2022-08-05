ogrinfo -dialect sqlite -sql 'WITH RECURSIVE clean_sequence as (
SELECT g.*,
cast(null as geometry) as aproximite,
cast(null as integer) as id_ref,
cast(null as real) AS distance
FROM (SELECT * FROM conf LIMIT 1) g
UNION ALL
SELECT T.*,
  CASE 
  WHEN C.aproximite IS NULL AND PtDistWithin(T.geom, C.geom,3) THEN T.geom_prev
  WHEN not (C.aproximite IS NULL) AND PtDistWithin(T.geom, C.aproximite,3) THEN C.aproximite
  ELSE NULL
  END as aproximite,
  CASE 
  WHEN C.aproximite IS NULL AND PtDistWithin(T.geom, C.geom,3) THEN t.prev_val
  WHEN not (C.aproximite IS NULL) AND PtDistWithin(T.geom, C.aproximite,3) THEN C.id_ref
  ELSE NULL
  END as id_ref,
  CASE 
  WHEN C.aproximite IS NULL AND PtDistWithin(T.geom, C.geom,3) THEN ST_Distance(T.geom, C.geom)
  WHEN not (C.aproximite IS NULL) AND PtDistWithin(T.geom, C.aproximite,3) THEN ST_Distance(T.geom, C.aproximite)
  ELSE NULL
  END as distance
  FROM clean_sequence as C 
  INNER JOIN (SELECT * FROM conf) as T 
  ON T.id_photo = C.id_photo + 1),
conf AS (SELECT
  sourcefile,
  filename, 
  substr(filename,1,4) as sequence,
  cast(substr(filename,5,4) AS integer) as id_photo,
  CAST(gpslatitude AS REAL), 
  CAST(gpslongitude AS REAL),
  ST_Transform(SetSRID(MakePoint(CAST(gpslongitude AS REAL), CAST(gpslatitude AS REAL)), 4326),2154)as geom,
  LEAD(ST_Transform(SetSRID(MakePoint(CAST(gpslongitude AS REAL), CAST(gpslatitude AS REAL)), 4326),2154)) over (order by filename) AS geom_next,
  LAG(ST_Transform(SetSRID(MakePoint(CAST(gpslongitude AS REAL), CAST(gpslatitude AS REAL)), 4326),2154)) over (order by filename) AS geom_prev,
  LAG(cast(substr(filename,5,4) AS integer)) OVER (ORDER BY cast(substr(filename,5,4) AS integer)) AS prev_val,
  LEAD(cast(substr(filename,5,4) AS integer)) OVER (ORDER BY cast(substr(filename,5,4) AS integer)) AS next_val
FROM "'GSAA'" ORDER BY filename)
SELECT *
 FROM clean_sequence
' GSAA.sqlite
