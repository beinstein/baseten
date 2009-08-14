all: PredicateParser

PredicateParser:
	cc -o PredicateParser -std=c99 -fobjc-exceptions -framework Foundation -framework CoreData -Wall -Werror PredicateParser.m -ggdb

clean:
	rm -rf PredicateParser
	rm -rf PredicateParser.dSYM

.PHONY: clean all
