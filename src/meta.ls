export meta =
  'pgrest.ivod':
    as: 'public.ivod'
    columns:
      '*': <[sitting_id type speaker thumb firm time first_frame_timestamp length video_url_n video_url_w wmvid youtube_id]>
  'pgrest.calendar':
    f: {-raw}
    s: {date: -1}
    as: 'public.calendar'
    $query: ad: $not: null
    columns:
      sitting_id: $literal: '_calendar_sitting_id(calendar)'
      '*': {}
  'pgrest.motions':
    s: {sitting_id: -1,motion_class: 1, agenda_item: 1}
    as: 'public.motions LEFT JOIN bills USING (bill_id)'
    columns:
      '*':
        motions: {}
        bills: <[bill_ref summary proposed_by]>
      'doc': type: \json
  'pgrest.sittings':
    s: {id: -1}
    f: {-videos}
    as: 'public.sittings'
    primary: \id
    columns:
      '*': {}
      dates:
        $from: 'pgrest.calendar'
        $query: 'sitting_id': $literal: 'sittings.id'
        $order: {date: 1}
        columns:
          'calendar_id': field: 'calendar.id'
          '*': <[chair date time_start time_end]>
      videos:
        $from: 'pgrest.ivod'
        $query: 'sitting_id': $literal: 'sittings.id'
        columns:
          '*': {}
      motions:
        $from: 'pgrest.motions'
        $query: 'sitting_id': $literal: 'sittings.id'
        $order: {motion_class: 1, agenda_item: 1}
        columns:
          '*': <[motion_class agenda_item subitem item bill_id bill_ref proposed_by summary doc]>
  'pgrest.bills':
    s: {bill_id: -1}
    f: {data: -1}
    as: 'bills'
    primary: (id) ->
      $or:
        bill_ref: id
        bill_id: id
    columns:
      '*': <[bill_id bill_ref summary proposed_by sponsors cosponsors abstract report_of reconsideration_of]>
      data: type: \json
      doc: type: \json
      motions:
        $from: 'pgrest.motions JOIN pgrest.sittings ON (sitting_id = sittings.id)'
        $query: 'bill_id': $literal: 'bills.bill_id'
        $order: {sitting_id: 1}
        columns:
          '*':
            motions: <[sitting_id resolution status committee]>
            sittings: <[dates]>
