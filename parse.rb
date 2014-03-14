require 'ox'
require 'json'
require 'mongo'
require 'zlib'
require 'open-uri'
require 'trollop'

class Entry
    attr_accessor :seq, :kanji, :readings, :senses
    def initialize
        @seq = 0
        @kanji = Array.new
        @readings = Array.new
        @senses = Array.new
    end

    def add_sense sense
        @senses << sense
    end

    def to_json(options = {})
        {'seq' => @seq, 'kanji' => @kanji, 'readings' => @readings, 'senses' => @senses}.to_json
    end
end

class Sense
    attr_accessor :pos, :meanings
    def initialize
        @pos = Array.new
        @meanings = Array.new
    end

    def to_json(options = {})
        {'pos' => @pos, 'meanings' => @meanings}.to_json
    end
end

class JMDict < ::Ox::Sax
    attr_reader :entries

    def initialize
        reset
        @entries = Array.new
    end

    def start_element(name)
        @read_seq = name == :ent_seq
        @read_kanji = name == :keb
        @read_reading = name == :reb
        @read_meaning = name == :gloss
        @read_pos = name == :pos
        @sense = Sense.new if name == :sense
        @entry = Entry.new if name == :entry
    end

    def text(value)
        @entry.seq = value.to_i if @read_seq
        @entry.kanji << value if @read_kanji
        @entry.readings << value if @read_reading
        @sense.pos << value[1..-2] if @read_pos
        @sense.meanings << value if @read_meaning
    end

    def end_element(name)
        if name == :entry
            @entries << @entry
            reset
        elsif name == :sense
            @entry.add_sense @sense
            @sense = nil
        end
    end

    protected

    def reset
        @entry = nil
        @sense = nil
        @read_kanji = @read_reading = @read_meaning = @read_pos = @read_seq = false
    end
end

# 0. Handle options and connect to Mongo
opts = Trollop::options do
    opt :skip_download, 'Skip download', default: false
    opt :host, 'Mongo Host', default: 'localhost'
    opt :port, 'Mongo port', type: :int, default: 3000
    opt :db, 'Mongo database', type: :string
    opt :coll, 'Mongo collection', type: :string
end

Trollop::die 'must specify database' if not opts[:db]
Trollop::die 'must specify collection' if not opts[:coll]

puts 'Connecting to Mongo...'
client = Mongo::MongoClient.new
db = client[opts[:db]]
coll = db[opts[:coll]]

# 1. Download the dictionary file
if opts[:skip_download]
    puts 'Skipping download...'
else
    puts 'Downloading JMDict_e.gz...'
    File.open('JMdict_e.gz', 'wb') do |saved_file|
        open('ftp://ftp.monash.edu.au/pub/nihongo/JMdict_e.gz', 'rb') do |read_file|
          saved_file.write(read_file.read)
        end
    end
end

# 2. Parse
puts 'Parsing JMDict_e...'
handler = JMDict.new
Ox.sax_parse(handler, Zlib::GzipReader.open('JMdict_e.gz'))

# 3. Store in mongo
# NOTE: we could do this in the handler, but I prefer doing it as a separate step.
puts 'Updating Mongo...'
handler.entries.each do |e|
    value = JSON.parse(e.to_json)
    coll.insert(value)
end

# 4. Done
puts 'Done.'
