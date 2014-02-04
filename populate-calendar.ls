#
# Read parsed data from TWLyParser then insert into database.
#
# twlyparser is one of dependency of api.ly g0v project. twlyparser downloads
# and parse data from "http://www.ly.gov.tw".
# this script populates data of calendar to local postgresql database.

const { USER, DB } = process.env

require! <[async optimist path fs pgrest]>
{util}:ly = require \twlyparser

{year, force, all, db=DB} = optimist.argv

year ?= new Date!getFullYear!

plx <- pgrest.new db, {+client}

update-list = (year, cb) ->
    return cb! unless year
    err, {rows:[{max:seen}]} <- plx.conn.query "select max(id) from calendar"
    throw err if err

    funcs = []
    entries <- ly.getCalendarByYear year, if all => 0 else seen

    for d in entries => let d
        id = delete d.id
        funcs.push (done) ->
            res <- plx.upsert collection: \calendar, q: {id}, $: $set: {d.date, raw: JSON.stringify d}, _, -> throw it
            done!

    err, res <- async.series funcs
    cb!

<- update-list year

err, {rows:entries}? <- plx.conn.query "select * from calendar #{if force => "" else "where ad is null"} order by id asc"
throw err if err

update-from-raw = (id, {name,chair=''}:raw, cb) ->
    if raw.committee is \院會
        committee = if name is /全院委員會/
          ['WHL']
        else
          null
    else if raw.committee is \臨時會
        committee = null
    else
        committee = [raw.committee]
        for c in raw.cocommittee?split /[,、，]/ when c and c not in committee
            committee.push c
        try
            committee = committee.map(-> util.parseCommittee it - /委員(?:會)?$/).reduce (++)
        catch
            console.log id, e
    chair = match chair
    | "" => null
    | /推(舉|定)/ => null
    else => chair - /(召集)?委員/
    name = raw.summary if !name
    name -= /\s/g if name
    [type, sitting] = match name
    | /公聽會/ => [\hearing, null]
    | /考察|視察|參訪|教育訓練/ => [\misc, null]
    | /第(\d+)次?(聯席|全體|全院)(委員)?會議?/ => [\sitting, +that.1]
    | /第(\d+)次會議?/ => [\sitting, +that.1]
    | /預備會議/ => [\sitting, 0]
    | /談話會/ => [\talk, null]
    | /臨時會/ => [\sitting]
    else => console.log id, name; [null, null]
    extra = if name is /第(\d+)次臨時會/ => +that.1 else null
    extra ?= if name is /第(\S{1,2})次臨時會第(\S{1,2})次會議/
      sitting = util.intOfZHNumber that.2
      util.intOfZHNumber that.1
    else null
    $set = raw{ad,session} <<< {name,type,extra,committee,chair,sitting} <<< do
        summary: raw.agenda
        raw: JSON.stringify raw
        time_start: raw.time.split(\~)?0?match(/\d\d:\d\d(:\d\d)?/)?0 ? '00:00'
        time_end: raw.time.split(\~)?1?match(/\d\d:\d\d(:\d\d)?/)?0 ? '23:59'
    delete $set.extra unless $set.extra
    <- plx.upsert {collection: \calendar, q: {id}, $: {$set}}, _, -> throw it
    cb!

funcs = entries.map ({ad,id}:entry) ->
    (done) ->
        if ad
            return done! unless force
            <- update-from-raw id, entry.raw
            done!
        else
            content <- ly.getCalendarEntry id
            <- setTimeout _, 1000ms
            raw = entry.raw <<< content
            update-from-raw id, raw, done

err, res <- async.series funcs
plx.end!
