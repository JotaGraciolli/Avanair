//TOP 10 de Aeroportos domésticos com conexão para aeroportos internacionais, ordenado por número de companhias aéreas que operam nestes aeroportos
MATCH (a:International)-[]-(flight)-[]-(b:!International)
WITH a, b, flight
MATCH (airline)-[]->(flight)
WHERE point.distance(a.point, b.point) < 200 * 1000 AND a.code <> b.code
RETURN a.code AS IATACode_A, b.code AS IATACode_B, COUNT(airline) as countAirline, point.distance(a.point, b.point) AS Distance
ORDER BY countAirline ASC, Distance ASC, IATACode_B, IATACode_A 
LIMIT 10
 