require 'sparql/extensions'

##
# A SPARQL for RDF.rb.
#
# @see http://www.w3.org/TR/rdf-sparql-query
module SPARQL
  autoload :Algebra, 'sparql/algebra'
  autoload :Grammar, 'sparql/grammar'
  autoload :Results, 'sparql/results'
  autoload :VERSION, 'sparql/version'

  # @see http://rubygems.org/gems/sparql-client
  autoload :Client,  'sparql/client'

  ##
  # Parse the given SPARQL `query` string.
  #
  # @example
  #   parser = SPARQL.parse("SELECT * WHERE { ?s ?p ?o }")
  #   result = parser.parse
  #
  # @param  [IO, StringIO, String, #to_s]  query
  # @param  [Hash{Symbol => Object}] options
  # @return [SPARQL::Query]
  #   The resulting query may be executed against
  #   a `queryable` object such as an RDF::Graph
  #   or RDF::Repository. 
  # @raise  [Parser::Error] on invalid input
  def self.parse(query, options = {})
    query = Grammar::Parser.new(query, options).parse
  end

  ##
  # Parse and execute the given SPARQL `query` string against `queriable`.
  #
  # Requires a queryable object (such as an RDF::Repository), into which the dataset will be loaded.
  #
  # Optionally takes a list of URIs to load as default or named graphs
  # into `queryable`.
  #
  # Note, if default or named graphs are specified as options (protocol elements),
  # or the query references specific default or named graphs the graphs are either
  # presumed to be existant in `queryable` or are loaded into `queryable` depending
  # on the presense and value of the :load_datasets option.
  #
  # Attempting to load into an immutable `queryable` will result in a TypeError.
  #
  # @example
  #   repository = RDF::Repository.new
  #   results = SPARQL.execute("SELECT * WHERE { ?s ?p ?o }", repository)
  #
  # @param  [IO, StringIO, String, #to_s]  query
  # @param  [Hash{Symbol => Object}] options
  # @option options  [RDF::Queryable]  :queryable
  # @option options [RDF::URI, String, Array<RDF::URI, String>] :load_datasets
  #   One or more URIs used to initialize a new instance of `queryable` in the default context.
  # @option options [RDF::URI, String, Array<RDF::URI, String>] :default_graph_uri
  #   One or more URIs used to initialize a new instance of `queryable` in the default context.
  # @option options [RDF::URI, String, Array<RDF::URI, String>] :named_graph_uri
  #   One or more URIs used to initialize the `queryable` as a named context.
  # @return [RDF::Graph, RDF::Query::Solutions, Boolean]
  #   Note, results may be used with SPARQL.serialize_results to obtain appropriate
  #   output encoding.
  # @raise  [SPARQL::MalformedQuery] on invalid input
  def self.execute(query, queryable, options = {})
    query = self.parse(query, options)
    queryable = queryable || RDF::Repository.new
    
    if options.has_key?(:load_datasets)
      queryable = queryable.class.new
      [options[:default_graph_uri]].flatten.each do |uri|
        queryable.load(uri)
      end
      [options[:named_graph_uri]].flatten.each do |uri|
        queryable.load(uri, :context => uri)
      end
    end
    solutions = query.execute(queryable)
  rescue SPARQL::Grammar::Parser::Error => e
    raise MalformedQuery, e.message
  rescue TypeError => e
    raise QueryRequestRefused, e.message
  end

  ##
  # MalformedQuery
  #
  # When the value of the query type is not a legal sequence of characters in the language defined by the
  # SPARQL grammar, the MalformedQuery or QueryRequestRefused fault message must be returned. According to the
  # Fault Replaces Message Rule, if a WSDL fault is returned, including MalformedQuery, an Out Message must not
  # be returned.
  class MalformedQuery < Exception
    def title
      "Malformed Query".freeze
    end
  end

  ##
  # QueryRequestRefused
  #
  # returned when a client submits a request that the service refuses to process.
  class QueryRequestRefused < Exception
    def title
      "Query Request Refused".freeze
    end
  end
end

require 'sparql/extensions'
