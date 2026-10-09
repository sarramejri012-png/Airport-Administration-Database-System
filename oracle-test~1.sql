-- ============================================================
-- BASE AEROPORT READY (sans erreur)
-- ============================================================

SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

-- =========================
-- NETTOYAGE
-- =========================
BEGIN
    FOR u IN (SELECT username FROM dba_users
              WHERE username IN ('AEROPORT','APP_ADMIN','APP_USER','AUDITEUR'))
    LOOP
        EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
    END LOOP;
END;
/

BEGIN
    FOR r IN (SELECT role FROM dba_roles
              WHERE role IN ('ROLE_LECTEUR','ROLE_OPERATEUR','ROLE_MANAGER'))
    LOOP
        EXECUTE IMMEDIATE 'DROP ROLE ' || r.role;
    END LOOP;
END;
/

-- =========================
-- USER AEROPORT
-- =========================
CREATE USER aeroport
IDENTIFIED BY "Aer0p0rt#"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE VIEW,
      CREATE SEQUENCE,
      CREATE PROCEDURE,
      CREATE TRIGGER
TO aeroport;

-- =========================
-- TABLES
-- =========================
CREATE TABLE aeroport.pilote (
    pilno NUMBER PRIMARY KEY,
    nom VARCHAR2(30),
    prenom VARCHAR2(30),
    age NUMBER,
    adresse VARCHAR2(100),
    salaire NUMBER
);

CREATE TABLE aeroport.avion (
    avno NUMBER PRIMARY KEY,
    avnom VARCHAR2(50),
    capacite NUMBER,
    loc VARCHAR2(50)
);

CREATE TABLE aeroport.vol (
    volno VARCHAR2(10) PRIMARY KEY,
    dep VARCHAR2(50),
    arr VARCHAR2(50),
    hd DATE,
    ha DATE,
    avno NUMBER,
    pilno NUMBER,
    FOREIGN KEY (avno) REFERENCES aeroport.avion(avno),
    FOREIGN KEY (pilno) REFERENCES aeroport.pilote(pilno)
);

CREATE TABLE aeroport.defpilote (
    volno VARCHAR2(10),
    pilno NUMBER,
    role VARCHAR2(20),
    PRIMARY KEY (volno, pilno),
    FOREIGN KEY (volno) REFERENCES aeroport.vol(volno),
    FOREIGN KEY (pilno) REFERENCES aeroport.pilote(pilno)
);

CREATE TABLE aeroport.bonus_pilote (
    pilno   NUMBER,
    nom     VARCHAR2(30),
    heures_vol NUMBER,
    prime   NUMBER
);

-- =========================
-- SEQUENCES
-- =========================
CREATE SEQUENCE aeroport.seq_pilote START WITH 100;
CREATE SEQUENCE aeroport.seq_avion START WITH 10;

-- =========================
-- DONNÉES
-- =========================
INSERT INTO aeroport.pilote VALUES (100, 'Laroche','Pierre',39,'Montauban',4800);
INSERT INTO aeroport.pilote VALUES (101, 'Lamothe','Sophie',34,'Toulouse',4200);

INSERT INTO aeroport.avion VALUES (10,'Airbus A320',180,'Toulouse');
INSERT INTO aeroport.avion VALUES (11,'Boeing 737',160,'Paris');

INSERT INTO aeroport.vol VALUES (
'AF101','Paris','Toulouse',
SYSDATE,
SYSDATE+1/24,
10,100
);

INSERT INTO aeroport.defpilote VALUES ('AF101',101,'COPILOTE');

COMMIT;

-- =========================
-- VUES
-- =========================
CREATE OR REPLACE VIEW aeroport.v_vols_detail AS
SELECT v.volno,
       v.dep,
       v.arr,
       a.avnom,
       p.nom || ' ' || p.prenom pilote
FROM aeroport.vol v
JOIN aeroport.avion a ON v.avno=a.avno
JOIN aeroport.pilote p ON v.pilno=p.pilno;

-- =========================
-- USERS
-- =========================
CREATE USER app_admin IDENTIFIED BY "Oracle1!";
CREATE USER app_user IDENTIFIED BY "Oracle2!";
CREATE USER auditeur IDENTIFIED BY "Oracle3!";

GRANT CREATE SESSION TO app_admin, app_user, auditeur;

-- =========================
-- ROLES
-- =========================
CREATE ROLE role_lecteur;
GRANT SELECT ON aeroport.pilote TO role_lecteur;
GRANT SELECT ON aeroport.vol TO role_lecteur;

CREATE ROLE role_operateur;
GRANT INSERT, UPDATE ON aeroport.vol TO role_operateur;

CREATE ROLE role_manager;
GRANT role_lecteur, role_operateur TO role_manager;

GRANT role_manager TO app_admin;
GRANT role_operateur TO app_user;
GRANT role_lecteur TO auditeur;

-- =========================
-- FIN
-- =========================