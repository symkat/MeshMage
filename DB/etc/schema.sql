CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE person (
    id                          serial          PRIMARY KEY,
    name                        text            not null,
    email                       citext          not null unique,
    is_enabled                  boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

-- Settings for a given user.  | Use with care, add things to the data model when you should.
create TABLE person_settings (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    name                        text            not null,
    value                       json            not null default '{}',
    created_at                  timestamptz     not null default current_timestamp,

    -- Allow ->find_or_new_related()
    CONSTRAINT unq_person_id_name UNIQUE(person_id, name)
);

CREATE TABLE auth_password (
    person_id                   int             not null unique references person(id),
    password                    text            not null,
    salt                        text            not null,
    updated_at                  timestamptz     not null default current_timestamp,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE network (
    id                          serial          PRIMARY KEY,
    name                        text            not null,
    address                     inet            not null,
    tld                         text            not null,
    updated_at                  timestamptz     not null default current_timestamp,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE node (
    id                          serial          PRIMARY KEY,
    network_id                  int             not null references network(id),
    hostname                    text            not null,
    public_ip                   inet            ,
    nebula_ip                   inet            not null,
    is_lighthouse               boolean         not null default false,
    updated_at                  timestamptz     not null default current_timestamp,
    created_at                  timestamptz     not null default current_timestamp
);

-- Attributes for a given machine.  | Use with care, add things to the data model when you should.
create TABLE node_attribute (
    id                          serial          PRIMARY KEY,
    node_id                     int             not null references node(id),
    name                        text            not null,
    value                       json            not null default '{}',
    created_at                  timestamptz     not null default current_timestamp,

    -- Allow ->find_or_new_related()
    CONSTRAINT unq_node_id_name UNIQUE(node_id, name)
);

CREATE TABLE sshkeys (
    id                          serial          PRIMARY KEY,
    name                        text            not null,
    public_key                  text            not null,
    created_at                  timestamptz     not null default current_timestamp
);

