create table users(
    id serial primary key, -- not null and uniqueness is already included by defining this field a pk
    first_name text not null, -- few mistakes was made in definition of this field, char type doesn't contain unicode which can be a huge mistake,
                             -- especially if we create an internation system and char is also a fixed size data type which obviously is incorrect in this case,
                             -- I assume that first_name is an important field which has to be filled with data :), so not-null constraint is a must have here
    last_name text not null, -- same here
    username text unique not null, -- we definitely want to require uniqueness here, same as not-null
    password text not null, -- usually we must encrypt passwords, so it can't be 8 characters, if we know which encryption algorithm we will use,
                           -- we can make this field fixed size, for example if it's sha-256, we could've made this field char(64)
    date_created date not null default current_date, -- I would do this field a little bit different, but I assume you need the exact this information. I would do this createtime timestamptz not null default now()
    is_active bool not null default true -- the name of this field says that we want to see whether this user is active or not.
                                         -- so till this field won't have any specified statuses for different values, we need only true or false, which is boolean data type
    --optional: we can add some extra fields, they can be quite useful in most of the systems
    --last_login timestamptz, we will fill this value on the back side,
    --is_staff bool not null default false, we can clarify is the user a staff or not
    --is_superuser bool not null default false, we can clarify is the user a superuser or not.
                                                -- I don't mean that this is the only permissions' restriction in the whole system for the user, but it can be quite convenient to have this field here
    --updatettime timestamptz, field will show last update-statement made on this row
    --create trigger t_users_bu_updated
    --before update
    --on users
    --for each row
    --execute procedure upd_updatettime();
    --create function upd_updatettime() returns trigger
    --language plpgsql
    --as
    --$$
    --begin
    --new.updatettime = current_timestamp;
    --return new;
    --end;
    --$$;
);
create index concurrently on users using gin (username gin_trgm_ops); --we need indexes for searching a user, so we can use extension pg_trgm for a better perfomance;
create index concurrently on users using gin (last_name gin_trgm_ops, first_name gin_trgm_ops);


--as we are not sure that tomorrow or let's say in one week, we won't have the request to change the maximum number of connected devices,
--I think the best way to implement such a logic is to create a trigger, so that we avoid ddl commands on the table in prod environment
create table devices (
    id uuid primary key, --postgresql has uuid data type, we can use it. we can also create extension for working with uuid data types, and then define default value as something like uuid_generate()
    alias text not null , --not sure what "name" is going to contain, so "alias" is a better for understanding I guess, if it's just a label for device by user
    users_id int not null references users(id) --let's create many to one connection to users table for data integrity
    --optional: createtime timestamptz not null default now(), is_removed bool not null default false, type text not null check (type in ('tablet', 'mobile', 'desktop', 'other')), os text
);
create unique index concurrently on devices (users_id, alias) /*where not is_removed*/;

create function tf_devices_check_devices_cnt() returns trigger
language plpgsql
as
$$
    begin
        if (select count(*) from devices where users_id = new.users_id /*and not is_removed*/) < 5 then
            return new;
        else
            raise exception 'You can''t create device! User already have 5 devices!';
        end if;
    end;
$$;
create trigger t_devices_bi
    before insert
    on devices
    for each row
execute procedure tf_devices_check_devices_cnt();

--if I understand correctly what "apps" means, then we need a table (we could do check-constraint if we would've known all the apps
-- from the beginning and we would be sure, that its fixed amount of the apps, so it won't add later) for definition apps
-- and another one for linking apps to devices (it doesn't make any sense to link apps to user)
create table apps (
    name text primary key,
    createtime timestamptz not null default now()
);
create table apps_devices (
    app_name text references apps(name),
    device_uuid uuid references devices(id),
    date_installed date not null default current_date
);
create index concurrently on apps_devices (device_uuid, app_name);


grant insert, update on table users to *role for an app*;
grant select, usage on sequence users_id_seq to *role for an app*;

grant insert, update on table devices to *role for an app*;
grant insert on table apps_devices to *role for an app*;
grant insert, update, delete on table apps to *role for an app*;

