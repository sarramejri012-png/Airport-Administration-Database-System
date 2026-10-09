--Journal de Tests Complet — Projet AEROPORT

--STEP 1 — Infrastructure et Déploiement
--Test 1.1 — Vérifier création utilisateur AEROPORT
SELECT username
FROM dba_users
WHERE username = 'AEROPORT';

--Test 1.2 — Vérifier tables créées
SELECT table_name
FROM all_tables
WHERE owner='AEROPORT';

--Test 1.3 — Vérifier séquences
SELECT sequence_name
FROM all_sequences
WHERE sequence_owner='AEROPORT';

--Test 1.4 — Vérifier données insérées
SELECT COUNT(*) FROM aeroport.pilote;
SELECT COUNT(*) FROM aeroport.avion;
SELECT COUNT(*) FROM aeroport.vol;

--Test 1.5 — Vérifier accès distant
CONNECT app_admin/Oracle1!;


--STEP 2 — Sécurité et Contrôle d’Accès
--Test 2.1 — Expiration mot de passe 30 jours
SELECT username, profile
FROM dba_users
WHERE username='APP_ADMIN';

--Test 2.2 — Vérifier paramètres du profil
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE profile = 'PROFIL_ADMIN';

--Test 2.3 — Verrouillage après 3 erreurs
--Faire 3 mauvaises connexions app_admin / mauvaismotdepasse
--Puis :
SELECT username, account_status
FROM dba_users
WHERE username='APP_ADMIN';

--Test 2.4 — Déverrouiller compte
ALTER USER app_admin ACCOUNT UNLOCK;

--Test 2.5 — Audit accès vue
SELECT * FROM aeroport.v_vols_detail;

--Puis :
SELECT username, action_name, obj_name
FROM dba_audit_trail
WHERE obj_name='V_VOLS_DETAIL';



--STEP 3 — Logique Métier (PL/SQL)
--Test 3.1 Affecter pilote 100 au vol AF999 (chevauchement avec AF101)
INSERT INTO aeroport.vol VALUES('AF999','Paris-CDG','Tunis-Carthage',SYSDATE,SYSDATE + 1/24,10,101);
INSERT INTO aeroport.defpilote VALUES ('AF999', 100, 'PILOTE');

--Test 3.2 — Calcul bonus pilote
BEGIN
    calcul_prime_pilotes;
END;
--Puis :
SELECT * FROM bonus_pilote;

--Test 3.3 — Historique salaires
UPDATE aeroport.pilote
SET salaire = 7000
WHERE pilno = 100;
--Puis :
SELECT * FROM aeroport.hist_salaire;

--Test 3.4 — Rapport avions
SET SERVEROUTPUT ON;
BEGIN
    rapport_avions;
END;

--Test 3.5 — Validation destination invalide et durée invalide
INSERT INTO aeroport.vol VALUES ('AF700','Paris-CDG','XXXX',SYSDATE,SYSDATE + 1,10,100);
INSERT INTO aeroport.vol VALUES ('AF701','Paris-CDG','Tunis-Carthage',SYSDATE,SYSDATE + 10/1440,10,100);
--Test 3.6 — Validation durée incohérente
INSERT INTO aeroport.vol VALUES ('AF701','Paris','Tunis',SYSDATE,SYSDATE + 10/1440,10,100);

--Test 3.7 — Blocage weekend
UPDATE aeroport.pilote
SET salaire = 9000
WHERE pilno = 100;

--STEP 4 — Gestion des Incidents et Robustesse
--Test 4.1 — Capacité avion dépassée
UPDATE aeroport.avion
SET capacite = 10
WHERE avno = 10;

INSERT INTO aeroport.vol VALUES ('AF900','Paris-CDG','Tunis-Carthage',SYSDATE,SYSDATE + 2/24,10,100);

--Test 4.2 — Séquence automatique
--Sans ID
INSERT INTO aeroport.pilote
(nom, prenom, age, adresse, salaire)
VALUES
('Auto','Seq',30,'Tunis',4000);

--Avec ID manuel
INSERT INTO aeroport.pilote VALUES
(999,'Test','Erreur',30,'Tunis',3000);

--Test 4.3 — Suppression vol avec affectation
DELETE FROM aeroport.vol
WHERE volno='AF101';


--Test 4.4 — Suppression vol sans affectation
INSERT INTO aeroport.vol VALUES ('TESTDEL','Paris-CDG','Tunis-Carthage',SYSDATE,SYSDATE+1,10,100);
DELETE FROM aeroport.vol
WHERE volno='TESTDEL';