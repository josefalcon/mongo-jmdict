require 'Nokogiri'
require 'ox'
require 'json'
require 'redis'
require 'mongo'
include Mongo

# Parse the dtd to create a "part of speech" map.
# we'll use the map in our sax parser
doc = Nokogiri::XML(File.open("jmdict_dtd"))
dtd = nil
# this is ugly...not sure how to use xpath to select the first document node
doc.children.each do |c|
    if c.type == Nokogiri::XML::Node::DTD_NODE
        dtd = c
    end
end

pos = Hash[dtd.entities.map {|k, v| [k, v.content]}]

class Entry
    attr_accessor :kanji, :readings, :senses
    def initialize
        @kanji = Array.new
        @readings = Array.new
        @senses = Array.new
    end

    def add_sense sense
#        if @senses.count > 0 and sense.pos.count == 0
#            @senses[-1].meanings.concat sense.meanings
#        else
            @senses << sense
#        end
    end

    def to_json(options = {})
        {'kanji' => @kanji, 'readings' => @readings, 'senses' => @senses}.to_json
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
        @read_kanji = name == :keb
        @read_reading = name == :reb
        @read_meaning = name == :gloss
        @read_pos = name == :pos
        @sense = Sense.new if name == :sense
        @entry = Entry.new if name == :entry
    end

    def text(value)
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
        @read_kanji = @read_reading = @read_meaning = @read_pos = false
    end
end

handler = JMDict.new
Ox.sax_parse(handler, File.open('jmdict_e'))

client = MongoClient.new
db = client['wasabi-db']
coll = db['dictionary']

handler.entries.each do |e|
    value = JSON.parse(e.to_json) # e.to_json

    coll.insert(value)

    # e.kanji.each do |k|
    #     redis.set(k, value)
    # end

    # e.readings.each do |r|
    #     redis.set(r, value)
    # end

    # coll.insert(value)

end
