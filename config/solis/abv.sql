--
-- Archiefbank ontology - 1.0.1 - 2022-08-26 11:45:34 +0200
-- description: Archiefbank ontology
-- author: Archiefpunt, Meemo, KADOC, LIBIS
--


CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
DROP SCHEMA IF EXISTS abv CASCADE;
CREATE SCHEMA abv;


CREATE TABLE abv.rollen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.rollen.id IS 'systeem UUID';

CREATE TABLE abv.testen(
	id SERIAL NOT NULL PRIMARY KEY, 
	integer_dt integer, 
	string_dt text, 
	date_dt date, 
	year_dt text, 
	duration_dt text, 
	json_dt text, 
	uri_dt text, 
	lang_string_dt text, 
	lang_string_array_dt text NOT NULL, 
	boolean_dt bool, 
	float_dt text, 
	double_dt text, 
	datetime_dt text, 
	time_dt text
);
COMMENT ON TABLE abv.testen 'Dit is een test construct mag weg bij productie overgang';
COMMENT ON COLUMN abv.testen.id IS 'unique record identifier';
COMMENT ON COLUMN abv.testen.integer_dt IS 'an integer value';
COMMENT ON COLUMN abv.testen.string_dt IS 'a string value NO language specified';
COMMENT ON COLUMN abv.testen.date_dt IS 'a date time type';
COMMENT ON COLUMN abv.testen.year_dt IS 'just a year of a date';

CREATE TABLE abv.soorten(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.soorten.id IS 'systeem UUID';

CREATE TABLE abv.functies_beroepen_activiteiten(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.functies_beroepen_activiteiten.id IS 'systeem UUID';

CREATE TABLE abv.gebruiksgroepen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON TABLE abv.gebruiksgroepen 'Lijst van groepen waartoe een gebruiker kan toe behoren';
COMMENT ON COLUMN abv.gebruiksgroepen.id IS 'systeem UUID';

CREATE TABLE abv.publicaties(
	identificatienummer_id int REFERENCES abv.identificatienummers(id), 
	bibliografische_verwijzing text, 
	auteur_id int REFERENCES abv.namen(id), 
	titel text NOT NULL, 
	reeks text, 
	reeksnummer text, 
	uitgever text, 
	plaats_van_uitgave text, 
	datum_uitgave date, 
	url text
);
COMMENT ON TABLE abv.publicaties 'bibliografische informatie voor publicaties die een toegang op een archiefbestand vormen, over het archiefbestand gaan of de directe informatiebron zijn voor de archiefbeschrijving. sterk aanbevolen om zoveel mogelijk externe identificatienummers voor de publicatie op te nemen. mogelijkheid om ofwel een tekststring met een volledige bibliografische referentie op te nemen, ofwel een gestructureerde beschrijving van de publicatie. de gestructureerde beschrijving maakt publicaties beter doorzoekbaar binnen archiefbank.';
COMMENT ON COLUMN abv.publicaties.identificatienummer_id IS 'Identificatienummer voor de publicatie';
COMMENT ON COLUMN abv.publicaties.bibliografische_verwijzing IS 'volledige bibliografische verwijzing naar de publicatie';
COMMENT ON COLUMN abv.publicaties.auteur_id IS 'auteur van de publicatie';
COMMENT ON COLUMN abv.publicaties.titel IS 'titel van de publicatie';
COMMENT ON COLUMN abv.publicaties.reeks IS 'titel van de reeks waarin de publicatie verschijnt';
COMMENT ON COLUMN abv.publicaties.reeksnummer IS 'rangnummer van de publicatie binnen de reeks';
COMMENT ON COLUMN abv.publicaties.uitgever IS 'naam van de uitgever van de publicatie';
COMMENT ON COLUMN abv.publicaties.plaats_van_uitgave IS 'naam van de plaats van uitgave';
COMMENT ON COLUMN abv.publicaties.datum_uitgave IS 'datum van uitgave';
COMMENT ON COLUMN abv.publicaties.url IS 'URL die verwijst naar een digitale versie van de publicatie';

CREATE TABLE abv.waarden(
	id SERIAL NOT NULL PRIMARY KEY, 
	waarde text NOT NULL, 
	type_waarde_id int NOT NULL REFERENCES abv.type_waarden(id)
);
COMMENT ON COLUMN abv.waarden.id IS 'systeem UUID';

CREATE TABLE abv.toegangen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.toegangen.id IS 'systeem UUID';

CREATE TABLE abv.termen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.termen.id IS 'systeem UUID';

CREATE TABLE abv.bibliografie_archieven(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.bibliografie_archieven.id IS 'systeem UUID';

CREATE TABLE abv.bronbeschrijvingen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.bronbeschrijvingen.id IS 'systeem UUID';

CREATE TABLE abv.bronverwijzingen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.bronverwijzingen.id IS 'systeem UUID';

CREATE TABLE abv.codetabellen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.codetabellen.id IS 'systeem UUID';

CREATE TABLE abv.concepten(
	identificatienummer_id int NOT NULL REFERENCES abv.identificatienummers(id), 
	label text NOT NULL, 
	type_id int REFERENCES abv.type_concepten(id), 
	definitie text
);
COMMENT ON COLUMN abv.concepten.identificatienummer_id IS 'Identificatienummer voor het concept';
COMMENT ON COLUMN abv.concepten.label IS 'Naam voor het Concept';
COMMENT ON COLUMN abv.concepten.type_id IS 'gebruiken om onderscheid te maken tussen verschillende terminologielijstjes/om concepten te koppelen aan terminologie voor een specifiek veld';
COMMENT ON COLUMN abv.concepten.definitie IS 'Definitie van het Concept';

CREATE TABLE abv.dateringen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.dateringen.id IS 'systeem UUID';

CREATE TABLE abv.entiteit_basis(
	id SERIAL NOT NULL PRIMARY KEY, 
	_audit text
);
COMMENT ON TABLE abv.entiteit_basis 'Basis entiteit waar alle andere van overerven';
COMMENT ON COLUMN abv.entiteit_basis.id IS 'systeem UUID';
COMMENT ON COLUMN abv.entiteit_basis._audit IS 'link naar audit';

CREATE TABLE abv.agenten(
	identificatienummer_id int NOT NULL REFERENCES abv.identificatienummers(id), 
	naam_id int NOT NULL REFERENCES abv.namen(id), 
	type_id int NOT NULL REFERENCES abv.type_agenten(id), 
	datering_systematisch text, 
	datering_text text, 
	geschiedenis_agent text, 
	taal_id int REFERENCES abv.talen(id), 
	associaties_id int REFERENCES abv.associaties(id), 
	bronnen_agent text, 
	bibliografie_agent text, 
	bronverwijzing_record text NOT NULL, 
	opmerking text
);
COMMENT ON TABLE abv.agenten 'beperkt beschrijvingsmodel. doel: enkel relateren van agents aan archieven en waarderingen. geen afzonderlijke biografische databank (dus geen familierelaties bvb) Gebruik daarvoor een externe bron.';
COMMENT ON COLUMN abv.agenten.identificatienummer_id IS 'Herhaalbaar om verschillende IDs op te kunnen nemen. Eigen persistente URI wordt door het systeem toegekend en is dus ‘verplicht’. Andere IDs enkel toevoegen als ze al buiten ABV bestaan.';
COMMENT ON COLUMN abv.agenten.naam_id IS 'Herhaalbaar om naamsvarianten te documenteren.';
COMMENT ON COLUMN abv.agenten.type_id IS 'Keuze uit drie opties. Is de agent een persoon, een familie of een instelling.';
COMMENT ON COLUMN abv.agenten.datering_systematisch IS 'Geboorte- en sterftejaar, periode van activiteit familie, oprichtings- en opheffingsdatum.';
COMMENT ON COLUMN abv.agenten.datering_text IS 'Woordelijke uitleg bij datering_systematisch, initiëel ook voor legacy data.';
COMMENT ON COLUMN abv.agenten.geschiedenis_agent IS 'Biografische geschiedenis van de agent.';
COMMENT ON COLUMN abv.agenten.taal_id IS 'Taal ivm agent';
COMMENT ON COLUMN abv.agenten.associaties_id IS 'Plaats, Periode, Onderwerp of agent gelinkt aan de agent. ';
COMMENT ON COLUMN abv.agenten.bronnen_agent IS 'Bronnen gebruikt om agentbeschrijving op te stellen.';
COMMENT ON COLUMN abv.agenten.bibliografie_agent IS 'Bronnen over de agent.';
COMMENT ON COLUMN abv.agenten.bronverwijzing_record IS 'Correcte verwijzing naar het record in de Chicagostijl.';
COMMENT ON COLUMN abv.agenten.opmerking IS 'Vrij opmerkingen veld.';

CREATE TABLE abv.talen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.talen.id IS 'systeem UUID';

CREATE TABLE abv.associaties(
	plaats_id int REFERENCES abv.plaatsen(id), 
	agent_id int REFERENCES abv.agenten(id), 
	periode_id int REFERENCES abv.periodes(id), 
	onderwerp_id int REFERENCES abv.onderwerpen(id)
);
COMMENT ON COLUMN abv.associaties.plaats_id IS 'Plaats geassocieerd met het archief.';
COMMENT ON COLUMN abv.associaties.agent_id IS 'Agent geassocieerd met archief en/of  samensteller';
COMMENT ON COLUMN abv.associaties.periode_id IS 'Tijdsperiode waarmee archief gelinkt kan worden.';
COMMENT ON COLUMN abv.associaties.onderwerp_id IS 'Onderwerp trefwoorden die geassocieerd kunnen worden met archief.';

CREATE TABLE abv.plaatsen(
	identificatienummer_id int REFERENCES abv.identificatienummers(id), 
	plaatsnaam_id int NOT NULL REFERENCES abv.namen(id)
);
COMMENT ON TABLE abv.plaatsen 'capteert informatie over geografische locaties. Verwijzingen naar externe geografische thesauri is sterk aanbevolen. De beschrijving is uiterst beperkt gehouden, in de veronderstelling dat rijkere metadata, zoals historische namen, taalvarianten, maar ook coördinaten eenvoudig aan externe geografische thesauri ontleend kunnen worden. ';
COMMENT ON COLUMN abv.plaatsen.identificatienummer_id IS 'Identificatienummer voor de publicatie';

CREATE TABLE abv.namen(
	waarde text NOT NULL, 
	type_naam_id int NOT NULL REFERENCES abv.type_namen(id)
);

CREATE TABLE abv.type_agenten(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.type_agenten.id IS 'systeem UUID';

CREATE TABLE abv.ordeningen(
	waarde text, 
	trefwoord_id int NOT NULL REFERENCES abv.ordeningsstatussen(id)
);

CREATE TABLE abv.raadplegingsvoorwaarden(
	tekst text NOT NULL, 
	taal_id int NOT NULL REFERENCES abv.talen(id), 
	raadplegingsstatus_id int NOT NULL REFERENCES abv.raadplegingsstatussen(id)
);

CREATE TABLE abv.rechtenstatussen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.rechtenstatussen.id IS 'systeem UUID';

CREATE TABLE abv.rol_beheerders(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.rol_beheerders.id IS 'systeem UUID';

CREATE TABLE abv.rol_samenstellers(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.rol_samenstellers.id IS 'systeem UUID';

CREATE TABLE abv.samenstellers(
	agent_id int NOT NULL REFERENCES abv.agenten(id), 
	functie_beroep_activiteit_id int REFERENCES abv.functies(id)
);
COMMENT ON COLUMN abv.samenstellers.agent_id IS 'Link met agent';
COMMENT ON COLUMN abv.samenstellers.functie_beroep_activiteit_id IS 'Functie, beroep of activiteiten waarin agent ';

CREATE TABLE abv.waarderingen(
	waardestelling text NOT NULL, 
	waarde_id int REFERENCES abv.waarden(id), 
	vergelijking_id int REFERENCES abv.vergelijkingen(id), 
	datum_waardering date, 
	bron_waardering text, 
	bijdragers text, 
	opmerkingen text
);
COMMENT ON TABLE abv.waarderingen 'capteert informatie over de intrinsieke en comparatieve erfgoedwaarde van het archiefbestand';
COMMENT ON COLUMN abv.waarderingen.waardestelling IS 'Omvattende verklaring van de erfgoedwaarde die een archiefbestand vertegenwoordigt.';
COMMENT ON COLUMN abv.waarderingen.waarde_id IS 'Omschrijving van een specifieke erfgoedwaarde die aan het archiefbestand wordt toegekend';
COMMENT ON COLUMN abv.waarderingen.vergelijking_id IS 'Omschrijving hoe het archiefbestand zich voor een specifiek aspect verhoudt tot andere archiefbestanden.';
COMMENT ON COLUMN abv.waarderingen.datum_waardering IS 'datum waarop de waardering gemaakt werd';
COMMENT ON COLUMN abv.waarderingen.bron_waardering IS 'Verwijzing naar een publicatie die als bron werd gebruikt voor deze waardering. ';
COMMENT ON COLUMN abv.waarderingen.bijdragers IS 'De namen van personen en organisaties die een bijdrage leverden aan deze waardering';
COMMENT ON COLUMN abv.waarderingen.opmerkingen IS 'Vrij notitieveld bij deze waardering';

CREATE TABLE abv.aangroei(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.aangroei.id IS 'systeem UUID';

CREATE TABLE abv.archieven(
	identificatienummer_id int NOT NULL REFERENCES abv.identificatienummers(id), 
	titel text NOT NULL, 
	datering_systematisch text, 
	datering_text text, 
	beschrijvingsniveau_id int NOT NULL REFERENCES abv.beschrijvingsniveaus(id), 
	is_onderdeel_van_id int REFERENCES abv.archieven(id), 
	omvang_id int REFERENCES abv.omvangen(id), 
	samensteller_id int NOT NULL REFERENCES abv.samenstellers(id), 
	rol_samensteller_id int NOT NULL REFERENCES abv.rol_samenstellers(id), 
	beheerder_id int NOT NULL REFERENCES abv.beheerders(id), 
	rol_beheerder_id int NOT NULL REFERENCES abv.rol_beheerders(id), 
	geschiedenis_archief text, 
	verwerving text, 
	inhoud_en_bereik text, 
	selectie_id int REFERENCES abv.waarderingen(id), 
	aangroei_id int REFERENCES abv.aangroei(id), 
	aangroei_text text, 
	ordening_id int REFERENCES abv.ordeningen(id), 
	ordening_text text, 
	juridische_beperking_id int NOT NULL REFERENCES abv.juridische_beperkingen(id), 
	raadplegingsvoorwaarde_id int REFERENCES abv.raadplegingsvoorwaarden(id), 
	taal_id int REFERENCES abv.talen(id), 
	taal_text text, 
	toegang text, 
	bronnen_archief text, 
	bibliografie_archief text, 
	aantekening_archivaris text, 
	associatie_id int REFERENCES abv.associaties(id), 
	rechtenstatus_metadata_id int NOT NULL REFERENCES abv.rechtenstatussen(id), 
	bronverwijzing_record text NOT NULL, 
	bronverwijzing_archief text NOT NULL
);
COMMENT ON COLUMN abv.archieven.identificatienummer_id IS 'Identificatienummer voor het archief of de collectie.';
COMMENT ON COLUMN abv.archieven.titel IS 'Titel van het archiefbestand of de collectie.';
COMMENT ON COLUMN abv.archieven.datering_systematisch IS 'Jaartallen van bereik van het archief: uit welke periode stammen de documenten.';
COMMENT ON COLUMN abv.archieven.datering_text IS 'Woordelijke uitleg bij datering_systematisch, initiëel ook voor legacy data.';
COMMENT ON COLUMN abv.archieven.beschrijvingsniveau_id IS 'Beschrijvingsniveau van het archief. Keuze uit archief, fonds, serie, collectie, virtuele collectie.';
COMMENT ON COLUMN abv.archieven.is_onderdeel_van_id IS 'Alleen gebruik maken wanneer een archiefbestanddeel deel uitmaakt van een groter archiefbestanddeel';
COMMENT ON COLUMN abv.archieven.omvang_id IS 'vrije tekst beschrijving van de dimensies en materiaalsoorten waaruit het archiefbestand bestaat';
COMMENT ON COLUMN abv.archieven.samensteller_id IS 'nieuwe overkoepelende term voor zowel archiefvormers, verzamelaars als documentalisten. herhaalbaar om verschillende samenstellers en hun verschillende rollen te kunnen documenteren';
COMMENT ON COLUMN abv.archieven.beheerder_id IS 'persoon of organisatie die het archief of de collectie vandaag beheerd. link naar wat voorheen de ‘bewaarplaats’ was.  Nu expliciet gemaakt als een Agent, die verbonden is aan een bepaalde Plaats. ';
COMMENT ON COLUMN abv.archieven.geschiedenis_archief IS 'Geschiedenis van het archief.';
COMMENT ON COLUMN abv.archieven.verwerving IS 'Uitleg hoe archief verworven werd door bewaarinstelling.';
COMMENT ON COLUMN abv.archieven.inhoud_en_bereik IS 'Inhoud van archief.';
COMMENT ON COLUMN abv.archieven.selectie_id IS 'Verklaring over de erfgoedwaarde van het archiefbestand en de vergelijking met andere archiefbestanden.';
COMMENT ON COLUMN abv.archieven.aangroei_id IS 'Aangroei toont status van het archief aan: statisch, dynamisch of is de status onbekend.';
COMMENT ON COLUMN abv.archieven.aangroei_text IS 'oud aangroei veld';
COMMENT ON COLUMN abv.archieven.ordening_id IS 'Toont de ordeningsstatus aan van het archief:geordend, niet geordend of onbekend.';
COMMENT ON COLUMN abv.archieven.ordening_text IS 'oud ordening veld';
COMMENT ON COLUMN abv.archieven.juridische_beperking_id IS 'bevat het archief/collectie materiaal dat mogelijk veel persoonsgegevens bevat, bevat het archief/collectie materiaal dat mogelijk veel persoonsgegevens bevat, bevat het archief/collectie materiaal dat mogelijk auteursrechtelijk beschermd ';
COMMENT ON COLUMN abv.archieven.raadplegingsvoorwaarde_id IS 'vrije tekst omschrijving van de concrete voorwaarden die verbonden zijn aan de toegang tot het archief/collectie';
COMMENT ON COLUMN abv.archieven.taal_id IS 'trefwoord dat aangeeft welke taal gebruikt wordt in het archief';
COMMENT ON COLUMN abv.archieven.taal_text IS 'oude taal veld';
COMMENT ON COLUMN abv.archieven.toegang IS 'link naar één of meer beschrijvingen van toegangen.   veld verzamelt informatie uit oude velden “toegangen” en “online toegangen” ';
COMMENT ON COLUMN abv.archieven.bronnen_archief IS 'bibliografie werken gebruikt voor het opstellen van de beschrijving';
COMMENT ON COLUMN abv.archieven.bibliografie_archief IS 'bibliografie werken gebaseerd op of gerelateerd aan het archief/de collectie';
COMMENT ON COLUMN abv.archieven.aantekening_archivaris IS 'Dit veld zal alle aantekeningen bundelen die voordien in de velden “aantekening”, “werknotities” en “aantekening archivaris” stonden.';
COMMENT ON COLUMN abv.archieven.associatie_id IS 'Trefwoordenveld. Kan gelinkt worden met een onderwerp, agent, plaats en een periode.';
COMMENT ON COLUMN abv.archieven.rechtenstatus_metadata_id IS 'Geeft weer onder welke licentievoorwaarden de metadata gepubliceerd kunnen worden.';
COMMENT ON COLUMN abv.archieven.bronverwijzing_record IS 'Correcte verwijzing naar het record in de Chicagostijl.';
COMMENT ON COLUMN abv.archieven.bronverwijzing_archief IS 'Correcte verwijzing naar het archief in de Chicagostijl.';

CREATE TABLE abv.beheerders(
	agent_id int NOT NULL REFERENCES abv.agenten(id), 
	erkenning_id int NOT NULL REFERENCES abv.erkenningen(id), 
	adres_id int REFERENCES abv.adressen(id), 
	telefoon text, 
	email text, 
	website text, 
	gebouw text, 
	toegang text, 
	openingsuren text, 
	toegangsvoorwaarden text, 
	bereikbaarheid_id int REFERENCES abv.bereikbaarheden(id)
);
COMMENT ON COLUMN abv.beheerders.agent_id IS 'Link met agent';
COMMENT ON COLUMN abv.beheerders.erkenning_id IS 'Categorie enkel geldig wanneer agent een bewaarplaats is. Erkenningniveaus zijn: landelijk, regionaal, lokaal en [none].';
COMMENT ON COLUMN abv.beheerders.adres_id IS 'Adres van bewaarplaats.';
COMMENT ON COLUMN abv.beheerders.telefoon IS 'Telefoonnummer van bewaarplaats.';
COMMENT ON COLUMN abv.beheerders.email IS 'Emailadres van bewaarplaats.';
COMMENT ON COLUMN abv.beheerders.website IS 'Website bewaarinstelling.';
COMMENT ON COLUMN abv.beheerders.gebouw IS 'Verwijzing naar de bewaarplaatsen die verbonden zijn aan de Agent';
COMMENT ON COLUMN abv.beheerders.toegang IS 'Verwijzing naar de toegang voor de archieven/collecties die de Agent bewaard.';
COMMENT ON COLUMN abv.beheerders.openingsuren IS 'Openingsuren waarop de Agent bereikbaar/toegankelijk is';
COMMENT ON COLUMN abv.beheerders.toegangsvoorwaarden IS 'Voorwaarden om toegang te krijgen tot archieven/collecties die door de Agent worden bewaard.';
COMMENT ON COLUMN abv.beheerders.bereikbaarheid_id IS 'Indien list: Rolstoeltoegankelijk, Aangepast sanitair, Parkeergelegenheid';

CREATE TABLE abv.beschrijvingsniveaus(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.beschrijvingsniveaus.id IS 'systeem UUID';

CREATE TABLE abv.juridische_beperkingen(
	privacy_gevoelig bool NOT NULL, 
	contractuele_beperking bool NOT NULL, 
	gevoelig_voor_auteursrechtelijkebescherming bool NOT NULL
);

CREATE TABLE abv.omvangen(
	waarde text NOT NULL, 
	trefwoord_id int REFERENCES abv.materiaalsoorten(id)
);

CREATE TABLE abv.onderwerpen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.onderwerpen.id IS 'systeem UUID';

CREATE TABLE abv.periodes(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.periodes.id IS 'systeem UUID';

CREATE TABLE abv.adressen(
	straat_en_nummer text, 
	gemeente_id int NOT NULL REFERENCES abv.plaatsen(id)
);

CREATE TABLE abv.bereikbaarheden(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.bereikbaarheden.id IS 'systeem UUID';

CREATE TABLE abv.erkenningen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.erkenningen.id IS 'systeem UUID';

CREATE TABLE abv.type_concepten(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.type_concepten.id IS 'systeem UUID';

CREATE TABLE abv.type_identificatienummers(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.type_identificatienummers.id IS 'systeem UUID';

CREATE TABLE abv.type_namen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.type_namen.id IS 'systeem UUID';

CREATE TABLE abv.materiaalsoorten(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.materiaalsoorten.id IS 'systeem UUID';

CREATE TABLE abv.ordeningsstatussen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.ordeningsstatussen.id IS 'systeem UUID';

CREATE TABLE abv.raadplegingsstatussen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.raadplegingsstatussen.id IS 'systeem UUID';

CREATE TABLE abv.functies(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.functies.id IS 'systeem UUID';

CREATE TABLE abv.type_vergelijkingen(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.type_vergelijkingen.id IS 'systeem UUID';

CREATE TABLE abv.type_waarden(
	id SERIAL NOT NULL PRIMARY KEY
);
COMMENT ON COLUMN abv.type_waarden.id IS 'systeem UUID';

CREATE TABLE abv.vergelijkingen(
	waarde text NOT NULL, 
	type_vergelijking_id int NOT NULL REFERENCES abv.type_vergelijkingen(id)
);

CREATE TABLE abv.identificatienummers(
	waarde text, 
	type_id int REFERENCES abv.type_identificatienummers(id), 
	bron_id int REFERENCES abv.agenten(id)
);
COMMENT ON COLUMN abv.identificatienummers.bron_id IS 'Verwijzing naar agent die identificatie aanmaakt.';
