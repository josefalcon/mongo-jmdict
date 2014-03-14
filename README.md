# mongo-jmdict

mongo-jmdict is a project for storing the [JMDict](http://www.edrdg.org/jmdict/j_jmdict.html) dictionary
in mongo. The SAX parser persists the following JMDict fields:

- ent_seq
- keb
- reb
- pos
- gloss

## Install

Use bundle to install the required dependencies.

```
$ bundle install
```

## Usage

Use `--help` to see the list of available options.

```
$ ruby parse.rb --help
```

Once connected to Mongo, the script will download the latest version of the JMDict dictionary,
parse, and finally persist to Mongo. If you intend to use your database for querying, be sure
to ensure indexes on the relevant fields. For example,

```
$ mongo
> db.collection.ensureIndex({kanji: 1})
> db.collection.ensureIndex({readings: 1})
```

## License

This package uses the [EDICT](http://www.csse.monash.edu.au/~jwb/edict.html) and [KANJIDIC](http://www.csse.monash.edu.au/~jwb/kanjidic.html) dictionary files. These files are the property of the [Electronic Dictionary Research and Development Group](http://www.edrdg.org/), and are used in conformance with the Group's [licence](http://www.edrdg.org/edrdg/licence.html).