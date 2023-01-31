DROP SCHEMA IF EXISTS notion CASCADE;
CREATE SCHEMA notion;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS notion.teams (
    id bigserial PRIMARY KEY,
    name varchar(40) NOT NULL
);

CREATE TABLE IF NOT EXISTS notion.users (
    id bigserial PRIMARY KEY,
    name varchar(15) NOT NULL,
    surname varchar(30) NOT NULL,
    email varchar(80) NOT NULL,
    birthday date NOT NULL,
    passw TEXT NOT NULL
);
CREATE FUNCTION notion.user_check() RETURNS TRIGGER AS $user_check$
BEGIN
        --Проверка email
        IF NEW.email !~ '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$' THEN
            RAISE EXCEPTION 'email: % is not valid', NEW.email;
END IF;
        --Проверка email на уникальность
        IF (SELECT count(*) FROM notion.users WHERE email = NEW.email) > 0 THEN
            RAISE EXCEPTION 'email: % already exists in the database', NEW.email;
END IF;

        --Проверка возраста > 16 лет
        IF date_part('year', age(NEW.birthday)) < 16 THEN
            RAISE EXCEPTION 'user age less then 16 years';
END IF;
        --убираем пароль в sha1
        NEW.passw := encode(digest(NEW.passw, 'sha1'), 'hex');
RETURN NEW;
END;
$user_check$ LANGUAGE plpgsql;
CREATE TRIGGER user_check BEFORE INSERT OR UPDATE ON notion.users
    FOR EACH ROW EXECUTE FUNCTION notion.user_check();


CREATE TABLE IF NOT EXISTS notion.usersteams(
    teamid bigint REFERENCES notion.teams(id) ON DELETE CASCADE,
    userid bigint REFERENCES notion.users(id) ON DELETE CASCADE,
    PRIMARY KEY (teamid, userid)
    );


DROP TYPE IF EXISTS NotepadColorEnum;
CREATE TYPE NotepadColorEnum AS ENUM ('black', 'white', 'red', 'blue', 'green');
CREATE TABLE IF NOT EXISTS notion.notepads (
    id bigserial PRIMARY KEY,
    title varchar(255) NOT NULL,
    createtime timestamp NOT NULL DEFAULT NOW() CHECK (createtime <= NOW()),
    color NotepadColorEnum DEFAULT 'black'
);

CREATE TABLE IF NOT EXISTS notion.usersnotepads(
    userid bigint REFERENCES notion.users(id) ON DELETE CASCADE,
    notepadid bigint REFERENCES notion.notepads(id) ON DELETE CASCADE,
    PRIMARY KEY (userid, notepadid)
);

CREATE FUNCTION notion.user_notepads_constraint() RETURNS TRIGGER AS $user_notepads_constraint$
BEGIN
DELETE FROM notion.notepads WHERE id = OLD.notepadid;
RETURN NULL;
END;
$user_notepads_constraint$ LANGUAGE plpgsql;
CREATE TRIGGER user_notepads_constraint AFTER DELETE ON notion.usersnotepads
    FOR EACH ROW EXECUTE FUNCTION notion.user_notepads_constraint();


CREATE TABLE IF NOT EXISTS notion.notes (
    id bigserial PRIMARY KEY,
    notepadid bigint REFERENCES notion.notepads(id) ON DELETE CASCADE,
    title varchar(255) NOT NULL,
    createtime timestamp NOT NULL DEFAULT NOW() CHECK (createtime <= NOW()),
    modificationdate timestamp NOT NULL DEFAULT NOW() CHECK (modificationdate >= createtime)
);

DROP TYPE IF EXISTS RecordTypeEnum;
CREATE TYPE RecordTypeEnum AS ENUM ('','Текст','Код','Заголовок','Цитата','Файл','Картинка','Ютуб Видео','Заметка');
DROP TYPE IF EXISTS ProgrammingLanguageEnum;
CREATE TYPE ProgrammingLanguageEnum AS ENUM ('','SQL','Java','C++','Shell');
CREATE TABLE IF NOT EXISTS notion.records (
    id bigserial PRIMARY KEY,
    noteid bigint REFERENCES notion.notes(id) ON DELETE CASCADE,
    sheet integer NOT NULL,
    recordtype RecordTypeEnum NOT NULL,
    recordcontent TEXT,
    programminglanguage ProgrammingLanguageEnum,
    link varchar(255)
);

CREATE FUNCTION notion.record_check() RETURNS TRIGGER AS $record_check$
BEGIN
        IF NEW.recordtype = '' THEN NEW.recordtype := NULL; END IF;
        IF NEW.programminglanguage = '' THEN NEW.programminglanguage := NULL; END IF;
        IF NEW.link = '' THEN NEW.link := NULL; END IF;
        --Проверка номера листа заметки
        IF (SELECT count(*) FROM notion.records WHERE noteid = NEW.noteid AND sheet = NEW.sheet) > 0 THEN
            RAISE EXCEPTION 'The note already has an record with the sheet %', NEW.sheet;
END IF;
        --Проверка типа и содержимого заметки
        IF NEW.recordtype IS NULL THEN
            RAISE EXCEPTION 'The type of record is not filled in.';
END IF;
        IF NEW.recordtype IN ('Текст','Заголовок','Цитата','Код') AND NEW.recordcontent IS NULL THEN
            RAISE EXCEPTION 'The content for this type of record(%) should not be NULL', NEW.recordtype;
END IF;
        IF NEW.recordtype IN ('Текст','Заголовок','Цитата','Файл','Картинка','Ютуб Видео','Заметка') AND NEW.programminglanguage IS NOT NULL THEN
            RAISE EXCEPTION 'The programming language for this type of record(%) should not be filled in.', NEW.recordtype;
END IF;
        IF NEW.recordtype IN ('Текст','Заголовок','Цитата','Код') AND NEW.link IS NOT NULL THEN
            RAISE EXCEPTION 'The link for this type of record(%) should not be filled in.', NEW.recordtype;
END IF;
        IF NEW.recordtype = 'Код' AND NEW.programminglanguage IS NULL THEN
            RAISE EXCEPTION 'The programming language for this type of record(%) should be filled in.', NEW.recordtype;
END IF;
        IF NEW.recordtype = 'Код' AND NEW.programminglanguage IS NULL THEN
            RAISE EXCEPTION 'The programming language for this type of record(%) should be filled in.', NEW.recordtype;
END IF;
        IF NEW.recordtype IN ('Файл','Картинка','Ютуб Видео','Заметка') AND NEW.recordcontent IS NOT NULL THEN
            RAISE EXCEPTION 'The content for this type of record(%) should not be filled in.', NEW.recordtype;
END IF;
        IF NEW.recordtype IN ('Файл','Картинка') AND NEW.link IS NULL THEN
            RAISE EXCEPTION 'The link for this type of record(%) should be filled in.', NEW.recordtype;
END IF;
        IF NEW.recordtype = 'Ютуб Видео' AND NEW.link IS NULL THEN
            RAISE EXCEPTION 'The link for this type of record(%) should be filled in.', NEW.recordtype;
END IF;
        IF NEW.recordtype = 'Заметка' AND NEW.link IS NULL THEN
            RAISE EXCEPTION 'The link for this type of record(%) should be filled in.', NEW.recordtype;
        ELSEIF NEW.recordtype = 'Заметка' AND (SELECT count(*) FROM notion.notes WHERE id = NEW.link::bigint) = 0 THEN
             RAISE EXCEPTION 'The note with id % does not exist.', NEW.link;
END IF;
RETURN NEW;
END;
$record_check$ LANGUAGE plpgsql;
CREATE TRIGGER record_check BEFORE INSERT OR UPDATE ON notion.records
    FOR EACH ROW EXECUTE FUNCTION notion.record_check();