/* This file contains some useful scripts for administration of AsmBB forum using the SQLite console. */


-- Displays all guests that downloaded only files like images, robots.txt, etc. without actually visiting the website.

select
  (g.addr >> 24 & 255)||'.'||(g.addr >> 16 & 255)||'.'||(g.addr >> 8 & 255)||'.'||(g.addr & 255) as IP,
  datetime(g.LastSeen, 'unixepoch') as Time,
  gr.method,
  gr.request,
  gr.client,
  gr.referer
from
  guests g
left join
  guestrequests gr on g.addr = gr.addr
where
  g.addr not in (select remoteIP from UserLog);


-- Displays a list of unique referers with counts of all visitors from that URL:

select count() as cnt, substr(referer, 1, instr(referer, '?')-1) as refr from guestrequests where refr is not null and refr not like '%board.asm32.info%' and instr(referer, '?') > 0
group by refr
union
select count() as cnt, referer as refr from guestrequests where refr is not null and refr not like '%board.asm32.info%' and instr(referer, '?') = 0
group by refr
order by cnt desc;

-- the same, but faster

select
  count(refr) as cnt,
  refr
from
  ( select
      substr(referer, 1, instr(referer, '?')-1) as refr
    from
      guestrequests
    where
      referer not like '%board.asm32.info%' and instr(referer, '?') > 0
    union all
    select
      referer as refr
    from
      guestrequests
    where
       referer not like '%board.asm32.info%' and instr(referer, '?') = 0
  )
group by refr
order by cnt desc, refr;



-- Displays a report about the Guests active from the last 5 minutes.

select datetime(LastSeen, 'unixepoch') as Date, (addr >> 24 & 255)||'.'||(addr >> 16 & 255)||'.'||(addr >> 8 & 255)||'.'||(addr & 255) as IP, Client
from Guests where LastSeen > strftime('%s', 'now') - 300 order by LastSeen;

select
  (g.addr >> 24 & 255)||'.'||(g.addr >> 16 & 255)||'.'||(g.addr >> 8 & 255)||'.'||(g.addr & 255) as IP,
  datetime(g.LastSeen, 'unixepoch') as Time,
  gr.method,
  gr.request,
  gr.client,
  gr.referer
from
  guests g
left join
  guestrequests gr on g.addr = gr.addr
where
  g.rowid in (select rowid from guests order by rowid desc limit 200) and
  IP <> '127.0.0.1';

/* Rebuilds the full text search table */

drop table PostFTS;
CREATE VIRTUAL TABLE PostFTS using fts5( Content, content=Posts, content_rowid=id, tokenize='porter unicode61 remove_diacritics 1');
insert into PostFTS(rowid, Content) select id, Content from Posts;



create View PostsView as select P.id, P.Content, P.ThreadID, (select group_concat(Tag, ' ') from ThreadTags TT where TT.ThreadID = P.ThreadID ) as Tags from Posts P;
drop table PostFTS;
CREATE VIRTUAL TABLE PostFTS using fts5( Content, ThreadID, Tags, content=PostsView, content_rowid=id, tokenize='porter unicode61 remove_diacritics 1');
insert into PostFTS(rowid, Content, ThreadID, Tags) select id, Content, ThreadID, Tags from PostsView;


drop table PostFTS;
CREATE VIRTUAL TABLE PostFTS using fts5( Content, ThreadID, UserID, PostTime, ReadCount, Tags, content=Posts, content_rowid=id, tokenize='porter unicode61 remove_diacritics 1');

insert into PostFTS(rowid, Content, ThreadID, UserID, PostTime, ReadCount, Tags)
select P.id, P.Content, P.ThreadID, P.UserID, P.PostTime, P.ReadCount, (select group_concat(Tag, ' ') from ThreadTags TT where TT.ThreadID = P.ThreadID ) as Tags from Posts P;

