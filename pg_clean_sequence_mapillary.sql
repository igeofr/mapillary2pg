WITH RECURSIVE clean_sequence AS 
(
	SELECT g.*,
		null::geometry AS aproximite,
		null::integer AS id_ref,
		null::double precision AS distance
    FROM (SELECT conf.* FROM conf LIMIT 1) g
UNION ALL
    SELECT T.*,
		CASE 
			WHEN C.aproximite IS NULL AND ST_DWithin(T.geom, C.geom,3) THEN T.geom_prev
			WHEN NOT (C.aproximite IS NULL) AND ST_DWithin(T.geom, C.aproximite,3) THEN C.aproximite
			ELSE NULL
		END as aproximite,
		CASE 
			WHEN C.aproximite IS NULL AND ST_DWithin(T.geom, C.geom,3) THEN t.prev_val
			WHEN NOT (C.aproximite IS NULL) AND ST_DWithin(T.geom, C.aproximite,3) THEN C.id_ref
			ELSE NULL
		END as id_ref,
		CASE 
			WHEN C.aproximite IS NULL AND ST_DWithin(T.geom, C.geom,3) THEN ST_Distance(T.geom, C.geom)
			WHEN NOT (C.aproximite IS NULL) AND ST_DWithin(T.geom, C.aproximite,3) THEN ST_Distance(T.geom, C.aproximite)
			ELSE NULL
		END as distance
    FROM clean_sequence AS C
 	INNER JOIN (SELECT conf.* FROM conf) AS T 
	ON T.id_photo = C.id_photo + 1
),
-----------------------
conf AS (SELECT
			sourcefile,
			filename, substr(filename,1,4) AS sequence, 
			substr(filename,5,4)::integer AS id_photo, 
			gpslatitude, 
			gpslongitude, 
			ST_Transform(ST_SetSRID(ST_MakePoint(gpslongitude, gpslatitude), 4326),2154) AS geom, 
			LEAD(ST_Transform(ST_SetSRID(ST_MakePoint(gpslongitude, gpslatitude), 4326),2154)) OVER(ORDER BY filename) AS geom_next,
			LAG(ST_Transform(ST_SetSRID(ST_MakePoint(gpslongitude, gpslatitude), 4326),2154)) OVER(ORDER BY filename) AS geom_prev,
			LAG(substr(filename,5,4)::integer) OVER(ORDER BY substr(filename,5,4)::integer) AS prev_val, 
			LEAD(substr(filename,5,4)::integer) OVER(ORDER BY substr(filename,5,4)::integer) AS next_val
		FROM ref_mapillary.img)
-----------------------
SELECT *
from clean_sequence WHERE NOT (aproximite IS NULL);
