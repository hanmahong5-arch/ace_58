-- PostgreSQL DDL for database: aion_account_db
-- Generated from SQL Server schema: AionAccountDB
-- Tables: 17

CREATE TABLE accountauth (
    gameaccountno integer DEFAULT 1 NOT NULL,
    gameaccount varchar(16) NOT NULL,
    password bytea NULL,
    quiz1 varchar(255) NULL,
    quiz2 varchar(255) NULL,
    phonenumber bigint DEFAULT 0 NOT NULL,
    cryptographtypecode smallint DEFAULT 1 NOT NULL,
    legalbirthday timestamp NOT NULL,
    gendercode smallint NOT NULL,
    gameaccounttypecode smallint DEFAULT 1 NOT NULL,
    gameaccountgradecode smallint DEFAULT 1 NOT NULL,
    accountstatuscode smallint DEFAULT 1 NOT NULL,
    authlimittypebitset integer DEFAULT 1 NOT NULL,
    securityserviceflag boolean DEFAULT false NOT NULL,
    restrictflag boolean DEFAULT false NOT NULL,
    noticeflag boolean DEFAULT false NOT NULL,
    hardwareid varchar(16) NULL,
    email varchar(50) DEFAULT '' NOT NULL,
    CONSTRAINT pk_accountauth PRIMARY KEY (gameaccountno)
);

CREATE TABLE accountetc (
    gameaccountno integer NOT NULL,
    banserverbitset bytea DEFAULT '\x00'::bytea NOT NULL,
    accountcustomizebitset bytea NULL,
    lastlogingameserverno smallint NULL,
    lastlogindate timestamp NULL,
    lastlogoutdate timestamp NULL,
    last_ip varchar(15) NULL,
    last_mac varchar(20) NULL,
    hardware varchar(16) NULL,
    accountcreatedate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    packageversioninfo smallint NULL,
    promoters varchar(14) NULL,
    note_ip varchar(15) NULL,
    CONSTRAINT pk_accountetc PRIMARY KEY (gameaccountno)
);

CREATE TABLE accountgamecharacter (
    gameaccountno integer NOT NULL,
    gameserverno smallint NOT NULL,
    characterno integer NOT NULL,
    characterlevel integer NOT NULL,
    modifydate timestamp NOT NULL,
    CONSTRAINT pk_accountgamecharacter PRIMARY KEY (gameaccountno, gameserverno)
);

CREATE TABLE accountgameslot (
    gameaccountno integer NOT NULL,
    gameslotavailstartdate timestamp NOT NULL,
    gameslotcustomizebitset bytea NOT NULL,
    CONSTRAINT pk_accountgameslot PRIMARY KEY (gameaccountno)
);

CREATE TABLE accounthistory (
    gameaccountno integer NOT NULL,
    registerdate timestamp NOT NULL,
    gameaccounthistorytypecode smallint NOT NULL,
    changevalue varchar(100) NULL,
    CONSTRAINT pk_accounthistory PRIMARY KEY (gameaccountno, registerdate)
);

CREATE TABLE accountlink (
    gameaccountno integer NOT NULL,
    linktargetno integer NOT NULL,
    CONSTRAINT pk_accountlink PRIMARY KEY (gameaccountno, linktargetno)
);

CREATE TABLE accountloginnotice (
    gameaccountno integer NOT NULL,
    noticetypecode smallint NOT NULL,
    noticestartdate timestamp NOT NULL,
    noticeenddate timestamp NOT NULL,
    CONSTRAINT pk_accountloginnotice PRIMARY KEY (gameaccountno, noticetypecode)
);

CREATE TABLE accountno (
    gameaccountno integer NOT NULL
);

CREATE TABLE accountsecurityservice (
    gameaccountno integer NOT NULL,
    accountsecuritymethodcode smallint NOT NULL,
    accountsecuritystatuscode smallint NOT NULL,
    modifydate timestamp NOT NULL,
    CONSTRAINT pk_accountsecurityservice PRIMARY KEY (gameaccountno, accountsecuritymethodcode)
);

CREATE TABLE admin_list (
    admin_id integer NOT NULL,
    CONSTRAINT pk_admin_list PRIMARY KEY (admin_id)
);

CREATE TABLE concurrentuserstat (
    serverno smallint NOT NULL,
    servertypecode smallint NOT NULL,
    concurrentuserstattypecode smallint NOT NULL,
    concurrentuserlimit integer NOT NULL,
    concurrentusercount integer NOT NULL,
    registerdate timestamp NOT NULL,
    CONSTRAINT pk_concurrentuserstat PRIMARY KEY (serverno, concurrentuserstattypecode, registerdate)
);

CREATE TABLE fatigue (
    fcid integer NOT NULL,
    lastlogoutdate timestamp NOT NULL,
    playtime integer DEFAULT 0 NOT NULL,
    resttime integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_fatigue PRIMARY KEY (fcid)
);

CREATE TABLE gameserver (
    gameserverno smallint NOT NULL,
    gameservername varchar(50) NOT NULL,
    gameservertypecode smallint NOT NULL,
    gameserverstatuscode smallint NOT NULL,
    serverareacode smallint NOT NULL,
    useragelimit smallint NOT NULL,
    privatenetworkipaddress varchar(15) NOT NULL,
    publicnetworkipaddress varchar(15) NOT NULL,
    portno smallint NOT NULL,
    paidflag boolean NOT NULL,
    servercustomizebitset integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_gameserver PRIMARY KEY (gameserverno)
);

CREATE TABLE gameserverchargegroup (
    gameserverno smallint NOT NULL,
    gameserverchargegroupno smallint NOT NULL,
    CONSTRAINT pk_gameserverchargegroup PRIMARY KEY (gameserverno)
);

CREATE TABLE illegallogintrace (
    gameaccountno integer NOT NULL,
    illegallogintracetypecode smallint NOT NULL,
    ipaddress varchar(15) NOT NULL,
    registerdate timestamp NOT NULL
);

CREATE TABLE restriction (
    gamerestrictionno integer NOT NULL,
    gameaccountno integer NOT NULL,
    gamerestrictionreasoncode smallint NOT NULL,
    restrictionstartdate timestamp NOT NULL,
    restrictionenddate timestamp NOT NULL,
    restrictionexpiredate timestamp NOT NULL,
    CONSTRAINT pk_restriction PRIMARY KEY (gamerestrictionno)
);

CREATE TABLE secedeaccount (
    secedeapplyno integer NOT NULL,
    gameaccountno integer NOT NULL,
    gameaccount varchar(16) NOT NULL,
    accountstatuscode smallint NOT NULL,
    accountcreatedate timestamp NOT NULL,
    secedeapplydate timestamp NOT NULL,
    batchdeletedate timestamp NULL,
    CONSTRAINT pk_secedeaccount PRIMARY KEY (secedeapplyno)
);

-- ── Indexes ──────────────────────────────────────────

CREATE UNIQUE INDEX ux_accountauth_gameaccount ON accountauth (gameaccount);
CREATE INDEX ix_accountgamecharacter_gameaccountno_characterlevel ON accountgamecharacter (gameaccountno, characterlevel);
CREATE INDEX ix_illegallogintrace_gameaccountno_registerdate ON illegallogintrace (gameaccountno, registerdate);
CREATE INDEX idx_restriction_gameaccountno_restrictionenddate ON restriction (gameaccountno, restrictionenddate);
CREATE INDEX idx_secedeaccount_gameaccount ON secedeaccount (gameaccount);
CREATE INDEX idx_secedeaccount_gameaccountno ON secedeaccount (gameaccountno);

-- ── Foreign Keys ─────────────────────────────────────

ALTER TABLE accountetc ADD CONSTRAINT fk_accountetc_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE accountgamecharacter ADD CONSTRAINT fk_accountgamecharacter_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE accountgameslot ADD CONSTRAINT fk_accountgameslot_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE accounthistory ADD CONSTRAINT fk_accounthistory_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE accountlink ADD CONSTRAINT fk_accountlink_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE accountloginnotice ADD CONSTRAINT fk_accountloginnotice_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE accountsecurityservice ADD CONSTRAINT fk_accountsecurityservice_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE illegallogintrace ADD CONSTRAINT fk_illegallogintrace_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE restriction ADD CONSTRAINT fk_restriction_gameaccountno FOREIGN KEY (gameaccountno) REFERENCES accountauth (gameaccountno);
ALTER TABLE accountlink ADD CONSTRAINT fk_accountlink_linktargetno FOREIGN KEY (linktargetno) REFERENCES fatigue (fcid);
