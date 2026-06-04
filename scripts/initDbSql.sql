--Siin failis on SQL-d, mis on vaja andmebaasitabelite jms loomiseks

--Elektri hinnad (aeg=timestamp ja hind on täisarv, aga tagasi viimiseks vaja jagada 10000'ga (4 komakohta, ehk sajandik komatäpsus)
CREATE TABLE elektrihind(
	aeg INTEGER NOT NULL,
	hind INTEGER NOT NULL,
	CONSTRAINT elektrihind_pk PRIMARY KEY (aeg)
);



