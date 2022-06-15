# Archiefpunt Data-API


De nieuwe [API](https://en.wikipedia.org/wiki/API) is een op het [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) principe gebaseerde API die de [JSON:API](https://jsonapi.org/) standaard volgt. [JSON:API](https://jsonapi.org/) focust zich op de eenvoud van implementatie zowel in de frontend als de backend.
Dit document bevat geen uitgebreide lijst van entiteiten of api endpoints. [JSON:API](https://jsonapi.org/) maakt gebruik van een schema alle entiteiten kunnen op dezelfde wijze opgevraagd, aangemaakt, verwijderd en aangepast worden. Het schema kan via de
Schema Endpoint opgevraagd worden.


## Model

Het [model](https://docs.google.com/spreadsheets/d/1xhvOCfiSIOtHjIJUtRrxvJ54OoDosNJ_JsA1B7FfpsI/edit?usp=sharing) maakt gebruik van een Google Sheet. De data hierin wordt omgezet naar een [SHACL](https://www.w3.org/TR/shacl/) file deze beschrijft de API dat hieronder beschreven is. De [_ENTITIES](https://docs.google.com/spreadsheets/d/1xhvOCfiSIOtHjIJUtRrxvJ54OoDosNJ_JsA1B7FfpsI/edit?usp=sharing) tab bevat een lijst van actieve entiteiten. subClassOf geeft inheritance binnen het model weer en sameAs de semantische inheritance met een extern model. Dus Functies is een subClassOf Codetabellen en deze een subClassOf Concept. Alle Codetabellen samen met de Functies codetabel kunnen met de /codetabellen endpoint opgevraagd worden alsook alle /concepten waar Codetabellen een onderdeel van is. Elke tab beschrijft een entity met zijn properties, cardinaliteit en verwachte datatype.


## Authenticatie

We maken gebruik van [OAuth2](https://oauth.net/2/). Om de API te bevragen heb je een token of een login nodig.


## Audit

Alle queries naar de API komen in een audit log terecht deze kan door beheerders bevraagd worden.


## Identifiers

Bij het aanmaken van een record wordt er een [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) (v4:random) aangemaakt voor de nieuwe entiteit. Als er een [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) aanwezig is wordt deze gebruikt bij het aanmaak van nieuwe entiteiten. We raden aan om het systeem een [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) te laten genereren.


## Endpoints


```
Test endpoints 
Basis: https://abv.libis.be
```



### Basis

[https://data.archiefbank.be](https://data.archiefbank.be)


```
Content-Type: application/vnd.api+json
```


Oproepen van de basis endpoint geeft een lijst van entiteiten die kunnen gebruikt worden om data op te vragen. Er bestaan 2 soorten entiteiten.



* Abstracte entiteiten: deze kunnen vergeleken worden met een super class. Kunnen gebruikt worden om te queryen bv. De entiteit Persoon is de super class voor archivaris, inbinder, vrijwilliger, … Als men alle personen opvraagt krijg je een lijst van personen met type archivaris, inbinder, vrijwilliger.
* Data entiteiten: deze kan men gebruiken om 1 of meerdere entiteiten van een bepaald type te lezen, schrijven, aanpassen en te verwijderen. Kortom alle [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) operaties.


```
curl https://data.archiefbank.be/
Content-Type: application/json
[
    "/aangroei",
    "/adressen",
    "/agenten",
    "/archieven",
...
    "/bronverwijzingen",
    "/concepten",
    "/contact_personen",
...
    "/talen",
    "/titels",
    "/toegangen",
    "/verwervingen",
    "/waarderingen"
]
```



### Schema

[https://data.archiefbank.be/schema.json](https://data.archiefbank.be/schema.json)


```
Content-Type: application/json
```


Deze endpoint roept een schema op en kan gebruikt worden door [JSON:API](https://jsonapi.org/) bibliotheken voor het opbouwen van een interne api. Zoals [spraypaint](https://github.com/graphiti-api/spraypaint.js) kijk op deze [lijst](https://jsonapi.org/implementations/#client-libraries) voor een uitgebreidere lijst.

Het schema kan opgevraagd worden in verschillende formaten. Deze formaten kunnen door een ondersteunde [mime-type](https://en.wikipedia.org/wiki/Media_type) in een [Accept header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept) op te geven of een query parameter.


<table>
  <tr>
   <td><strong>Accept header/query param mime-type</strong>
   </td>
   <td><strong>Omschrijving</strong>
   </td>
  </tr>
  <tr>
   <td>application/plantuml
   </td>
   <td>Schema als een <a href="https://plantuml.com/">PlantUML</a> file
   </td>
  </tr>
  <tr>
   <td>application/n-triples
   </td>
   <td>Schema als n-triples
   </td>
  </tr>
  <tr>
   <td>application/n-quads
   </td>
   <td>Schema als n-quads
   </td>
  </tr>
  <tr>
   <td>application/ld+json
   </td>
   <td>Schema als JSON-LD 
   </td>
  </tr>
  <tr>
   <td>application/rdf+json
   </td>
   <td>Schema als RDF/JSON
   </td>
  </tr>
  <tr>
   <td>text/html
   </td>
   <td>Schema als HTML
   </td>
  </tr>
  <tr>
   <td>text/n3
   </td>
   <td>Schema als n3 notatie
   </td>
  </tr>
  <tr>
   <td>text/turtle
   </td>
   <td>Schema as Turtle. (Preferred format)
   </td>
  </tr>
</table>


Bv.

Via een [Accept header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept)

HEADER Accept: text/turtle

[https://data.archiefbank.be/schema.json](https://data.archiefbank.be/schema.json)

Of via een accept parameter

[https://data.archiefbank.be/schema.json?accept=text/turtle](https://data.archiefbank.be/schema.json?accept=text/turtle)


### Entity

[https://data.archiefbank.be/[ENTITY](https://data.archiefbank.be/[ENTITY)]

[https://data.archiefbank.be/[ENTITY]/[ID](https://data.archiefbank.be/[ENTITY]/[ID)]


```
Content-Type: application/vnd.api+json
```


Opvragen van data voor een entity kan gebeuren door gebruik te maken van de JSON:API query mogelijkheden als ook op een RESTful manier door de id van de entiteit.


### Model

[https://data.archiefbank.be/[ENTITY]/model](https://data.archiefbank.be/[ENTITY]/model)


```
Content-Type: application/json
```


Ophalen van een entity beschrijving. Geeft een blauwdruk van de attributen die nodig zijn om een entiteit aan te maken.

Bv.

[http://data.archiefbank.be/bronverwijzingen/model](http://data.archiefbank.be/bronverwijzingen/model)


```
Content-Type: application/json
```


{

    "type": "bronverwijzingen",

    "attributes": {

        "record": {

            "description": "",

            "mandatory": true,

            "data_type": "string"

        },

        "archief": {

            "description": "",

            "mandatory": true,

            "data_type": "string"

        }

    }

}


### Vandal

[https://data.archiefbank.be/vandal](https://data.archiefbank.be/vandal)

UI om [JSON:API](https://jsonapi.org/) te testen alsook queries te schrijven.


## Queries

Lees de JSON:API [specificaties](https://jsonapi.org/format/) voor een uitgebreide uitleg van hoe queries opgebouwd worden hieronder geven we een paar voorbeelden met betrekking tot Archiefbank .


### CREATE

POST [https://data.archiefbank.be/bronverwijzingen](https://data.archiefbank.be/bronverwijzingen)

HEADER `Content-Type: application/json`

BODY


```
{
   "type": "bronverwijzingen",
   "attributes": {
       "record": "Test record",
       "archief": "Persoonlijk archief van Test"
   }
}
```



### READ

Bv.


#### Alle archieven

GET [https://data.archiefbank.be/archieven](https://data.archiefbank.be/archieven)


#### Archief met id=1

GET [https://data.archiefbank.be/archieven/1](https://data.archiefbank.be/archieven/1)

GET [https://data.archiefbank.be/bronverwijzingen?filter[id][eq]=1&page[number]=1&page[size]=10](https://data.archiefbank.be/bronverwijzingen?filter[id][eq]=1&page[number]=1&page[size]=10)

GET [https://data.archiefbank.be/archieven?filter[beheerder.id][eq]=1&sort=beheerder.id&include=beheerder.rol](https://data.archiefbank.be/archieven?filter[beheerder.id][eq]=1&sort=beheerder.id&include=beheerder.rol)


### UPDATE

PUT [https://data.archiefbank.be/bronverwijzingen/1](https://data.archiefbank.be/bronverwijzingen/1)


```
{
   "type": "bronverwijzingen",
   "attributes": {
       "id": "1",
       "record": "Test record",
       "archief": "Persoonlijk archief van Test"
   }
}
```



### DELETE

DELETE  [https://data.archiefbank.be/archieven/1](https://data.archiefbank.be/archieven/1)


## ERD voor archieven

Zie volgende pagina voor diagram of [online](http://www.plantuml.com/plantuml/svg/L53DpjCm4BpxAVRxEAAW95H2v51HLL0gqO80mR7QnflKYdyisw64q7TdMxKekSIxExCpEtaN4uRK6osUVC3M86WSN9-0T2TYfwp7W0PgZJ5-S3PzKty8YeLuajGeI_1fk_du_VFNrNxpVa9lW-lzrfueg8IsvesfbZFUMMAjD6W2zYudw3cWtr6CsD9F9TC9YZoVmAiGt7djj0lmOeV1EIj4KaaJ8_L9KND4sy4FZMWb1RB0DpEx7I23_5N1tp8lYon_c-Kb56MrU5qLR-1bNhABy5Xtx0ju_0MZk6M65LfEGqey2iYolqjOEuxbquCa0yLHZ8qYBI_mEyegfg1i2nLmWPWEP0-sDuR2VnQxL5yqOv5PBHdYNqBY8kwp39wBvvlo58VbmxBbTfo9RIMFLADgJ8fuHqtx6VD-FNFIuEVG7j7mtF8pooEHpIkuFjTWivqD_Il5QdeSjs7elR-g7RGz50LQT1VjqP1ZxaGJ9measuFTel-zJw8ZcWw53IQdME8ZHL7lwICfrnx3-LJoAWbBN-ToftBvTRuSaDKBnK3Nd_2v-8byTlp2bgulfivLc_B_9PxeSk4Aq-rR8MwLS_dNNfg9Hle22jbMEZi_sgPtwXDoQYrb7-PtPViSwDKLps-1JXEtxD3XIdagQOxKo6jrxp1EdFqfBI74T-SYIjrOP9II_Aa7vaX-q9avD-QO-D7LIoaS_4eaLnj9JtdknygsFePBr-TLZ_vjaTMme1wDy1eT0C8DgnRGomdVK8KYDyJ10jYp7FAuJPlrmoZcEOoPtUBCD4Vt7O45Op4P7ZP_bL-Jo70N-eg3y1W0PgyOcSOm59ef2_CDffLbObDqKwMf04qDO38X1C3CGBVmGOoA6C386Wl6u8MDD6aXknrlxX_TxpwZxeNc-VV1RKqBID9F5x-GcnLoJGz8K2JaasSW6hl5QKN-SLuS4xjyADidTwPBGdeZHI3IfgbmBtGaX2-W_lRTt8qbCSrYxbPkVrDyfxYmyfRQK1WSwM4UNWfdWFAbcOysff72_bEsfDiXI2CTzgjIJrGGQVtKvOevMoxO-gdilytH3nxJWWol40z3tsflrvTkOradYF5FYYc42pmEt77b3eNzoxdXEj8hOcpsMVX4qz3SMkt3O5McNb_8vMMh5aD1sc6Z6bbkhINkjZTPb7wYKwak0nSNeUT7JeE6MY8TZbDchvlcr9rfSf2NkvjbvfX_-oPpb0vpl-T963i-grj1Yj3tXu7OBK43lTeLsX8re2nbZQp2Xbt9MLBRAHj0qREWHDe5OWXQWKrjmqyKhU4YRe2Kf0Lcg1jWqRI2Lda3KaMjIoCI1wOAMsD4vi1OujPmM-fmrGBNcMgj0smhN3lPOfV3ia9PxN8KQviSn5ha6cUVc8RAbPCfU7LkQxY8kAsIXf3XeELxhovbbaEyZlclVNE-bWzbgpUD_DlORx2OFWpKi4AvXU_NxTDgaqiT5tdoQDgyZYrbqdOPlusG76ejgknrARRtKdqGXH7TCOoO1OEuw3MEN6O1DOnmbS7rUq0thVUjmJwBaQRhZke6zsqd8P3ri6PsXZZOjbK0A1P7NED_-C7yk-lB1NBCluy-fN_EVv5u3ZtSlgsZJMBiZpOULq5A2ffhEWVOP6HbhKbK9kYjiit53UjsFYkWHgn3DrPjebEQMlSa39DRJ5y9nLRXRtqzoJlAOb7ZZTPyknaXxXw6vgoCD-A3KxoBlv-gSVO_NrWZw7vSnT76Y7mCFgg6xNiGwUWpHmqdF6OV2y9n9DtDBURf-gXe-y8Ozn8zO1_2I2xhuXhzuWvVkrTQ0et-rOJnbIH2K3ED-ibYWRyJAzzEEZTFDCV4f_VetqvKBXCKpuWhMsBPMrh50lYXnymd33Z1aFAlgYB7b_8nKfdOgvOs_pbZvoFdeJdkH_wC_4ybb8UMVCp_WnXZn989yAFWSRKq2SY1zjIxNPlb_cpiM7p5MHloFylQOTzsdrUC7NS_0TnCykt4IblUIqzVYIIKVIlITdKnAfHWObX9vWdph2sZHyWdrvw3xCksFYRMbhpgdbysYRKVKrvwpuyYiMGKx4973uOSV3oCnDzdcevXIDoWytNwYgvpJp7zy2DTXlay_Wy0) (opgelet externe link)

![alt_text](config/solis/abv.png "Class model")

