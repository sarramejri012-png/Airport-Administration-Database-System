-- =========================
-- ETAPE 2
-- =========================
--forcer APP_ADMIN à changer son mot de passe tous les 30 jours.
CREATE PROFILE profil_admin LIMIT
    PASSWORD_LIFE_TIME 30;

ALTER USER app_admin PROFILE profil_admin;

--Verrouillage après 3 tentatives
ALTER PROFILE DEFAULT LIMIT
    FAILED_LOGIN_ATTEMPTS 3
    PASSWORD_LOCK_TIME 1;
    
--tracer qui consulte les vols
AUDIT SELECT ON aeroport.v_vols_detail BY ACCESS;
--Vérifier les accès
SELECT username,obj_name,action_name,timestamp,returncode
FROM dba_audit_trail
WHERE obj_name = 'V_VOLS_DETAIL'
ORDER BY timestamp DESC;
--réinitialiser les logs
NOAUDIT SELECT ON aeroport.v_vols_detail;

-- =========================
-- ETAPE 3
-- =========================
--Empêche un pilote d’être affecté à deux vols en même temps.
CREATE OR REPLACE TRIGGER trg_dispo_pilote
BEFORE INSERT OR UPDATE ON aeroport.defpilote
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM aeroport.defpilote d
    JOIN aeroport.vol v1 ON v1.volno = d.volno
    JOIN aeroport.vol v2 ON v2.volno = :NEW.volno
    WHERE d.pilno = :NEW.pilno
      AND v1.volno != :NEW.volno
      AND (
            v2.hd BETWEEN v1.hd AND v1.ha
         OR v2.ha BETWEEN v1.hd AND v1.ha
      );

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
        'Pilote déjà affecté à un autre vol (chevauchement détecté)');
    END IF;
END;

--Bonus selon heures de vol du mois
CREATE OR REPLACE PROCEDURE calcul_prime_pilotes
IS
BEGIN
    DELETE FROM bonus_pilote;
    INSERT INTO bonus_pilote
    SELECT p.pilno,p.nom,ROUND(SUM((v.ha - v.hd) * 24),2) AS heures_vol,ROUND(SUM((v.ha - v.hd) * 24) * 100,2) AS prime
    FROM aeroport.pilote p
    JOIN aeroport.vol v
        ON p.pilno = v.pilno
    WHERE TRUNC(v.hd,'MM') = TRUNC(SYSDATE,'MM')
    GROUP BY p.pilno, p.nom;
    COMMIT;
END;
/

--Historique des salaires
CREATE TABLE aeroport.hist_salaire (
    id NUMBER GENERATED ALWAYS AS IDENTITY,
    pilno NUMBER,
    ancien_salaire NUMBER,
    nouveau_salaire NUMBER,
    date_modif DATE,
    user_modif VARCHAR2(50)
);
CREATE OR REPLACE TRIGGER trg_hist_salaire
AFTER UPDATE OF salaire ON aeroport.pilote
FOR EACH ROW
BEGIN
    INSERT INTO aeroport.hist_salaire VALUES (DEFAULT,:OLD.pilno,:OLD.salaire,:NEW.salaire,SYSDATE,USER);
END;
/

--Rapport de performance avions
CREATE OR REPLACE PROCEDURE rapport_avions
IS
BEGIN
    FOR r IN (
        SELECT a.avnom,COUNT(v.volno) nb_vols,a.capacite,ROUND((COUNT(v.volno) / a.capacite) * 100,2) taux_remplissage
        FROM aeroport.avion a
        LEFT JOIN aeroport.vol v
            ON a.avno = v.avno
        GROUP BY a.avnom, a.capacite
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Avion : ' || r.avnom ||' | Nb vols : ' || r.nb_vols ||' | Taux remplissage approx : ' ||r.taux_remplissage || '%');
    END LOOP;
END;
/

--Validation des escales + durée vol interdit vol si durée < 30 min
CREATE TABLE aeroport.aeroport_valide (
    nom_aeroport VARCHAR2(50) PRIMARY KEY
);
INSERT INTO aeroport.aeroport_valide VALUES ('Paris-CDG');
INSERT INTO aeroport.aeroport_valide VALUES ('Toulouse-Blagnac');
INSERT INTO aeroport.aeroport_valide VALUES ('New York-JFK');
INSERT INTO aeroport.aeroport_valide VALUES ('Tokyo-Narita');
INSERT INTO aeroport.aeroport_valide VALUES ('Lyon-Saint-Exupéry');
INSERT INTO aeroport.aeroport_valide VALUES ('Marseille-Provence');
INSERT INTO aeroport.aeroport_valide VALUES ('Tunis-Carthage');
COMMIT;
CREATE OR REPLACE TRIGGER trg_validation_vol
BEFORE INSERT OR UPDATE ON aeroport.vol
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    -- Vérification destination valide
    SELECT COUNT(*)
    INTO v_count
    FROM aeroport.aeroport_valide
    WHERE nom_aeroport = :NEW.arr;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20020,'Destination invalide' );
    END IF;
    -- Vérification durée minimale
    IF (:NEW.ha - :NEW.hd) * 24 * 60 < 30 THEN
        RAISE_APPLICATION_ERROR(-20021, 'Durée du vol inférieure à 30 minutes' );
    END IF;
END;


--Blocage modification week-end
CREATE OR REPLACE TRIGGER trg_bloc_weekend
BEFORE INSERT OR UPDATE OR DELETE ON aeroport.pilote
BEGIN
    IF TO_CHAR(SYSDATE,'DY','NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT','SUN') THEN
        RAISE_APPLICATION_ERROR(-20003,
        'Modification interdite pendant le week-end');
    END IF;
END;

-- =========================
-- ETAPE 4
-- =========================
--empêcher un avion trop petit pour un vol
CREATE OR REPLACE TRIGGER trg_capacite_avion
BEFORE INSERT OR UPDATE ON aeroport.vol
FOR EACH ROW
DECLARE
    v_capacite NUMBER;
BEGIN
    SELECT capacite
    INTO v_capacite
    FROM aeroport.avion
    WHERE avno = :NEW.avno;
    IF v_capacite < 50 THEN
        RAISE_APPLICATION_ERROR(-20040,'Capacité insuffisante pour assurer ce vol' );
    END IF;
END;

--chaque pilote doit utiliser SEQ_PILOTE automatiquement
CREATE OR REPLACE TRIGGER trg_seq_pilote
BEFORE INSERT ON aeroport.pilote
FOR EACH ROW
BEGIN
    IF :NEW.pilno IS NULL THEN
        SELECT aeroport.seq_pilote.NEXTVAL
        INTO :NEW.pilno
        FROM dual;
    END IF;
END;

--On interdit suppression si pilotes secondaires existent
CREATE OR REPLACE TRIGGER trg_delete_vol_secure
BEFORE DELETE ON aeroport.vol
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM aeroport.defpilote
    WHERE volno = :OLD.volno;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20011,
        'Suppression impossible : affectations secondaires existantes');
    END IF;
END;





