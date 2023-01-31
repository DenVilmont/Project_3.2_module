CREATE FUNCTION notion.note_update_modificationdate() RETURNS TRIGGER AS $note_update_modificationdate$
BEGIN
        NEW.modificationdate = NOW();
RETURN NEW;
END;
$note_update_modificationdate$ LANGUAGE plpgsql;
CREATE TRIGGER note_update_modificationdate BEFORE INSERT OR UPDATE ON notion.notes
    FOR EACH ROW EXECUTE FUNCTION notion.note_update_modificationdate();


CREATE TABLE IF NOT EXISTS notion.notepadslog (
    id bigserial PRIMARY KEY,
    operation varchar(10) NOT NULL,
    userid varchar(50) NOT NULL,
    stamp timestamp NOT NULL,
    notepadid bigint,
    notepadowner bigint,
    notepadtitle varchar(255),
    color NotepadColorEnum,
    noteid bigint,
    notetitle varchar(255)
);

CREATE FUNCTION notion.notepad_log() RETURNS TRIGGER AS $notepad_log$
BEGIN
    INSERT INTO notion.notepadslog (operation, userid, stamp, notepadid, notepadtitle, color)
        VALUES(TG_OP, user, NOW(), NEW.id, NEW.title, NEW.color);

    RETURN NULL;
END;
$notepad_log$ LANGUAGE plpgsql;


CREATE TRIGGER notepad_log AFTER INSERT OR UPDATE OR DELETE ON notion.notepads
    FOR EACH ROW EXECUTE FUNCTION notion.notepad_log();


CREATE FUNCTION notion.note_log() RETURNS TRIGGER AS $note_log$
BEGIN
    INSERT INTO notion.notepadslog (operation, userid, stamp, noteid, notetitle)
        VALUES(TG_OP, user, NOW(), NEW.id, NEW.title);

    RETURN NULL;
END;
$note_log$ LANGUAGE plpgsql;


CREATE TRIGGER note_log AFTER INSERT OR UPDATE OR DELETE ON notion.notes
    FOR EACH ROW EXECUTE FUNCTION notion.note_log();


CREATE FUNCTION notion.usersnotepads_log() RETURNS TRIGGER AS $usersnotepads_log$
BEGIN
    INSERT INTO notion.notepadslog (operation, userid, stamp, notepadid, notepadowner)
        VALUES(TG_OP, user, NOW(), NEW.notepadid, NEW.userid);

    RETURN NULL;
END;
$usersnotepads_log$ LANGUAGE plpgsql;


CREATE TRIGGER usersnotepads_log AFTER INSERT OR UPDATE OR DELETE ON notion.usersnotepads
    FOR EACH ROW EXECUTE FUNCTION notion.usersnotepads_log();