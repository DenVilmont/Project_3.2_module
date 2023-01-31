CREATE OR REPLACE FUNCTION notion.random_between(low INT ,high INT) RETURNS INT AS $$
BEGIN
RETURN floor(random()* (high-low + 1) + low);
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION notion.random_name_and_surname(OUT name TEXT, OUT surname TEXT) AS $$
BEGIN
SELECT arrays.firstnames[random_between(1,array_length(arrays.firstnames,1))],
       arrays.surname[random_between(1,array_length(arrays.surname,1))]
INTO name, surname
FROM (
         SELECT ARRAY[
            'Adam','Bill','Bob','Calvin','Donald','Dwight','Frank','Fred','George','Howard',
            'James','John','Jacob','Jack','Martin','Matthew','Max','Michael',
            'Paul','Peter','Phil','Roland','Ronald','Samuel','Steve','Theo','Warren','William',
            'Abigail','Alice','Allison','Amanda','Anne','Barbara','Betty','Carol','Cleo','Donna',
            'Jane','Jennifer','Julie','Martha','Mary','Melissa','Patty','Sarah','Simone','Susan'
        ] AS firstnames,
        ARRAY[
            'Matthews','Smith','Jones','Davis','Jacobson','Williams','Donaldson','Maxwell','Peterson','Stevens',
            'Franklin','Washington','Jefferson','Adams','Jackson','Johnson','Lincoln','Grant','Fillmore','Harding','Taft',
            'Truman','Nixon','Ford','Carter','Reagan','Bush','Clinton','Hancock'
        ] AS surname
     ) AS arrays;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION notion.generate_test_data(teams int DEFAULT 3) RETURNS void AS $$
DECLARE
firstname varchar(15);
    lastname varchar(30);
    tstamp TEXT;
    teamid bigint;
    userid bigint := 0;
    notepadid bigint := 0;
    color NotepadColorEnum;
BEGIN
    --добавляем команды
FOR i IN 1..teams LOOP
        INSERT INTO notion.teams ("name") VALUES('Команда '||i);
END LOOP;

    --Добавляем от 3 до 6 пользователей в каждую команду
FOR teamid IN SELECT id FROM notion.teams t LOOP
        FOR i IN 1..notion.random_between(3,6) LOOP
SELECT name, surname INTO firstname, lastname FROM random_name_and_surname();
INSERT INTO notion.users (firstname, lastname, email, birthday, passw)
VALUES(firstname, lastname, firstname||lastname||userid||'@gmail.com',
       (timestamp '1950-01-01 00:00:00' + random() * (timestamp '2005-01-01 00:00:00' - timestamp '1950-01-01 00:00:00'))::date, firstname||lastname||userid)
    RETURNING id INTO userid;
INSERT INTO notion.usersteams (teamid, userid) VALUES(teamid, userid);
END LOOP;
END LOOP;

    -- добавляем 10% пользователей(минимум 1) без команды
FOR i IN 1..(SELECT count(*)/10+1 FROM notion.users) LOOP
SELECT name, surname INTO firstname, lastname FROM random_name_and_surname();
INSERT INTO notion.users (firstname, lastname, email, birthday, passw)
VALUES(firstname, lastname, firstname||lastname||userid||'@gmail.com',
       (timestamp '1950-01-01 00:00:00' + random() * (timestamp '2005-01-01 00:00:00' - timestamp '1950-01-01 00:00:00'))::date, firstname||lastname||userid)
    RETURNING id INTO userid;
END LOOP;

    --добавляем 10% пользователей(минимум 1) в первые 3 команды
FOR i IN 1..(SELECT count(*)/10+1 FROM notion.users) LOOP
    SELECT name, surname INTO firstname, lastname FROM random_name_and_surname();
    INSERT INTO notion.users (firstname, lastname, email, birthday, passw)
    VALUES(firstname, lastname, firstname||lastname||userid||'@gmail.com',
       (timestamp '1950-01-01 00:00:00' + random() * (timestamp '2005-01-01 00:00:00' - timestamp '1950-01-01 00:00:00'))::date, firstname||lastname||userid)
    RETURNING id INTO userid;

    FOR teamid IN SELECT id FROM notion.teams ORDER BY id LIMIT 3 LOOP
        INSERT INTO notion.usersteams (teamid, userid) VALUES(teamid, userid);
    END LOOP;
END LOOP;

    --добавляем каждому пользователю по блокноту.
FOR userid IN SELECT id FROM notion.users ORDER BY id LOOP
    SELECT INTO color FROM unnest(enum_range(NULL::NotepadColorEnum)) colors ORDER BY random() LIMIT 1;
    INSERT INTO notion.notepads (title, createtime, color) VALUES('Блокнот '||userid, now(), color::NotepadColorEnum)
        RETURNING id INTO notepadid;
    INSERT INTO notion.usersnotepads(userid, notepadid) VALUES(userid, notepadid);
END LOOP;

SELECT id INTO userid FROM notion.users ORDER BY id DESC LIMIT 1;

-- добавляем первым 10% блокнотов (минимум 1) второго автора (последний пользователь)
FOR notepadid IN SELECT id FROM notion.notepads ORDER BY id LIMIT (SELECT count(*)/10+1 FROM notion.notepads) LOOP
                 INSERT INTO notion.usersnotepads(userid, notepadid) VALUES(userid, notepadid);
END LOOP;

END;
$$ LANGUAGE plpgsql;

