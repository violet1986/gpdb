--
-- Basic tests for replicated table
--
create schema rpt;
set search_path to rpt;

---------
-- INSERT
---------
create table foo (x int, y int) distributed replicated;
create table foo1(like foo) distributed replicated;
create table bar (like foo) distributed randomly;
create table bar1 (like foo) distributed by (x);

-- values --> replicated table 
-- random partitioned table --> replicated table
-- hash partitioned table --> replicated table
-- singleQE --> replicated table
-- replicated --> replicated table
insert into bar values (1, 1), (3, 1);
insert into bar1 values (1, 1), (3, 1);
insert into foo1 values (1, 1), (3, 1);
insert into foo select * from bar;
insert into foo select * from bar1;
insert into foo select * from bar order by x limit 1;
insert into foo select * from foo;

select * from foo order by x;
select bar.x, bar.y from bar, (select * from foo) as t1 order by 1,2;
select bar.x, bar.y from bar, (select * from foo order by x limit 1) as t1 order by 1,2;

truncate foo;
truncate foo1;
truncate bar;
truncate bar1;

-- replicated table --> random partitioned table
-- replicated table --> hash partitioned table
insert into foo values (1, 1), (3, 1);
insert into bar select * from foo order by x limit 1;
insert into bar1 select * from foo order by x limit 1;

select * from foo order by x;
select * from bar order by x;
select * from bar1 order by x;

drop table if exists foo;
drop table if exists foo1;
drop table if exists bar;
drop table if exists bar1;

--
-- CREATE UNIQUE INDEX
--
-- create unique index on non-distributed key.
create table foo (x int, y int) distributed replicated;
create table bar (x int, y int) distributed randomly;

-- success
create unique index foo_idx on foo (y);
-- should fail
create unique index bar_idx on foo (y);

drop table if exists foo;
drop table if exists bar;

--
-- CREATE TABLE
--
--
-- Like
CREATE TABLE parent (
        name            text,
        age                     int4,
        location        point
) distributed replicated;

CREATE TABLE child (like parent) distributed replicated;
CREATE TABLE child1 (like parent) DISTRIBUTED BY (name);
CREATE TABLE child2 (like parent);

-- should be replicated table
\d child
-- should distributed by name
\d child1
-- should be replicated table
\d child2

drop table if exists parent;
drop table if exists child;
drop table if exists child1;
drop table if exists child2;

-- Inherits
CREATE TABLE parent_rep (
        name            text,
        age                     int4,
        location        point
) distributed replicated;

CREATE TABLE parent_part (
        name            text,
        age                     int4,
        location        point
) distributed by (name);

-- inherits from a replicated table, should fail
CREATE TABLE child (
        salary          int4,
        manager         name
) INHERITS (parent_rep) WITH OIDS;

-- replicated table can not have parents, should fail
CREATE TABLE child (
        salary          int4,
        manager         name
) INHERITS (parent_part) WITH OIDS DISTRIBUTED REPLICATED;

drop table if exists parent_rep;
drop table if exists parent_part;
drop table if exists child;

--
-- CTAS
--
-- CTAS from generate_series
create table foo as select i as c1, i as c2
from generate_series(1,3) i distributed replicated;

-- CTAS from replicated table 
create table bar as select * from foo distributed replicated;
select * from bar;

drop table if exists foo;
drop table if exists bar;

-- CTAS from partition table table
create table foo as select i as c1, i as c2
from generate_series(1,3) i;

create table bar as select * from foo distributed replicated;
select * from bar;

drop table if exists foo;
drop table if exists bar;

-- CTAS from singleQE 
create table foo as select i as c1, i as c2
from generate_series(1,3) i;
select * from foo;

create table bar as select * from foo order by c1 limit 1 distributed replicated;
select * from bar;

drop table if exists foo;
drop table if exists bar;

-- Create view can work
create table foo(x int, y int) distributed replicated;
insert into foo values(1,1);

create view v_foo as select * from foo;
select * from v_foo;

drop view v_foo;
drop table if exists foo;

---------
-- Alter
--------
-- Drop distributed key column
create table foo(x int, y int) distributed replicated;
create table bar(like foo) distributed by (x);

insert into foo values(1,1);
insert into bar values(1,1);

-- success
alter table foo drop column x;
-- fail
alter table bar drop column x;

drop table if exists foo;
drop table if exists bar;

-- Alter gp_distribution_policy
create table foo(x int, y int) distributed replicated;
create table bar(x int, y int) distributed by (x);

-- alter distribution policy of replicated table
alter table foo set distributed by (x);
-- alter a partitioned table to replicated table
alter table bar set distributed replicated;

drop table if exists foo;
drop table if exists bar;

---------
-- UPDATE / DELETE
---------
create table foo(x int, y int) distributed replicated;
create table bar(x int, y int);
insert into foo values (1, 1), (2, 1);
insert into bar values (1, 2), (2, 2);
update foo set y = 2 where y = 1;
select * from foo;
update foo set y = 1 from bar where bar.y = foo.y;
select * from foo;
delete from foo where y = 1;
select * from foo;

drop schema rpt cascade;
