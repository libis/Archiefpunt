--
-- AUDIT ontology - 0.2 - 2022-09-20 15:04:20 +0200
-- description: 
-- author: LIBIS
--


CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
DROP SCHEMA IF EXISTS audit CASCADE;
CREATE SCHEMA audit;


CREATE TABLE audit.change_sets(
	id SERIAL NOT NULL PRIMARY KEY, 
	diff text NOT NULL, 
	subject_of_change text, 
	preceding_change_set_id int REFERENCES audit.change_sets(id), 
	created_date text, 
	change_reason text, 
	creator_name text, 
	creator_group text, 
	other_data text
);
COMMENT ON TABLE audit.change_sets 'The encapsulation of a delta between two versions of a resource description';
COMMENT ON COLUMN audit.change_sets.id IS 'uuid';
COMMENT ON COLUMN audit.change_sets.diff IS 'changes in hashdiff format';
COMMENT ON COLUMN audit.change_sets.subject_of_change IS 'the resource to which this set of changes applies';
COMMENT ON COLUMN audit.change_sets.preceding_change_set_id IS 'This property can be used to build a history of changes to a particular resource description';
COMMENT ON COLUMN audit.change_sets.created_date IS 'the date that the changeset was created. The date should be in W3CDTF format ';
COMMENT ON COLUMN audit.change_sets.change_reason IS 'a short, human readable description of the purpose for the changeset';
COMMENT ON COLUMN audit.change_sets.creator_name IS 'the name of the entity responsible for creating the changeset';
COMMENT ON COLUMN audit.change_sets.creator_group IS 'the name of the group responsible for creating the changeset';
COMMENT ON COLUMN audit.change_sets.other_data IS 'data pushed from the enduser';
