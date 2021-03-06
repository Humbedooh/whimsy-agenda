#
# Server side Sinatra routes
#

# redirect root to latest agenda
get '/' do
  agenda = dir('board_agenda_*.txt').sort.last
  redirect to("/#{agenda[/\d+_\d+_\d+/].gsub('_', '-')}/")
end

# all agenda pages
get %r{/(\d\d\d\d-\d\d-\d\d)/(.*)} do |date, path|
  agenda = "board_agenda_#{date.gsub('-','_')}.txt"
  pass unless File.exist? File.join(FOUNDATION_BOARD, agenda)

  if AGENDA_CACHE[agenda][:mtime] == 0
    AGENDA_CACHE.parse(agenda, true)
  end

  @base = (env['SCRIPT_URL']||env['PATH_INFO']).chomp(path).untaint

  if ENV['RACK_ENV'] == 'test'
    userid = 'test'
    username = 'Joe Tester'
  else
    require 'etc'
    userid = env['REMOTE_USER'] || Etc.getlogin
    username = Etc.getpwnam(userid)[4].split(',').first
  end

  @server = {
    userid: userid,
    agendas: dir('board_agenda_*.txt').sort,
    drafts: dir('board_minutes_*.txt').sort,
    pending: Pending.get(userid),
    username: username,
    initials: username.gsub(/[^A-Z]/, '').downcase
  }

  @page = {
    date: date,
    path: path,
    query: params['q'],
    agenda: agenda,
    parsed: AGENDA_CACHE[agenda][:parsed],
    etag: AGENDA_CACHE[agenda][:etag]
  }

  @page[:etag] = nil unless AGENDA_CACHE[agenda][:mtime].to_i > 0

  _html :'main'
end

# posted actions
post '/json/:file' do
  _json :"actions/#{params[:file]}"
end

# updates to agenda data
get %r{(\d\d\d\d-\d\d-\d\d).json} do |file|
  file = "board_agenda_#{file.gsub('-','_')}.txt"
  path = File.expand_path(file, FOUNDATION_BOARD).untaint
  pass unless File.exist? path

  begin
    _json do
      file = file.dup.untaint

      if AGENDA_CACHE[file][:mtime] != File.mtime(path)
        AGENDA_CACHE.parse file
      end

      last_modified AGENDA_CACHE[file][:mtime]
      AGENDA_CACHE[file][:parsed]
    end
  ensure
    AGENDA_CACHE[file][:etag] = headers['ETag']
  end
end
