#!/bin/bash
java -jar ./widoco-1.4.16-jar-with-dependencies.jar \
     -confFile ./build_doc.properties \
     -includeImportedOntologies \
     -rewriteAll \
     -ontFile ../solis/abv_schema.ttl \
     -webVowl \
     -lang nl \
     -outFolder _doc