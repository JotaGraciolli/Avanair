//SCRIPT DE INGESTÃO DE DADOS

//Limpeza da base
MATCH (n:Airport) DETACH DELETE n;
MATCH (n:Airline) DETACH DELETE n;
MATCH (n:Fligth) DETACH DELETE n;
MATCH (n:AirportType) DETACH DELETE n;
MATCH (n:Continent) DETACH DELETE n;
MATCH (n:Country) DETACH DELETE n;
MATCH (n:Region) DETACH DELETE n;
MATCH (n:RunwaySurface) DETACH DELETE n;

//Drop das constraints
DROP CONSTRAINT constraintAirportCode IF EXISTS;
DROP CONSTRAINT constraintAirlineCode IF EXISTS;
DROP CONSTRAINT constraintFlightCode IF EXISTS;
DROP CONSTRAINT constraintAirportTypeCode IF EXISTS;
DROP CONSTRAINT constraintContinentCode IF EXISTS;
DROP CONSTRAINT constraintCountryCode IF EXISTS;
DROP CONSTRAINT constraintRegionCode IF EXISTS;
DROP CONSTRAINT constraintRunwaySurfaceCode IF EXISTS;

//Criação das constraints
CREATE CONSTRAINT constraintAirportCode         IF NOT EXISTS FOR (a:Airport)       REQUIRE a.code IS NODE KEY;
CREATE CONSTRAINT constraintAirlineCode         IF NOT EXISTS FOR (a:Airline)       REQUIRE a.code IS NODE KEY;
CREATE CONSTRAINT constraintFlightCode          IF NOT EXISTS FOR (f:Fligth)        REQUIRE f.code IS NODE KEY;
CREATE CONSTRAINT constraintAirportTypeCode     IF NOT EXISTS FOR (t:AirportType)   REQUIRE t.code IS NODE KEY;
CREATE CONSTRAINT constraintContinentCode       IF NOT EXISTS FOR (c:Continent)     REQUIRE c.code IS NODE KEY;
CREATE CONSTRAINT constraintCountryCode         IF NOT EXISTS FOR (c:Country)       REQUIRE c.code IS NODE KEY;
CREATE CONSTRAINT constraintRegionCode          IF NOT EXISTS FOR (r:Region)        REQUIRE r.code IS NODE KEY;
CREATE CONSTRAINT constraintRunwaySurfaceCode   IF NOT EXISTS FOR (r:RunwaySurface) REQUIRE r.code IS NODE KEY;

//Ingestão do arquivo de Flights
LOAD CSV WITH HEADERS FROM 'https://stpslatam.blob.core.windows.net/partners-contest/routes.csv' as row
    WITH    row.source_airport as sourceAirportCode, 
            row.destination_apirport as destinationAirportCode,
			row.airline as airLineCode,
			row.codeshare as codeShare,
			row.stops as stops,
			row.equipment as equipmentList
		
	MERGE (airportFrom:Airport {code:sourceAirportCode})
	MERGE (airportTo:Airport {code:destinationAirportCode})
	MERGE (flight:Fligth {code:sourceAirportCode + destinationAirportCode})
	SET flight.isCodeShare = CASE WHEN codeShare = 'Y' THEN 'YES' ELSE 'NO' END, 
		flight.stopAmount = toInteger(stops)
	
	MERGE (airportFrom)-[:SOURCE]->(flight)-[:DESTINATION]->(airportTo)
	MERGE (airLineOperates:Airline {code:airLineCode})
	MERGE (airLineOperates)-[rel:OPERATES]->(flight)
	SET rel.equipment = split(equipmentList,' ');

//Ingestão do arquivo de Aeroportos
LOAD CSV WITH HEADERS FROM  'https://stpslatam.blob.core.windows.net/partners-contest/world_airports.csv' as row
	WITH 	row.iata_code as iataCode,
			Point({longitude: toFloat(row.longitude_deg), latitude: toFloat(row.latitude_deg)}) as point,
			row.type as airportType,
			toInteger(row.elevation_ft) as elevationInFeets,
            row.iso_country as countryCode,
            row.iso_region as regionCode,
			row.continent as continentCode,
			toInteger(row.runway_length_ft) as runwayLengthInFeets,
			toInteger(row.runway_width_ft) as runwayWidthInFeets,
			row.runway_surface as runwaySurfaceCode

	WHERE
			row.iata_code IS NOT NULL
			AND row.runway_surface IS NOT NULL
	MERGE (continent:Continent {code:continentCode})
    MERGE (country:Country {code:countryCode})
    MERGE (region:Region {code:regionCode})
    MERGE (region)-[:IS_IN_COUNTRY]->(country)
	MERGE (country)-[:IS_IN_CONTINENT]->(continent)
	MERGE (runwaySurface:RunwaySurface {code:runwaySurfaceCode})
    MERGE (NewAirportType:AirportType {code:airportType})
    WITH iataCode, elevationInFeets, NewAirportType, region, runwaySurface, runwayLengthInFeets, runwayWidthInFeets, point
	MATCH (airport:Airport)
	WHERE airport.code = iataCode
	SET airport.point = point,
		airport.elevationInFeets = elevationInFeets,
		airport.runwayLengthInFeets = runwayLengthInFeets,
		airport.runwayWidthInFeets = runwayWidthInFeets
    MERGE (airport)-[:IS_TYPE]->(NewAirportType)
    MERGE (airport)-[:IS_IN_REGION]->(region)
    MERGE (airport)-[:RUNWAY_SURFACE_IS]->(runwaySurface);

//Criação de labels
MATCH (continentFrom:Continent)<-[:IS_IN_CONTINENT]-(countryFrom:Country)<-[:IS_IN_COUNTRY]-(:Region)<-[:IS_IN_REGION]-(airportFrom:Airport)-[:SOURCE]->(flight:Fligth)-[:DESTINATION]->(airportTo:Airport)-[:IS_IN_REGION]->(:Region)-[:IS_IN_COUNTRY]->(countryTo:Country)-[:IS_IN_CONTINENT]->(continentTo:Continent)
WHERE elementId (continentFrom) <> elementId (continentTo)
SET airportFrom:Intercontinental
SET airportTo:Intercontinental;

MATCH (countryFrom:Country)<-[:IS_IN_COUNTRY]-(:Region)<-[:IS_IN_REGION]-(airportFrom:Airport)-[:SOURCE]->(flight:Fligth)-[:DESTINATION]->(airportTo:Airport)-[:IS_IN_REGION]->(:Region)-[:IS_IN_COUNTRY]->(countryTo:Country)
WHERE elementId (countryFrom) <> elementId (countryTo)
SET airportFrom:International
SET airportTo:International;

//Relacionamento entre aeroportos
MATCH (airportFrom:Airport)-[]->(flight:Fligth)-[]->(airportTo:Airport)
MERGE (airportFrom)-[r:IS_CONECTET_TO]->(airportTo)
SET r.stops = 0,
	r.distanceInkm = point.distance(airportFrom.point,airportTo.point);