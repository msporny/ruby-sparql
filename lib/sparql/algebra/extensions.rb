require 'json'

##
# Extensions for Ruby's `Object` class.
class Object
  ##
  # Returns the SXP binary representation of this object, defaults to `self'.
  #
  # @return [String]
  def to_sxp_bin
    self
  end
  
  ##
  # Make sure the object is in SXP form and transform it to a string form
  def to_sse
    self.to_sxp_bin.to_sxp
  end
end

##
# Extensions for Ruby's `Object` class.
class Array
  ##
  # Returns the SXP representation of this object, defaults to `self'.
  #
  # @return [String]
  def to_sxp_bin
    map {|x| x.to_sxp_bin}
  end
  
  ##
  # Evaluates the array using the given variable `bindings`.
  #
  # In this case, the Array has two elements, the first of which is
  # an XSD datatype, and the second is the expression to be evaluated.
  # The result is cast as a literal of the appropriate type
  #
  # @param  [RDF::Query::Solution, #[]] bindings
  #   a query solution containing zero or more variable bindings
  # @return [RDF::Term]
  def evaluate(bindings)
    dt, val = self.map {|o| o.evaluate(bindings)}
    SPARQL::Algebra::Expression.cast(*self.map {|o| o.evaluate(bindings)})
  end
end

##
# Extensions for `RDF::Term`.
module RDF::Term
  include SPARQL::Algebra::Expression
  
  def evaluate(bindings)
    self
  end
end # RDF::Term

# Override RDF::Queryable to execute against SPARQL::Algebra::Query elements as well as RDF::Query and RDF::Pattern
module RDF::Queryable
  alias_method :query_without_sparql, :query
  ##
  # Queries `self` for RDF statements matching the given `pattern`.
  #
  # Monkey patch to RDF::Queryable#query to execute a {SPARQL::Algebra::Operator}
  # in addition to an {RDF::Query} object.
  #
  # @example
  #     queryable.query([nil, RDF::DOAP.developer, nil])
  #     queryable.query(:predicate => RDF::DOAP.developer)
  #
  #     op = SPARQL::Algebra::Expression.parse(%q((bgp (triple ?a doap:developer ?b))))
  #     queryable.query(op)
  #
  # @param  [RDF::Query, RDF::Statement, Array(RDF::Term), Hash, SPARQL::Operator] pattern
  # @yield  [statement]
  #   each matching statement
  # @yieldparam  [RDF::Statement] statement
  # @yieldreturn [void] ignored
  # @return [Enumerator]
  # @see    RDF::Queryable#query_pattern
  def query(pattern, &block)
    raise TypeError, "#{self} is not readable" if respond_to?(:readable?) && !readable?

    if pattern.is_a?(SPARQL::Algebra::Operator) && pattern.respond_to?(:execute)
      before_query(pattern) if respond_to?(:before_query)
      query_execute(pattern, &block)
      after_query(pattern) if respond_to?(:after_query)
      enum_for(:query_execute, pattern)
    else
      query_without_sparql(pattern, &block)
    end
  end
  
end

class RDF::Query
  # Equivalence for Queries:
  #   Same Patterns
  #   Same Context
  # @return [Boolean]
  def ==(other)
    other.is_a?(RDF::Query) && patterns == other.patterns && context == context
  end

  # Transform Query into an Array form of an SSE
  #
  # If Query is named, it's treated as a GroupGraphPattern, otherwise, a BGP
  #
  # @return [Array]
  def to_sxp_bin
    res = [:bgp] + patterns.map(&:to_sxp_bin)
    (context ? [:graph, context, res] : res)
  end
end

class RDF::Query::Pattern
  # Transform Query Pattern into an SXP
  # @return [Array]
  def to_sxp_bin
    [:triple, subject, predicate, object]
  end
end

##
# Extensions for `RDF::Query::Variable`.
class RDF::Query::Variable
  include SPARQL::Algebra::Expression

  ##
  # Returns the value of this variable in the given `bindings`.
  #
  # @param  [RDF::Query::Solution, #[]] bindings
  # @return [RDF::Term] the value of this variable
  def evaluate(bindings = {})
    bindings[name.to_sym]
  end
end # RDF::Query::Variable

##
# Extensions for `RDF::Query::Solutions`.
class RDF::Query::Solutions
  alias_method :filter_without_expression, :filter

  ##
  # Filters this solution sequence by the given `criteria`.
  #
  # @param  [SPARQL::Algebra::Expression] expression
  # @yield  [solution]
  #   each solution
  # @yieldparam  [RDF::Query::Solution] solution
  # @yieldreturn [Boolean]
  # @return [void] `self`
  def filter(expression = {}, &block)
    case expression
      when SPARQL::Algebra::Expression
        filter_without_expression do |solution|
          expression.evaluate(solution).true?
        end
        filter_without_expression(&block) if block_given?
        self
      else filter_without_expression(expression, &block)
    end
  end
  alias_method :filter!, :filter
end # RDF::Query::Solutions
